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

  auto pixel_buffer_texture = std::make_unique<flutter::PixelBufferTexture>(
      [this](size_t w, size_t h) -> const FlutterDesktopPixelBuffer* {
        return this->CopyPixelBuffer(w, h);
      });

  texture_variant_ = std::make_unique<flutter::TextureVariant>(std::move(pixel_buffer_texture));
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
  if (!is_running_) return;
  is_running_ = false;

  if (worker_thread_.joinable()) {
    worker_thread_.join();
  }
}

const FlutterDesktopPixelBuffer* StreamTextureWindows::CopyPixelBuffer(size_t width,
                                                                      size_t height) {
  std::lock_guard<std::mutex> lock(mutex_);
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
#ifdef HAVE_FFMPEG
  AVFormatContext* format_ctx = nullptr;
  AVCodecContext* codec_ctx = nullptr;
  SwsContext* sws_ctx = nullptr;
  AVPacket* packet = av_packet_alloc();
  AVFrame* frame = av_frame_alloc();
  AVFrame* frame_rgba = av_frame_alloc();

  int video_stream_idx = -1;
  while (is_running_) {
    if (avformat_open_input(&format_ctx, source_path_.c_str(), nullptr, nullptr) < 0) {
      std::this_thread::sleep_for(std::chrono::milliseconds(100));
      continue;
    }
    if (avformat_find_stream_info(format_ctx, nullptr) < 0) {
      avformat_close_input(&format_ctx);
      std::this_thread::sleep_for(std::chrono::milliseconds(100));
      continue;
    }
    for (unsigned int i = 0; i < format_ctx->nb_streams; i++) {
      if (format_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
        video_stream_idx = i;
        break;
      }
    }
    if (video_stream_idx >= 0) break;
    avformat_close_input(&format_ctx);
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
  }

  if (video_stream_idx >= 0 && format_ctx) {
    const AVCodec* codec = avcodec_find_decoder(format_ctx->streams[video_stream_idx]->codecpar->codec_id);
    if (codec) {
      codec_ctx = avcodec_alloc_context3(codec);
      avcodec_parameters_to_context(codec_ctx, format_ctx->streams[video_stream_idx]->codecpar);
      if (avcodec_open2(codec_ctx, codec, nullptr) == 0) {
        sws_ctx = sws_getContext(codec_ctx->width, codec_ctx->height, codec_ctx->pix_fmt,
                                 width_, height_, AV_PIX_FMT_RGBA,
                                 SWS_BILINEAR, nullptr, nullptr, nullptr);

        while (is_running_) {
          if (av_read_frame(format_ctx, packet) < 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            continue;
          }
          if (packet->stream_index == video_stream_idx) {
            if (avcodec_send_packet(codec_ctx, packet) == 0) {
              while (avcodec_receive_frame(codec_ctx, frame) == 0) {
                {
                  std::lock_guard<std::mutex> lock(mutex_);
                  uint8_t* dst_data[4] = {worker_buffer_.data(), nullptr, nullptr, nullptr};
                  int dst_linesize[4] = {static_cast<int>(width_ * 4), 0, 0, 0};
                  sws_scale(sws_ctx, frame->data, frame->linesize, 0, codec_ctx->height,
                            dst_data, dst_linesize);
                  std::swap(ready_buffer_, worker_buffer_);
                  has_new_frame_ = true;
                }
                if (registrar_ && texture_id_ >= 0) {
                  registrar_->MarkTextureFrameAvailable(texture_id_);
                }
              }
            }
          }
          av_packet_unref(packet);
        }
      }
    }
  }

  if (sws_ctx) sws_freeContext(sws_ctx);
  if (codec_ctx) avcodec_free_context(&codec_ctx);
  if (format_ctx) avformat_close_input(&format_ctx);
  if (frame) av_frame_free(&frame);
  if (frame_rgba) av_frame_free(&frame_rgba);
  if (packet) av_packet_free(&packet);

#else
  // Native Win32 Named Pipe / File reader fallback loop
  HANDLE pipe_handle = INVALID_HANDLE_VALUE;
  bool is_named_pipe = (source_path_.rfind("\\\\.\\pipe\\", 0) == 0);

  if (is_named_pipe) {
    pipe_handle = CreateNamedPipeA(
        source_path_.c_str(),
        PIPE_ACCESS_INBOUND,
        PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
        1,
        65536,
        65536,
        3000,
        nullptr);
  }

  while (is_running_) {
    if (is_named_pipe && pipe_handle != INVALID_HANDLE_VALUE) {
      ConnectNamedPipe(pipe_handle, nullptr);
      std::vector<uint8_t> temp_chunk(65536);
      DWORD bytes_read = 0;
      while (is_running_ && ReadFile(pipe_handle, temp_chunk.data(), static_cast<DWORD>(temp_chunk.size()), &bytes_read, nullptr)) {
        if (bytes_read > 0) {
          {
            std::lock_guard<std::mutex> lock(mutex_);
            has_new_frame_ = true;
          }
          if (registrar_ && texture_id_ >= 0) {
            registrar_->MarkTextureFrameAvailable(texture_id_);
          }
        }
      }
      DisconnectNamedPipe(pipe_handle);
    } else {
      std::this_thread::sleep_for(std::chrono::milliseconds(33));
      {
        std::lock_guard<std::mutex> lock(mutex_);
        has_new_frame_ = true;
      }
      if (registrar_ && texture_id_ >= 0) {
        registrar_->MarkTextureFrameAvailable(texture_id_);
      }
    }
  }

  if (pipe_handle != INVALID_HANDLE_VALUE) {
    CloseHandle(pipe_handle);
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

    {
      std::lock_guard<std::mutex> lock(g_textures_mutex);
      auto it = g_active_textures.find(texture_id);
      if (it != g_active_textures.end()) {
        it->second->Stop();
        g_active_textures.erase(it);
      }
    }

    result->Success(flutter::EncodableValue(true));

  } else {
    result->NotImplemented();
  }
}

void StreamTexturePluginRegister(flutter::BinaryMessenger* messenger,
                                 flutter::TextureRegistrar* registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "open_android_dex/stream", &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [registrar](const flutter::MethodCall<flutter::EncodableValue>& call,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        HandleMethodCall(call, std::move(result), registrar);
      });
}
