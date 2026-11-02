#ifndef STREAM_TEXTURE_H_
#define STREAM_TEXTURE_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

G_DECLARE_FINAL_TYPE(StreamTexture, stream_texture, STREAM, TEXTURE, FlPixelBufferTexture)

StreamTexture* stream_texture_new(FlTextureRegistrar* registrar, const gchar* source_path, int width, int height);
void stream_texture_stop(StreamTexture* self);

void stream_texture_plugin_register(FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // STREAM_TEXTURE_H_
