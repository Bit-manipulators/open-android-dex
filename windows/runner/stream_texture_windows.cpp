#include "stream_texture_windows.h"

#include <flutter/standard_method_codec.h>

#include <chrono>
#include <iostream>

#ifdef HAVE_FFMPEG
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}
#endif

static std::map<int64_t, std::unique_ptr<StreamTextureWindows>> g_active_textures;
static std::mutex g_textures_mutex;

StreamTextureWindows::StreamTextureWindows(flutter::TextureRegistrar* registrar,
                                           const std::string& source_path,
                                           int width,
                                           int height)
    : registrar_(registrar),
      source_path_(source_path),
      width_((width > 0) ? width : 720),
      height_((height > 0) ? height : 1280) {
  const size_t buffer_size = static_cast<size_t>(width_) * height_ * 4;
  render_buffer_.resize(buffer_size, 0);
  ready_buffer_.resize(buffer_size, 0);
  worker_buffer_.resize(buffer_size, 0);

  // Pre-fill initial buffers with dark slate background (15, 23, 42, 255)
  for (size_t i = 0; i < buffer_size; i += 4) {
    render_buffer_[i] = 15;
    render_buffer_[i + 1] = 23;
    render_buffer_[i + 2] = 42;
    render_buffer_[i + 3] = 255;

    ready_buffer_[i] = 15;
    ready_buffer_[i + 1] = 23;
    ready_buffer_[i + 2] = 42;
    ready_buffer_[i + 3] = 255;
  }

  pixel_buffer_.buffer = render_buffer_.data();
  pixel_buffer_.width = width_;
  pixel_buffer_.height = height_;

  texture_variant_ = std::make_unique<flutter::TextureVariant>(
      flutter::PixelBufferTexture(
          [this](size_t w, size_t h) -> const FlutterDesktopPixelBuffer* {
            return this->CopyPixelBuffer(w, h);
          }));
  texture_id_ = registrar_->RegisterTexture(texture_variant_.get());

  is_running_ = true;
  has_new_frame_ = true;
  worker_thread_ = std::thread(&StreamTextureWindows::WorkerLoop, this);
}

StreamTextureWindows::~StreamTextureWindows() {
  Stop();
  if (registrar_ && texture_id_ >= 0) {
    registrar_->UnregisterTexture(texture_id_);
    texture_id_ = -1;
  }
}

void StreamTextureWindows::Stop() {
  if (is_stopped_.exchange(true)) return;
  is_running_ = false;

  HANDLE h = pipe_handle_.exchange(INVALID_HANDLE_VALUE);
  if (h != INVALID_HANDLE_VALUE) {
    CancelIoEx(h, nullptr);
    CloseHandle(h);
  }

  if (worker_thread_.joinable()) {
    worker_thread_.join();
  }
}

const FlutterDesktopPixelBuffer* StreamTextureWindows::CopyPixelBuffer(size_t width,
                                                                      size_t height) {
  if (is_stopped_.load()) {
    return nullptr;
  }
  std::lock_guard<std::mutex> lock(mutex_);
  if (is_stopped_.load()) {
    return nullptr;
  }
  if (has_new_frame_ && !ready_buffer_.empty()) {
    std::swap(render_buffer_, ready_buffer_);
    has_new_frame_ = false;
  }

  if (!render_buffer_.empty() && width_ > 0 && height_ > 0) {
    pixel_buffer_.buffer = render_buffer_.data();
    pixel_buffer_.width = width_;
    pixel_buffer_.height = height_;
    return &pixel_buffer_;
  }

  return nullptr;
}

void StreamTextureWindows::WorkerLoop() {
  bool is_named_pipe = (source_path_.rfind("\\\\.\\pipe\\", 0) == 0);
  if (is_named_pipe) {
    HANDLE h = CreateNamedPipeA(
        source_path_.c_str(),
        PIPE_ACCESS_INBOUND,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
        1,
        65536,
        65536,
        5000,
        nullptr);
    pipe_handle_.store(h);
  }

#ifdef HAVE_FFMPEG
  HANDLE pipe = pipe_handle_.load();
  if (is_named_pipe && pipe != INVALID_HANDLE_VALUE) {
    BOOL connected = ConnectNamedPipe(pipe, nullptr) ? TRUE : (GetLastError() == ERROR_PIPE_CONNECTED);
    if (!connected && !is_running_) {
      return;
    }
  }

  struct PipeIoContext {
    HANDLE handle;
    std::atomic<bool>* running;
    std::atomic<bool>* stopped;
  };

  PipeIoContext io_ctx{pipe, &is_running_, &is_stopped_};

  auto read_packet = [](void* opaque, uint8_t* buf, int buf_size) -> int {
    auto* ctx = static_cast<PipeIoContext*>(opaque);
    if (!ctx || !ctx->running->load() || ctx->stopped->load()) {
      return AVERROR_EOF;
    }
    HANDLE h = ctx->handle;
    if (h == INVALID_HANDLE_VALUE) {
      return AVERROR_EOF;
    }
    DWORD bytes_read = 0;
    if (!ReadFile(h, buf, static_cast<DWORD>(buf_size), &bytes_read, nullptr)) {
      return AVERROR_EOF;
    }
    if (bytes_read == 0) {
      return AVERROR_EOF;
    }
    return static_cast<int>(bytes_read);
  };

  constexpr size_t kIoBufferSize = 65536;
  auto* avio_buffer = static_cast<unsigned char*>(av_malloc(kIoBufferSize));
  AVIOContext* avio_ctx = avio_alloc_context(
      avio_buffer, kIoBufferSize, 0, &io_ctx, read_packet, nullptr, nullptr);

  AVFormatContext* format_ctx = avformat_alloc_context();
  if (format_ctx && avio_ctx) {
    format_ctx->pb = avio_ctx;
    format_ctx->flags |= AVFMT_FLAG_CUSTOM_IO;

    auto interrupt_cb = [](void* opaque) -> int {
      auto* self = static_cast<StreamTextureWindows*>(opaque);
      if (!self || !self->is_running() || self->is_stopped()) {
        return 1;
      }
      return 0;
    };
    format_ctx->interrupt_callback.callback = interrupt_cb;
    format_ctx->interrupt_callback.opaque = this;

    AVDictionary* opts = nullptr;
    av_dict_set(&opts, "probesize", "262144", 0);
    av_dict_set(&opts, "analyzeduration", "500000", 0);
    av_dict_set(&opts, "fflags", "nobuffer", 0);
    av_dict_set(&opts, "flags", "low_delay", 0);

    bool opened = (avformat_open_input(&format_ctx, nullptr, nullptr, &opts) == 0);
    if (opts) {
      av_dict_free(&opts);
    }

    if (opened) {
      if (avformat_find_stream_info(format_ctx, nullptr) >= 0) {
        int video_stream_idx = -1;
        for (unsigned int i = 0; i < format_ctx->nb_streams; i++) {
          if (format_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            video_stream_idx = static_cast<int>(i);
            break;
          }
        }

        if (video_stream_idx >= 0) {
          const AVCodec* codec = avcodec_find_decoder(
              format_ctx->streams[video_stream_idx]->codecpar->codec_id);
          if (codec) {
            AVCodecContext* codec_ctx = avcodec_alloc_context3(codec);
            avcodec_parameters_to_context(
                codec_ctx, format_ctx->streams[video_stream_idx]->codecpar);
            if (avcodec_open2(codec_ctx, codec, nullptr) == 0) {
              SwsContext* sws_ctx = sws_getContext(
                  codec_ctx->width, codec_ctx->height, codec_ctx->pix_fmt,
                  width_, height_, AV_PIX_FMT_RGBA,
                  SWS_BILINEAR, nullptr, nullptr, nullptr);

              AVPacket* packet = av_packet_alloc();
              AVFrame* frame = av_frame_alloc();

              while (is_running_ && !is_stopped_) {
                if (av_read_frame(format_ctx, packet) < 0) {
                  break;
                }
                if (packet->stream_index == video_stream_idx) {
                  if (avcodec_send_packet(codec_ctx, packet) == 0) {
                    while (avcodec_receive_frame(codec_ctx, frame) == 0) {
                      {
                        std::lock_guard<std::mutex> lock(mutex_);
                        uint8_t* dst_data[4] = {worker_buffer_.data(), nullptr, nullptr, nullptr};
                        int dst_linesize[4] = {static_cast<int>(width_ * 4), 0, 0, 0};
                        sws_scale(sws_ctx, frame->data, frame->linesize, 0,
                                  codec_ctx->height, dst_data, dst_linesize);
                        std::swap(ready_buffer_, worker_buffer_);
                        has_new_frame_ = true;
                      }
                      if (registrar_ && texture_id_ >= 0 && !is_stopped_.load()) {
                        registrar_->MarkTextureFrameAvailable(texture_id_);
                      }
                    }
                  }
                }
                av_packet_unref(packet);
              }

              if (frame) av_frame_free(&frame);
              if (packet) av_packet_free(&packet);
              if (sws_ctx) sws_freeContext(sws_ctx);
            }
            if (codec_ctx) avcodec_free_context(&codec_ctx);
          }
        }
      }
      avformat_close_input(&format_ctx);
    } else {
      avformat_free_context(format_ctx);
    }
  }

  if (avio_ctx) {
    avio_context_free(&avio_ctx);
  }

  HANDLE final_h = pipe_handle_.exchange(INVALID_HANDLE_VALUE);
  if (final_h != INVALID_HANDLE_VALUE) {
    DisconnectNamedPipe(final_h);
    CloseHandle(final_h);
  }

#else
  // Native Win32 Named Pipe / File reader fallback loop
  while (is_running_) {
    HANDLE h = pipe_handle_.load();
    if (is_named_pipe && h != INVALID_HANDLE_VALUE) {
      BOOL connected = ConnectNamedPipe(h, nullptr) ? TRUE : (GetLastError() == ERROR_PIPE_CONNECTED);
      if (!connected && !is_running_) break;
      std::vector<uint8_t> temp_chunk(65536);
      DWORD bytes_read = 0;
      while (is_running_ && h != INVALID_HANDLE_VALUE && ReadFile(h, temp_chunk.data(), static_cast<DWORD>(temp_chunk.size()), &bytes_read, nullptr)) {
        if (bytes_read > 0) {
          {
            std::lock_guard<std::mutex> lock(mutex_);
            has_new_frame_ = true;
          }
          if (registrar_ && texture_id_ >= 0 && !is_stopped_.load()) {
            registrar_->MarkTextureFrameAvailable(texture_id_);
          }
        }
        h = pipe_handle_.load();
      }
      if (h != INVALID_HANDLE_VALUE) {
        DisconnectNamedPipe(h);
      }
    } else {
      std::this_thread::sleep_for(std::chrono::milliseconds(33));
      if (!is_running_) break;
      {
        std::lock_guard<std::mutex> lock(mutex_);
        has_new_frame_ = true;
      }
      if (registrar_ && texture_id_ >= 0 && !is_stopped_.load()) {
        registrar_->MarkTextureFrameAvailable(texture_id_);
      }
    }
  }

  HANDLE final_h = pipe_handle_.exchange(INVALID_HANDLE_VALUE);
  if (final_h != INVALID_HANDLE_VALUE) {
    CloseHandle(final_h);
  }
#endif
}

// =============================================================================
// Platform Method Channel Implementation
// =============================================================================

static void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& method_call,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result,
                             flutter::TextureRegistrar* texture_registrar) {
  const std::string& method = method_call.method_name();

  if (method == "startStream") {
    std::string path = "\\\\.\\pipe\\opendex_stream";
    int width = 720;
    int height = 1280;

    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args) {
      auto path_it = args->find(flutter::EncodableValue("path"));
      if (path_it != args->end() && std::holds_alternative<std::string>(path_it->second)) {
        path = std::get<std::string>(path_it->second);
      }
      auto w_it = args->find(flutter::EncodableValue("width"));
      if (w_it != args->end() && std::holds_alternative<int>(w_it->second)) {
        width = std::get<int>(w_it->second);
      }
      auto h_it = args->find(flutter::EncodableValue("height"));
      if (h_it != args->end() && std::holds_alternative<int>(h_it->second)) {
        height = std::get<int>(h_it->second);
      }
    }

    auto stream_texture = std::make_unique<StreamTextureWindows>(texture_registrar, path, width, height);
    int64_t texture_id = stream_texture->texture_id();

    if (texture_id < 0) {
      result->Error("TEXTURE_REGISTRATION_FAILED", "Failed to register Windows texture");
      return;
    }

    {
      std::lock_guard<std::mutex> lock(g_textures_mutex);
      g_active_textures[texture_id] = std::move(stream_texture);
    }

    result->Success(flutter::EncodableValue(texture_id));

  } else if (method == "stopStream") {
    int64_t texture_id = -1;
    const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
    if (args) {
      auto id_it = args->find(flutter::EncodableValue("textureId"));
      if (id_it != args->end() && std::holds_alternative<int64_t>(id_it->second)) {
        texture_id = std::get<int64_t>(id_it->second);
      } else if (id_it != args->end() && std::holds_alternative<int>(id_it->second)) {
        texture_id = static_cast<int64_t>(std::get<int>(id_it->second));
      }
    }

    std::shared_ptr<StreamTextureWindows> texture_to_delete;
    {
      std::lock_guard<std::mutex> lock(g_textures_mutex);
      auto it = g_active_textures.find(texture_id);
      if (it != g_active_textures.end()) {
        texture_to_delete = std::move(it->second);
        g_active_textures.erase(it);
      }
    }

    if (texture_to_delete) {
      texture_to_delete->Stop();
      auto* reg = texture_to_delete->registrar();
      if (reg && texture_id >= 0) {
        texture_to_delete->ResetTextureId();
        reg->UnregisterTexture(texture_id, [texture_to_delete]() {
          // Safely destroyed after engine confirms unregistration!
        });
      }
    }

    result->Success(flutter::EncodableValue(true));

  } else {
    result->NotImplemented();
  }
}

void StreamTexturePluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  auto plugin_registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);

  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      plugin_registrar->messenger(),
      "open_android_dex/stream",
      &flutter::StandardMethodCodec::GetInstance());

  flutter::TextureRegistrar* texture_registrar = plugin_registrar->texture_registrar();
  channel->SetMethodCallHandler(
      [texture_registrar](const flutter::MethodCall<flutter::EncodableValue>& call,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        HandleMethodCall(call, std::move(result), texture_registrar);
      });
}
