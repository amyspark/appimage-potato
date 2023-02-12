ARG ARCH

FROM ghcr.io/amyspark/ubuntu-server:${ARCH}-18.04 as base

# Start off as root
USER root

# Setup the various repositories we are going to need for our dependencies
# Some software demands a newer GCC because they're using C++14 stuff, which is just insane
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates gnupg software-properties-common wget
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add -
RUN add-apt-repository -y ppa:openjdk-r/ppa && apt-add-repository "deb https://apt.kitware.com/ubuntu/ bionic main"

# Set mirrors up
RUN sed -E -i 's#http://archive\.ubuntu\.com/ubuntu#mirror://mirrors.ubuntu.com/mirrors.txt#g' /etc/apt/sources.list && \
  sed -E -i 's#http://security\.ubuntu\.com/ubuntu#mirror://mirrors.ubuntu.com/mirrors.txt#g' /etc/apt/sources.list

# Update the system and bring in our core operating requirements
RUN apt-get update && apt-get upgrade -y && apt-get install -y openssh-server openjdk-8-jre-headless

# Some software demands a newer GCC because they're using C++14 stuff, which is just insane
# We do this after the general system update to ensure it doesn't bring in any unnecessary updates
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test && apt-get update

# Krita's dependencies (libheif's avif plugins) need Rust 
RUN add-apt-repository -y ppa:ubuntu-mozilla-security/rust-updates && apt-get update && apt-get install -y cargo rustc

# 18.04 attempts to configure tzdata
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Now install the general dependencies we need for builds
RUN apt-get install -y \
  # General requirements for building KDE software
  build-essential gcc-11 g++-11 cmake git-core locales rsync \
  # General requirements for building other software
  automake libxml-parser-perl libpq-dev libaio-dev \
  # Needed for some frameworks
  bison gettext \
  # Qt and KDE Build Dependencies
  gperf libasound2-dev libatkmm-1.6-dev libbz2-dev libcairo-perl libcap-dev libcups2-dev libdbus-1-dev \
  libdrm-dev libegl1-mesa-dev libfontconfig1-dev libfreetype6-dev libgcrypt20-dev libgl1-mesa-dev \
  # AMY: on arm64, libegl1-mesa-dev does not bring in libxkbcommon-dev
  libxkbcommon-dev \
  libglib-perl libgsl0-dev libgsl0-dev gstreamer1.0-alsa libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libjpeg-dev libnss3-dev libpci-dev libpng-dev libpulse-dev libssl-dev \
  libgstreamer-plugins-good1.0-dev libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly gstreamer1.0-pulseaudio libtiff5-dev libudev-dev libwebp-dev flex libmysqlclient-dev libicu-dev \
  # QX11Extras deps in Qt 5.15.7
  libxcb-shm0-dev libxinerama-dev libxcb-icccm4-dev libxcb-xinerama0-dev libxcb-image0-dev libxcb-render-util0-dev \
  # Mesa libraries for everything to use
  libx11-dev libxkbcommon-x11-dev libxcb-glx0-dev libxcb-keysyms1-dev libxcb-util0-dev libxcb-res0-dev libxcb1-dev libxcomposite-dev libxcursor-dev \
  libxdamage-dev libxext-dev libxfixes-dev libxi-dev libxrandr-dev libxrender-dev libxss-dev libxtst-dev mesa-common-dev \
  # Krita AppImage (Python) extra dependencies
  libffi-dev \
  # Kdenlive AppImage extra dependencies
  liblist-moreutils-perl libtool libpixman-1-dev subversion \
  # Support OpenGL ES
  libgles2-mesa-dev
# Krita's dependencies (libheif's avif plugins) need meson and ninja, both aren't available in binary form for 18.04
# The deadsnakes PPA packs setuptools and pip inside python3.9-venv, let's deploy it manually
RUN add-apt-repository -y ppa:deadsnakes/ppa && apt-get update && apt-get install -y python3.9 python3.9-dev python3.9-venv && python3.9 -m ensurepip 
RUN python3.9 -m pip install meson

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 10 && \
  update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 20 && \
  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 10 && \
  update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 20

# Setup a user account for everything else to be done under
RUN useradd -d /home/appimage/ -u 1000 --user-group --create-home -G video appimage
# Make sure SSHD will be able to startup
RUN mkdir /var/run/sshd/
# Get locales in order
RUN locale-gen en_US en_US.UTF-8 en_NZ.UTF-8

###
### Prepare ninja
###

FROM base as ninja

ARG NINJA_VERSION=1.10.2

RUN cd /tmp && \
  wget -c https://github.com/ninja-build/ninja/archive/refs/tags/v${NINJA_VERSION}.tar.gz && \
  tar xf v${NINJA_VERSION}.tar.gz && \
  cd ninja-${NINJA_VERSION} && \
  python3 ./configure.py --bootstrap && \
  mkdir -p /tmp/ninja/bin && \
  cp ./ninja /tmp/ninja/bin/

###
### Prepare appimagetool
###

FROM base as appimagetool

ARG QEMU_EXECUTABLE

RUN apt-get install -y build-essential automake cmake desktop-file-utils \
  libcairo2-dev \
  libarchive-dev liblzma-dev \
  libglib2.0-dev libssl-dev libfuse-dev libtool \
  libgpgme-dev libgcrypt20-dev \
  pkg-config vim zsync

# Cloning my repository to fix https://github.com/AppImage/AppImageKit/pull/1203#issuecomment-1199568648
RUN git clone --recursive https://github.com/amyspark/AppImageKit.git /tmp/src

RUN cd /tmp/src && \
    cmake . -DCMAKE_INSTALL_PREFIX=/tmp/appimagetool.AppDir/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=ON && \
    nice -n 20 cmake --build . --target install --parallel

RUN cd /tmp/ &&\
    cp /tmp/src/resources/AppRun /tmp/appimagetool.AppDir/ && \
    cp "$(which desktop-file-validate)" /tmp/appimagetool.AppDir/usr/bin/ && \
    cp "$(which zsyncmake)" /tmp/appimagetool.AppDir/usr/bin/ && \
    cp /tmp/src/resources/appimagetool.desktop /tmp/appimagetool.AppDir/ && \
    cp /tmp/src/resources/appimagetool.png /tmp/appimagetool.AppDir/ && \
    cp /tmp/src/resources/appimagetool.png /tmp/appimagetool.AppDir/.DirIcon && \
    /tmp/appimagetool.AppDir/AppRun /tmp/appimagetool.AppDir/ -v \
    appimagetool-"$(uname -m)"-"$(env GIT_DIR=/tmp/src/.git git rev-parse --short HEAD)".AppImage && \
    sha256sum /tmp/appimagetool-*.AppImage && \
    chmod +x /tmp/appimagetool*AppImage && \
    mkdir appimagetool && \
    cd appimagetool && \
    ${QEMU_EXECUTABLE} /tmp/appimagetool*AppImage --appimage-extract && \
    chmod +rx squashfs-root/usr/lib/appimagekit

###
### Prepare patchelf
###

FROM base AS patchelf

RUN cd /tmp && \
  wget -c https://nixos.org/releases/patchelf/patchelf-0.9/patchelf-0.9.tar.bz2 && \ 
  tar xf patchelf-0.9.tar.bz2 && \
  cd patchelf-0.9/ && \
  ./configure --prefix=/tmp/patchelf && \
  nice -n 20 make -j$(nproc) && \
  nice -n 20 make -j$(nproc) install

###
### Prepare linuxdeployqt
###

FROM base as linuxdeployqt

ARG QEMU_EXECUTABLE

COPY --from=patchelf /tmp/patchelf /

COPY --from=appimagetool  /tmp/appimagetool/squashfs-root/usr/ /usr/local

RUN apt-get install -y \
  qt5-default qtbase5-dev qttools5-dev-tools

RUN cd /tmp && \
  git clone https://github.com/probonopd/linuxdeployqt.git src && \
  cd src && \
  qmake CONFIG+=release CONFIG+=force_debug_info linuxdeployqt.pro && \
  make -j$(nproc) && \
  mkdir -p linuxdeployqt.AppDir/usr/bin && \
  mkdir -p linuxdeployqt.AppDir/usr/lib && \
  cp ./bin/linuxdeployqt linuxdeployqt.AppDir/usr/bin/ && \
  chmod +x linuxdeployqt.AppDir/AppRun && \
  ./bin/linuxdeployqt linuxdeployqt.AppDir/linuxdeployqt.desktop -verbose=3 -appimage -executable=linuxdeployqt.AppDir/usr/bin/linuxdeployqt && \
  cd /tmp && \
  mkdir linuxdeployqt && \
  cd linuxdeployqt && \
  ${QEMU_EXECUTABLE} /tmp/src/linuxdeployqt*AppImage --appimage-extract

###
# Merge all tools (into /usr/local, that folder is ignored by Krita scripts)
###

FROM base

ARG ARCH
ARG BUILD_REF
ARG BUILD_DATE

LABEL org.label-schema.build-date=${BUILD_DATE}
LABEL org.label-schema.name="KDE Appimage Base (${ARCH})"
LABEL org.label-schema.url="https://invent.kde.org/sysadmin/ci-images"
LABEL org.label-schema.vcs-ref=${BUILD_REF}
LABEL org.label-schema.vcs-url="https://github.com/amyspark/appimage-potato"
LABEL org.label-schema.vendor="Amyspark"
LABEL org.label-schema.schema-version="1.0"

# Install ninja
COPY --from=ninja /tmp/ninja /usr/local

# Install patchelf
COPY --from=patchelf /tmp/patchelf /usr/local

# Install linuxdeployqt
COPY --from=linuxdeployqt /tmp/linuxdeployqt/squashfs-root/usr/ /usr/local

# Install appimagetool
COPY --from=appimagetool  /tmp/appimagetool/squashfs-root/usr/ /usr/local

# Workaround: patch appimagetool having a wrong rpath
RUN sh -c "find /usr/local/lib -name '*.so*' | xargs -I % patchelf --set-rpath '$ORIGIN' %" && \
  patchelf --set-rpath '$ORIGIN/../lib' /usr/local/bin/appimagetool

USER appimage
