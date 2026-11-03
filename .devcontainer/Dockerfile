FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

RUN apt update && apt install -y \
    bash \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-4-dev \
    libgtk-3-dev \
    libglib2.0-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    adb \
    scrcpy \
    python3 \
    python3-pip \
    python3-gi \
    python3-gi-cairo \
    gir1.2-gtk-4.0 \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK
ENV FLUTTER_HOME=/usr/local/flutter
ENV PATH="${FLUTTER_HOME}/bin:${PATH}"

RUN git clone -b stable https://github.com/flutter/flutter.git ${FLUTTER_HOME} \
    && flutter config --no-analytics \
    && flutter config --enable-linux-desktop \
    && flutter precache --linux

WORKDIR /workspace
CMD ["/bin/bash"]

