#include "stream_texture.h"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>
}

#include <cinttypes>
#include <csignal>
#include <fcntl.h>
#include <unistd.h>
#include <iostream>
#include <map>
#include <mutex>
#include <string>

// Fallback dark pixel to guarantee Flutter render thread never reads a null pointer
static const uint8_t g_blank_pixel[4] = {15, 23, 42, 255};

struct _StreamTexture {
  FlPixelBufferTexture parent_instance;

  FlTextureRegistrar* registrar;
  gchar* source_path;
  uint32_t width;
  uint32_t height;

  // Thread-safe triple-buffering:
  // - render_buffer: safely owned by Flutter engine render thread during copy_pixels
  // - ready_buffer: latest complete frame waiting for next copy_pixels tick
  // - worker_buffer: actively written to by FFmpeg sws_scale in background thread
  uint8_t* render_buffer;
  uint8_t* ready_buffer;
  uint8_t* worker_buffer;
  size_t buffer_capacity;
  gboolean has_new_frame;
  gboolean notification_pending;
  GMutex mutex;

  GThread* worker_thread;
  gboolean is_running;
};

G_DEFINE_TYPE(StreamTexture, stream_texture, fl_pixel_buffer_texture_get_type())

static std::map<int64_t, StreamTexture*> g_active_textures;
static std::mutex g_textures_mutex;

struct TextureFrameNotification {
  FlTextureRegistrar* registrar;
  FlTexture* texture;
  StreamTexture* stream;
};

static gboolean on_frame_available_idle(gpointer user_data) {
  auto* notif = static_cast<TextureFrameNotification*>(user_data);
  if (notif) {
    gboolean should_notify = FALSE;
    if (notif->stream) {
      g_mutex_lock(&notif->stream->mutex);
      notif->stream->notification_pending = FALSE;
      should_notify = notif->stream->is_running;
      g_mutex_unlock(&notif->stream->mutex);
    }
    if (should_notify && notif->registrar && notif->texture) {
      fl_texture_registrar_mark_texture_frame_available(notif->registrar, notif->texture);
    }
    if (notif->texture) {
      g_object_unref(notif->texture);
    }
    delete notif;
  }
  return G_SOURCE_REMOVE;
}

static gboolean stream_texture_copy_pixels(FlPixelBufferTexture* texture,
                                           const uint8_t** out_buffer,
                                           uint32_t* width,
                                           uint32_t* height,
                                           GError** error) {
  StreamTexture* self = STREAM_TEXTURE(texture);

  g_mutex_lock(&self->mutex);
  // Atomic buffer exchange: present the newest completed ready_buffer
  if (self->has_new_frame && self->ready_buffer != nullptr) {
    std::swap(self->render_buffer, self->ready_buffer);
    self->has_new_frame = FALSE;
  }

  if (self->render_buffer != nullptr && self->width > 0 && self->height > 0) {
    *out_buffer = self->render_buffer;
    *width = self->width;
    *height = self->height;
    g_mutex_unlock(&self->mutex);
    return TRUE;
  }

  // Safe fallback: return valid 1x1 buffer so Flutter engine NEVER dereferences null
  *out_buffer = g_blank_pixel;
  *width = 1;
  *height = 1;
  g_mutex_unlock(&self->mutex);
  return TRUE;
}

void stream_texture_stop(StreamTexture* self);

static void stream_texture_dispose(GObject* object) {
  StreamTexture* self = STREAM_TEXTURE(object);
  stream_texture_stop(self);

  g_mutex_lock(&self->mutex);
  if (self->render_buffer) {
    g_free(self->render_buffer);
    self->render_buffer = nullptr;
  }
  if (self->ready_buffer) {
    g_free(self->ready_buffer);
    self->ready_buffer = nullptr;
  }
  if (self->worker_buffer) {
    g_free(self->worker_buffer);
    self->worker_buffer = nullptr;
  }
  if (self->source_path) {
    g_free(self->source_path);
    self->source_path = nullptr;
  }
  self->has_new_frame = FALSE;
  g_mutex_unlock(&self->mutex);

  G_OBJECT_CLASS(stream_texture_parent_class)->dispose(object);
}

static void stream_texture_finalize(GObject* object) {
  StreamTexture* self = STREAM_TEXTURE(object);
  g_mutex_clear(&self->mutex);
  G_OBJECT_CLASS(stream_texture_parent_class)->finalize(object);
}

static void stream_texture_class_init(StreamTextureClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = stream_texture_dispose;
  G_OBJECT_CLASS(klass)->finalize = stream_texture_finalize;
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = stream_texture_copy_pixels;
}

static void stream_texture_init(StreamTexture* self) {
  self->registrar = nullptr;
  self->source_path = nullptr;
  self->render_buffer = nullptr;
  self->ready_buffer = nullptr;
  self->worker_buffer = nullptr;
  self->buffer_capacity = 0;
  self->width = 0;
  self->height = 0;
  self->has_new_frame = FALSE;
  self->notification_pending = FALSE;
  self->worker_thread = nullptr;
  self->is_running = FALSE;
  g_mutex_init(&self->mutex);
}

static int stream_texture_interrupt_cb(void* opaque) {
  StreamTexture* self = (StreamTexture*)opaque;
  if (!self || !self->is_running) {
    return 1; // Immediately interrupt any blocking FFmpeg I/O call
  }
  return 0;
}

static gpointer stream_texture_worker(gpointer data) {
  StreamTexture* self = STREAM_TEXTURE(data);

  // Ignore SIGPIPE across worker threads
  signal(SIGPIPE, SIG_IGN);
  g_printerr("[stream_texture_worker] STARTED for %s\n", self->source_path);

  int retries = 0;
  AVFormatContext* fmt_ctx = avformat_alloc_context();
  if (fmt_ctx) {
    fmt_ctx->interrupt_callback.callback = stream_texture_interrupt_cb;
    fmt_ctx->interrupt_callback.opaque = self;
  }

  while (self->is_running && retries < 300) {
    if (!fmt_ctx) {
      fmt_ctx = avformat_alloc_context();
      if (fmt_ctx) {
        fmt_ctx->interrupt_callback.callback = stream_texture_interrupt_cb;
        fmt_ctx->interrupt_callback.opaque = self;
      }
    }

    AVDictionary* opts = nullptr;
    av_dict_set(&opts, "probesize", "262144", 0);
    av_dict_set(&opts, "analyzeduration", "500000", 0);
    av_dict_set(&opts, "fflags", "nobuffer", 0);
    av_dict_set(&opts, "flags", "low_delay", 0);

    int open_res = avformat_open_input(&fmt_ctx, self->source_path, nullptr, &opts);
    av_dict_free(&opts);

    if (open_res == 0) {
      g_printerr("[stream_texture_worker] open_input SUCCEEDED after %d retries\n", retries);
      break;
    }

    if (retries % 20 == 0) {
      g_printerr("[stream_texture_worker] retry %d open_input failed (code %d)\n", retries, open_res);
    }

    retries++;
    g_usleep(50000); // 50ms wait
  }

  if (!fmt_ctx || !self->is_running) {
    g_printerr("[stream_texture_worker] EXITING: fmt_ctx=%p is_running=%d\n", fmt_ctx, self->is_running);
    if (fmt_ctx) avformat_free_context(fmt_ctx);
    return nullptr;
  }

  int video_stream_idx = -1;
  for (unsigned int i = 0; i < fmt_ctx->nb_streams; i++) {
    if (fmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
      video_stream_idx = (int)i;
      break;
    }
  }

  // Only probe stream info if the container header didn't define video stream
  if (video_stream_idx == -1) {
    int stream_info_res = avformat_find_stream_info(fmt_ctx, nullptr);
    g_printerr("[stream_texture_worker] avformat_find_stream_info returned %d, nb_streams=%d\n",
               stream_info_res, fmt_ctx->nb_streams);
    for (unsigned int i = 0; i < fmt_ctx->nb_streams; i++) {
      if (fmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
        video_stream_idx = (int)i;
        break;
      }
    }
  } else {
    g_printerr("[stream_texture_worker] Container header already defined %d stream(s); preserving initial IDR packet!\n",
               fmt_ctx->nb_streams);
  }

  if (video_stream_idx == -1) {
    g_printerr("[stream_texture_worker] NO VIDEO STREAM FOUND! Exiting.\n");
    avformat_close_input(&fmt_ctx);
    return nullptr;
  }

  AVCodecParameters* codecpar = fmt_ctx->streams[video_stream_idx]->codecpar;
  enum AVCodecID cid = codecpar->codec_id;
  if (cid == AV_CODEC_ID_NONE) {
    cid = AV_CODEC_ID_H264;
  }
  const AVCodec* decoder = avcodec_find_decoder(cid);
  if (!decoder) {
    decoder = avcodec_find_decoder(AV_CODEC_ID_H264);
  }
  if (!decoder) {
    g_printerr("[stream_texture_worker] NO DECODER FOUND! Exiting.\n");
    avformat_close_input(&fmt_ctx);
    return nullptr;
  }

  AVCodecContext* codec_ctx = avcodec_alloc_context3(decoder);
  if (!codec_ctx ||
      avcodec_parameters_to_context(codec_ctx, codecpar) < 0 ||
      avcodec_open2(codec_ctx, decoder, nullptr) < 0) {
    g_printerr("[stream_texture_worker] CODEC OPEN FAILED! Exiting.\n");
    if (codec_ctx) avcodec_free_context(&codec_ctx);
    avformat_close_input(&fmt_ctx);
    return nullptr;
  }

  g_printerr("[stream_texture_worker] Decoder successfully initialized! Starting frame loop...\n");

  AVFrame* frame = av_frame_alloc();
  AVPacket* pkt = av_packet_alloc();
  SwsContext* sws_ctx = nullptr;

  while (self->is_running) {
    int read_res = av_read_frame(fmt_ctx, pkt);
    if (read_res < 0) {
      if (read_res == AVERROR_EOF || !self->is_running) {
        g_printerr("[stream_texture_worker] av_read_frame returned EOF or stopped! (res=%d, is_running=%d)\n",
                   read_res, self->is_running);
        break;
      }
      static int s_err_count = 0;
      if (++s_err_count % 50 == 1) {
        g_printerr("[stream_texture_worker] av_read_frame temp error: %d\n", read_res);
      }
      g_usleep(10000);
      continue;
    }

    if (pkt->stream_index == video_stream_idx) {
      int send_res = avcodec_send_packet(codec_ctx, pkt);
      if (send_res == 0) {
        int recv_res = avcodec_receive_frame(codec_ctx, frame);
        while (recv_res == 0) {
          int frame_w = frame->width;
          int frame_h = frame->height;

          if (frame_w > 0 && frame_h > 0) {
            // Allocate generous headroom to prevent frequent reallocations during resizing
            size_t req_size = (size_t)frame_w * frame_h * 4 + 65536;

            g_mutex_lock(&self->mutex);
            if (req_size > self->buffer_capacity || self->worker_buffer == nullptr ||
                self->ready_buffer == nullptr || self->render_buffer == nullptr) {
              uint8_t* new_worker = (uint8_t*)g_malloc0(req_size);
              uint8_t* new_ready  = (uint8_t*)g_malloc0(req_size);
              uint8_t* new_render = (uint8_t*)g_malloc0(req_size);

              if (self->worker_buffer) g_free(self->worker_buffer);
              if (self->ready_buffer) g_free(self->ready_buffer);
              if (self->render_buffer) g_free(self->render_buffer);

              self->worker_buffer = new_worker;
              self->ready_buffer = new_ready;
              self->render_buffer = new_render;
              self->buffer_capacity = req_size;
            }

            if (self->width != (uint32_t)frame_w || self->height != (uint32_t)frame_h || sws_ctx == nullptr) {
              self->width = (uint32_t)frame_w;
              self->height = (uint32_t)frame_h;
              if (sws_ctx) sws_freeContext(sws_ctx);
              sws_ctx = sws_getContext(
                  frame_w, frame_h, (AVPixelFormat)frame->format,
                  frame_w, frame_h, AV_PIX_FMT_RGBA,
                  SWS_FAST_BILINEAR, nullptr, nullptr, nullptr);
            }
            g_mutex_unlock(&self->mutex);

            if (sws_ctx && self->worker_buffer) {
              uint8_t* dest_slices[4] = {self->worker_buffer, nullptr, nullptr, nullptr};
              int dest_strides[4] = {frame_w * 4, 0, 0, 0};

              sws_scale(sws_ctx, frame->data, frame->linesize, 0, frame_h, dest_slices, dest_strides);

              gboolean schedule_notif = FALSE;
              g_mutex_lock(&self->mutex);
              // Safely exchange worker_buffer with ready_buffer (triple-buffering).
              // Flutter render thread owns render_buffer independently; no data races!
              std::swap(self->ready_buffer, self->worker_buffer);
              self->has_new_frame = TRUE;

              if (!self->notification_pending && self->is_running && self->registrar) {
                self->notification_pending = TRUE;
                schedule_notif = TRUE;
              }
              g_mutex_unlock(&self->mutex);

              if (schedule_notif) {
                g_object_ref(self);
                auto* notif = new TextureFrameNotification{self->registrar, FL_TEXTURE(self), self};
                g_idle_add(on_frame_available_idle, notif);
              }
            }
          }
          recv_res = avcodec_receive_frame(codec_ctx, frame);
        }
      } else {
        g_printerr("[stream_texture_worker] avcodec_send_packet error: %d\n", send_res);
      }
    }
    av_packet_unref(pkt);
  }

  if (sws_ctx) sws_freeContext(sws_ctx);
  if (pkt) av_packet_free(&pkt);
  if (frame) av_frame_free(&frame);
  if (codec_ctx) avcodec_free_context(&codec_ctx);
  avformat_close_input(&fmt_ctx);

  return nullptr;
}

StreamTexture* stream_texture_new(FlTextureRegistrar* registrar, const gchar* source_path, int width, int height) {
  StreamTexture* self = STREAM_TEXTURE(g_object_new(stream_texture_get_type(), nullptr));
  self->registrar = registrar;
  self->source_path = g_strdup(source_path);
  self->width = (uint32_t)width;
  self->height = (uint32_t)height;
  self->is_running = TRUE;
  self->notification_pending = FALSE;
  self->has_new_frame = FALSE;

  // Allocate 1080p+ capacity up-front (approx 10MB) to prevent in-flight reallocations
  size_t init_size = (size_t)width * height * 4 + 65536;
  if (init_size < (size_t)1920 * 1080 * 4 + 65536) {
    init_size = (size_t)1920 * 1080 * 4 + 65536;
  }
  self->buffer_capacity = init_size;
  self->render_buffer = (uint8_t*)g_malloc0(init_size);
  self->ready_buffer  = (uint8_t*)g_malloc0(init_size);
  self->worker_buffer = (uint8_t*)g_malloc0(init_size);

  // Pre-fill initial render_buffer with dark slate background (15, 23, 42, 255)
  for (size_t i = 0; i < (size_t)width * height * 4; i += 4) {
    self->render_buffer[i]     = 15;
    self->render_buffer[i + 1] = 23;
    self->render_buffer[i + 2] = 42;
    self->render_buffer[i + 3] = 255;
    self->ready_buffer[i]      = 15;
    self->ready_buffer[i + 1]  = 23;
    self->ready_buffer[i + 2]  = 42;
    self->ready_buffer[i + 3]  = 255;
  }
  self->has_new_frame = TRUE;

  self->worker_thread = g_thread_new("stream-texture-worker", stream_texture_worker, self);
  return self;
}

void stream_texture_stop(StreamTexture* self) {
  if (!self) return;

  self->is_running = FALSE;
  if (self->worker_thread) {
    // Poke the FIFO pipe with non-blocking write to immediately unblock any stuck av_read_frame()
    if (self->source_path) {
      int poke_fd = open(self->source_path, O_WRONLY | O_NONBLOCK);
      if (poke_fd >= 0) {
        close(poke_fd);
      }
    }
    g_thread_join(self->worker_thread);
    self->worker_thread = nullptr;
  }
}

// =============================================================================
// Platform Method Channel Implementation
// =============================================================================

static void handle_method_call(FlMethodChannel* channel,
                               FlMethodCall* method_call,
                               gpointer user_data) {
  FlPluginRegistrar* registrar = FL_PLUGIN_REGISTRAR(user_data);
  FlTextureRegistrar* texture_registrar = fl_plugin_registrar_get_texture_registrar(registrar);

  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  if (g_strcmp0(method, "startStream") == 0) {
    const gchar* path = "/tmp/opendex_stream.mkv";
    int width = 720;
    int height = 1280;

    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* p = fl_value_lookup_string(args, "path");
      if (p && fl_value_get_type(p) == FL_VALUE_TYPE_STRING) {
        path = fl_value_get_string(p);
      }
      FlValue* w = fl_value_lookup_string(args, "width");
      if (w && fl_value_get_type(w) == FL_VALUE_TYPE_INT) {
        width = (int)fl_value_get_int(w);
      }
      FlValue* h = fl_value_lookup_string(args, "height");
      if (h && fl_value_get_type(h) == FL_VALUE_TYPE_INT) {
        height = (int)fl_value_get_int(h);
      }
    }

    StreamTexture* texture = stream_texture_new(texture_registrar, path, width, height);
    if (!fl_texture_registrar_register_texture(texture_registrar, FL_TEXTURE(texture))) {
      fl_method_call_respond_error(method_call, "TEXTURE_REGISTRATION_FAILED",
                                   "Failed to register texture with registrar", nullptr, nullptr);
      g_object_unref(texture);
      return;
    }

    int64_t texture_id = fl_texture_get_id(FL_TEXTURE(texture));
    {
      std::lock_guard<std::mutex> lock(g_textures_mutex);
      g_active_textures[texture_id] = texture;
    }

    g_autoptr(FlValue) result = fl_value_new_int(texture_id);
    fl_method_call_respond_success(method_call, result, nullptr);

  } else if (g_strcmp0(method, "stopStream") == 0) {
    int64_t texture_id = -1;
    if (args && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* id_val = fl_value_lookup_string(args, "textureId");
      if (id_val && fl_value_get_type(id_val) == FL_VALUE_TYPE_INT) {
        texture_id = fl_value_get_int(id_val);
      }
    }

    StreamTexture* texture = nullptr;
    {
      std::lock_guard<std::mutex> lock(g_textures_mutex);
      auto it = g_active_textures.find(texture_id);
      if (it != g_active_textures.end()) {
        texture = it->second;
        g_active_textures.erase(it);
      }
    }

    if (texture) {
      stream_texture_stop(texture);
      fl_texture_registrar_unregister_texture(texture_registrar, FL_TEXTURE(texture));
      g_object_unref(texture);
    }

    g_autoptr(FlValue) result = fl_value_new_bool(TRUE);
    fl_method_call_respond_success(method_call, result, nullptr);

  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

void stream_texture_plugin_register(FlPluginRegistrar* registrar) {
  signal(SIGPIPE, SIG_IGN);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlBinaryMessenger) messenger = fl_plugin_registrar_get_messenger(registrar);

  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
      messenger, "open_android_dex/stream", FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(
      channel, handle_method_call, g_object_ref(registrar), g_object_unref);
}
