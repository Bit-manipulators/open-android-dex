#!/usr/bin/env bash
# ==============================================================================
# Open Android DeX — Build Minimal Self-Contained Static FFmpeg
# Produces: libavcodec.a, libavformat.a, libswscale.a, libavutil.a
# Eliminates external dynamic library dependencies (libgme, libx264, etc.)
# so the AppImage runs portably across any Linux distribution (Arch, Fedora, Debian, Ubuntu).
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DEST_DIR="${1:-${REPO_ROOT}/build/ffmpeg_static}"

if [ -f "${DEST_DIR}/lib/libavcodec.a" ] && \
   [ -f "${DEST_DIR}/lib/libavformat.a" ] && \
   [ -f "${DEST_DIR}/lib/libswscale.a" ] && \
   [ -f "${DEST_DIR}/lib/libavutil.a" ]; then
    echo "✅ Minimal static FFmpeg already built at ${DEST_DIR}"
    exit 0
fi

echo "============================================================"
echo "  🚀 Building Minimal Static FFmpeg for Open Android DeX"
echo "  Target: ${DEST_DIR}"
echo "============================================================"

CACHE_DIR="${REPO_ROOT}/build/downloads"
mkdir -p "${CACHE_DIR}"
FFMPEG_VERSION="4.4.4"
TARBALL="${CACHE_DIR}/ffmpeg-${FFMPEG_VERSION}.tar.xz"

if [ ! -f "${TARBALL}" ]; then
    echo "==> Downloading FFmpeg ${FFMPEG_VERSION} source..."
    curl -fsSL -o "${TARBALL}" "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz"
fi

BUILD_DIR=$(mktemp -d -t ffmpeg_build_XXXXXX)
trap 'rm -rf "${BUILD_DIR}"' EXIT

echo "==> Extracting FFmpeg source..."
tar -xf "${TARBALL}" -C "${BUILD_DIR}" --strip-components=1

cd "${BUILD_DIR}"

echo "==> Configuring minimal static FFmpeg..."
./configure \
    --prefix="${DEST_DIR}" \
    --enable-static \
    --disable-shared \
    --disable-programs \
    --disable-doc \
    --disable-everything \
    --disable-x86asm \
    --disable-network \
    --disable-autodetect \
    --enable-protocol=file,pipe \
    --enable-demuxer=matroska,h264,hevc \
    --enable-parser=h264,hevc \
    --enable-decoder=h264,hevc \
    --enable-swscale \
    --enable-avformat \
    --enable-avcodec \
    --enable-avutil \
    --extra-cflags="-fPIC"

echo "==> Compiling minimal static FFmpeg..."
make -j"$(nproc)"
make install

echo "============================================================"
echo "  ✅ Static FFmpeg successfully built and installed!"
echo "  Location: ${DEST_DIR}"
echo "============================================================"
