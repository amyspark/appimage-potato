ARG ARCH=x86_64
ARG VERSION=20.04

FROM ghcr.io/amyspark/ubuntu-server:${ARCH}-${VERSION} as base

ARG UBUNTU_RELEASE=focal

# Start off as root
USER root

# Setup the various repositories we are going to need for our dependencies
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates gnupg software-properties-common wget
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add -
RUN add-apt-repository -y ppa:openjdk-r/ppa && apt-add-repository "deb https://apt.kitware.com/ubuntu/ $UBUNTU_RELEASE main"

# Set mirrors up
RUN sed -E -i 's#http://archive\.ubuntu\.com/ubuntu#mirror://mirrors.ubuntu.com/mirrors.txt#g' /etc/apt/sources.list && \
  sed -E -i 's#http://security\.ubuntu\.com/ubuntu#mirror://mirrors.ubuntu.com/mirrors.txt#g' /etc/apt/sources.list

# Update the system...
RUN apt-get update && apt-get upgrade -y

# Some software demands a newer GCC because they're using C++14 stuff, which is just insane
# We do this after the general system update to ensure it doesn't bring in any unnecessary updates
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test && apt-get update

# Krita's dependencies (libheif's avif plugins) need Rust 
RUN add-apt-repository -y ppa:ubuntu-mozilla-security/rust-updates && apt-get update && apt-get install -y cargo rustc

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
  # Base system deps
  gperf libnss3-dev libpci-dev libatkmm-1.6-dev libbz2-dev libcap-dev libdbus-1-dev libudev-dev \
  # OpenSSL (1.1.1f) and libgcrypt (1.8.5) libraries 
  libssl-dev libgcrypt-dev \
  # DRM and openGL libraries
  libdrm-dev libegl1-mesa-dev libgl1-mesa-dev mesa-common-dev \
  # AMY: on arm64, libegl1-mesa-dev does not bring in libxkbcommon-dev
  libxkbcommon-dev \
  # Font libraries (TODO: consider removal)
  libfontconfig1-dev libfreetype6-dev \
  # GNU Scientific Library
  libgsl-dev \
  # GStreamer pugins for Qt Multimedia
  libpulse-dev libasound2-dev \
  gstreamer1.0-alsa gstreamer1.0-pulseaudio gstreamer1.0-plugins-base gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly \
  libgstreamer1.0-dev libgstreamer-plugins-good1.0-dev libgstreamer-plugins-bad1.0-dev libgstreamer-plugins-base1.0-dev \
  # XCB Libraries for Qt
  libwayland-dev \
  libicu-dev libxcb-shm0-dev libxinerama-dev libxcb-icccm4-dev libxcb-xinerama0-dev libxcb-image0-dev libxcb-render-util0-dev \
  libx11-dev libxkbcommon-x11-dev libxcb-glx0-dev libxcb-keysyms1-dev libxcb-util0-dev libxcb-res0-dev libxcb1-dev \
  libxcomposite-dev libxcursor-dev libxdamage-dev libxext-dev libxfixes-dev libxi-dev libxrandr-dev libxrender-dev \
  libxcb-randr0-dev libxcb-shape0-dev libxcb-xfixes0-dev libxcb-sync-dev libxcb-xinput-dev \
  libxss-dev libxtst-dev \
  # Krita AppImage Python extra dependencies
  libffi-dev \
  # Other
  flex ninja-build python3-pip \
  # Support OpenGL ES
  libgles2-mesa-dev \
  # cppcheck is necessary for the CI
  cppcheck

# Since recently we build Python ourselves, so there is no need for the deadsnake's repo
# (at least until we recover system-provided python)
## The deadsnakes PPA packs setuptools and pip inside python3.10-venv
# RUN add-apt-repository -y ppa:deadsnakes/ppa && apt-get update && apt-get install -y python3.10 python3.10-dev python3.10-venv && python3.10 -m ensurepip 

# Krita's dependencies (libheif's avif plugins) need meson and ninja
# Meson is available in binary form for 20.04
# AMY: Ninja on 20.04 LTS is 1.10 which is good enough
RUN apt-get install -y python3-pip && python3 -m pip install meson

RUN apt-get install --yes ccache python3-yaml python3-packaging python3-lxml python3-clint openbox xvfb dbus-x11
# See bug for gcovr: https://github.com/gcovr/gcovr/issues/583
RUN python3 -m pip install python-gitlab gcovr==5.0 cppcheck-codequality

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 20 && \
     update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 10 && \
     update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 20 && \
     update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 10 && \
     update-alternatives --install /usr/bin/gcov gcov /usr/bin/gcov-11 20 && \
     update-alternatives --install /usr/bin/gcov gcov /usr/bin/gcov-9 10 && \
     update-alternatives --install /usr/bin/gcov-dump gcov-dump /usr/bin/gcov-dump-11 20 && \
     update-alternatives --install /usr/bin/gcov-dump gcov-dump /usr/bin/gcov-dump-9 10 && \
     update-alternatives --install /usr/bin/gcov-tool gcov-tool /usr/bin/gcov-tool-11 20 && \
     update-alternatives --install /usr/bin/gcov-tool gcov-tool /usr/bin/gcov-tool-9 10

# For D-Bus to be willing to start it needs a Machine ID
RUN dbus-uuidgen > /etc/machine-id
# Certain X11 based software is very particular about permissions and ownership around /tmp/.X11-unix/ so ensure this is right
RUN mkdir /tmp/.X11-unix/ && chown root:root /tmp/.X11-unix/ && chmod 1777 /tmp/.X11-unix/

# Setup a user account for everything else to be done under
RUN useradd -d /home/appimage/ -u 1000 --user-group --create-home -G video appimage
# Make sure SSHD will be able to startup
RUN mkdir /var/run/sshd/
# Get locales in order
RUN locale-gen en_US en_US.UTF-8 en_NZ.UTF-8

###
### Prepare ninja
###

# FROM base as ninja

# ARG NINJA_VERSION=1.11.1

# RUN cd /tmp && \
#   wget -c https://github.com/ninja-build/ninja/archive/refs/tags/v${NINJA_VERSION}.tar.gz && \
#   tar xf v${NINJA_VERSION}.tar.gz && \
#   cd ninja-${NINJA_VERSION} && \
#   python3 ./configure.py --bootstrap && \
#   mkdir -p /tmp/ninja/bin && \
#   cp ./ninja /tmp/ninja/bin/

###
### Prepare appimagetool
###

FROM base as appimagetool

ARG QEMU_EXECUTABLE

# https://github.com/AppImageCommunity/AppImageBuild/blob/5100790d827cb746079f2c2f4481baf509c51818/install-deps-ubuntu.sh#L8-L36
RUN apt-get install -y \
    libfuse-dev \
    desktop-file-utils \
    ca-certificates \
    gcc \
    g++ \
    make \
    build-essential \
    git \
    automake \
    autoconf \
    libtool \
    libtool-bin \
    patch \
    wget \
    vim-common \
    desktop-file-utils \
    pkg-config \
    libarchive-dev \
    librsvg2-dev \
    librsvg2-bin \
    liblzma-dev \
    cmake \
    libssl-dev \
    zsync \
    fuse \
    gettext \
    bison \
    libgpgme-dev \
    texinfo

RUN git clone --recursive https://github.com/AppImage/AppImageKit.git /tmp/src

# https://bugs.gentoo.org/706456 AppImageTool can NOT be compiled with GCC > 10
# until the squashfs-tools pulls at least 4.4-git.1
# See https://github.com/plougher/squashfs-tools/commit/fe2f5da4b0f8994169c53e84b7cb8a0feefc97b5
RUN cd /tmp/src && \
    env CC=gcc-9 CXX=g++-9 cmake . -DCMAKE_INSTALL_PREFIX=/tmp/appimagetool.AppDir/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=ON && \
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

COPY --from=patchelf /tmp/patchelf /usr/local

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
# COPY --from=ninja /tmp/ninja /usr/local

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
