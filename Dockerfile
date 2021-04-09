FROM gcc AS builder

RUN apt-get update && \
    apt-get -y dist-upgrade && \
    apt-get -y install curl git cmake nasm ninja-build meson libtool \
      libass-dev libvorbis-dev libx264-dev libnuma-dev libvpx-dev libgmp-dev libgnutls28-dev libmp3lame-dev libopus-dev

WORKDIR /tmp/x265

RUN curl -OL https://bitbucket.org/multicoreware/x265_git/downloads/x265_3.5.tar.gz && \ 
  tar -xvf x265_3.5.tar.gz

WORKDIR /tmp/x265/x265_3.5

RUN cmake -S ./source -B build-12 -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/opt/ffmpeg \
  -DHIGH_BIT_DEPTH=TRUE \
  -DMAIN12=TRUE \
  -DEXPORT_C_API=FALSE \
  -DENABLE_CLI=FALSE \
  -DENABLE_SHARED=FALSE \
  -Wno-dev
RUN ninja -C build-12

RUN cmake -S ./source -B build-10 -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/opt/ffmpeg \
  -DHIGH_BIT_DEPTH=TRUE \
  -DEXPORT_C_API=FALSE \
  -DENABLE_CLI=FALSE \
  -DENABLE_SHARED=FALSE \
  -Wno-dev
RUN ninja -C build-10

RUN cmake -S ./source -B build -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/opt/ffmpeg \
  -DENABLE_SHARED=TRUE \
  -DENABLE_HDR10_PLUS=TRUE \
  -DEXTRA_LIB='x265_main10.a;x265_main12.a' \
  -DEXTRA_LINK_FLAGS='-L .' \
  -DLINKED_10BIT=TRUE \
  -DLINKED_12BIT=TRUE \
  -Wno-dev
RUN ln -s ../build-10/libx265.a build/libx265_main10.a
RUN ln -s ../build-12/libx265.a build/libx265_main12.a
RUN ninja -C build && ninja -C build install

WORKDIR /tmp

RUN git clone --depth=1 https://gitlab.com/AOMediaCodec/SVT-AV1.git && \
   cd SVT-AV1 && \
   cd Build && \
   cmake .. -G"Unix Makefiles" -DSVT_AV1_LTO:BOOL=ON -DCMAKE_INSTALL_PREFIX=/opt/ffmpeg -DCMAKE_BUILD_TYPE=Release && \
   make && \
   make install

RUN git clone --depth=1 https://code.videolan.org/videolan/dav1d.git dav1d
WORKDIR /tmp/dav1d 
RUN mkdir build && cd build && meson .. -Dprefix=/opt/ffmpeg -Dlibdir=/opt/ffmpeg/lib && ninja && ninja install

WORKDIR /tmp/

RUN git clone --depth=1 https://github.com/Netflix/vmaf.git vmaf
WORKDIR /tmp/vmaf
RUN cd libvmaf/ && mkdir build && cd build && meson .. -Dprefix=/opt/ffmpeg -Dlibdir=/opt/ffmpeg/lib && ninja && ninja install
RUN cp -r model/ /usr/local/share/model/

WORKDIR /tmp/

RUN git clone --depth=1 https://github.com/FFmpeg/FFmpeg ffmpeg
WORKDIR /tmp/ffmpeg
RUN export LD_LIBRARY_PATH="/opt/ffmpeg/lib" && \
   export PKG_CONFIG_PATH="/opt/ffmpeg/lib/pkgconfig" && \
   ./configure --prefix=/opt/ffmpeg --disable-debug --disable-autodetect --disable-doc --disable-static --disable-hwaccels --enable-shared --disable-stripping --enable-lto --disable-libxcb --disable-alsa --disable-fontconfig --disable-avisynth --disable-libfreetype --disable-sdl2 --disable-ffplay --disable-xlib --disable-vdpau --disable-vaapi --disable-sndio \
    --enable-gmp --enable-gnutls --enable-libopus --enable-libdav1d --enable-gpl --enable-runtime-cpudetect --enable-libass --enable-version3 --enable-libmp3lame --enable-libvorbis --enable-libvpx --enable-libx264 --enable-libx265 --enable-libvmaf --enable-libsvtav1 && \
   make && \
   make install

FROM debian

RUN apt-get update && \
    apt-get -y install --no-install-recommends libx264-155 libnuma1 libvpx5 libvorbisenc2 libmp3lame0 libass9 libopus0 && \
    apt-get -y clean && \
    rm -rf /var/lib/apt/lists/*

ENV LD_LIBRARY_PATH="/opt/ffmpeg/lib"
ENV PATH="/opt/ffmpeg/bin:$PATH"

COPY --from=builder /opt/ffmpeg/ /opt/ffmpeg/
COPY --from=builder /usr/local/share/model/ /usr/local/share/model/
RUN ffmpeg -version
