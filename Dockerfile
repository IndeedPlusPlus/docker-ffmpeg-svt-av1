FROM debian AS builder

RUN apt-get update && \
    apt-get -y dist-upgrade && \
    apt-get -y install build-essential git cmake nasm

WORKDIR /tmp

RUN git clone --depth=1 https://github.com/AOMediaCodec/SVT-AV1 && \
   cd SVT-AV1 && \
   cd Build && \
   cmake .. -G"Unix Makefiles" -DCMAKE_BUILD_TYPE=Release && \
   make -j && \
   make install

RUN apt-get -y install ninja-build meson libtool libass-dev libvorbis-dev libx264-dev libx265-dev libnuma-dev libvpx-dev libgmp-dev libgnutls28-dev libmp3lame-dev libopus-dev

RUN git clone --depth=1 https://code.videolan.org/videolan/dav1d.git dav1d
WORKDIR /tmp/dav1d 
RUN mkdir build && cd build && meson .. -Dprefix=/usr/local -Dlibdir=/usr/local/lib && ninja && ninja install

WORKDIR /tmp/

RUN git clone --depth=1 https://github.com/FFmpeg/FFmpeg ffmpeg
WORKDIR /tmp/ffmpeg
RUN export LD_LIBRARY_PATH="/usr/local/lib" && \
   export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" && \
   ./configure --disable-debug --disable-autodetect --disable-doc --disable-static --disable-hwaccels --enable-shared --disable-stripping --enable-lto --disable-libxcb --disable-alsa --disable-fontconfig --disable-avisynth --disable-libfreetype --disable-sdl2 --disable-ffplay --disable-xlib --disable-vdpau --disable-vaapi --disable-sndio \
    --enable-gmp --enable-gnutls --enable-libopus --enable-libdav1d --enable-gpl --enable-runtime-cpudetect --enable-libass --enable-version3 --enable-libmp3lame --enable-libvorbis --enable-libvpx --enable-libx264 --enable-libx265 --enable-libsvtav1 && \
   make -j && \
   make install

FROM debian

RUN apt-get update && \
    apt-get -y install --no-install-recommends libx264-155 libx265-165 libnuma1 libvpx5 libvorbisenc2 libmp3lame0 libass9 libopus0 && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH="/usr/local/lib"

COPY --from=builder /usr/local/ /usr/local/
RUN ffmpeg -version
