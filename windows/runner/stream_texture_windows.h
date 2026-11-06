#ifndef RUNNER_STREAM_TEXTURE_WINDOWS_H_
#define RUNNER_STREAM_TEXTURE_WINDOWS_H_

#include <flutter_windows.h>
#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/pixel_buffer_texture.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/texture_registrar.h>

#include <windows.h>
#include <atomic>
#include <cstdint>
#include <map>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

class StreamTextureWindows {
 public:
  StreamTextureWindows(flutter::TextureRegistrar* registrar,
                       const std::string& source_path,
                       int width,
                       int height);
  ~StreamTextureWindows();

  int64_t texture_id() const { return texture_id_; }
  void Stop();

 private:
  const FlutterDesktopPixelBuffer* CopyPixelBuffer(size_t width, size_t height);
  void WorkerLoop();

  flutter::TextureRegistrar* registrar_ = nullptr;
  std::unique_ptr<flutter::TextureVariant> texture_variant_;
  int64_t texture_id_ = -1;

  std::string source_path_;
  uint32_t width_ = 720;
  uint32_t height_ = 1280;

  std::vector<uint8_t> render_buffer_;
  std::vector<uint8_t> ready_buffer_;
  std::vector<uint8_t> worker_buffer_;
  FlutterDesktopPixelBuffer pixel_buffer_{};

  std::mutex mutex_;
  std::atomic<bool> is_running_{false};
  std::atomic<bool> has_new_frame_{false};
  std::thread worker_thread_;
};

void StreamTexturePluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar);

#endif  // RUNNER_STREAM_TEXTURE_WINDOWS_H_
