import 'package:flutter/services.dart';

class TextureStreamChannel {
  static const MethodChannel _channel =
      MethodChannel('open_android_dex/stream');

  /// Starts listening to a native video stream from [path] and registers an OpenGL / Flutter Texture.
  /// Returns the registered [textureId], which can be passed directly to `Texture(textureId: id)`.
  static Future<int?> startStream({
    required String path,
    required int width,
    required int height,
  }) async {
    try {
      final dynamic result = await _channel.invokeMethod('startStream', {
        'path': path,
        'width': width,
        'height': height,
      });

      if (result is int) {
        return result;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Stops an active stream and frees its native texture buffer.
  static Future<void> stopStream(int textureId) async {
    try {
      await _channel.invokeMethod('stopStream', {'textureId': textureId});
    } catch (_) {}
  }
}
