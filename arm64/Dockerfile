FROM multiarch/ubuntu-debootstrap:arm64-xenial as base

# Start off as root
USER root

# Setup the various repositories we are going to need for our dependencies
# Some software demands a newer GCC because they're using C++14 stuff, which is just insane
# AMY: CMake must be compiled manually, Kitware does not provide ARM packages for < 20.04
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates gnupg software-properties-common wget
RUN add-apt-repository -y ppa:openjdk-r/ppa

# Update the system and bring in our core operating requirements
RUN apt-get update && apt-get upgrade -y && apt-get install -y openssh-server openjdk-8-jre-headless

# Some software demands a newer GCC because they're using C++14 stuff, which is just insane
# We do this after the general system update to ensure it doesn't bring in any unnecessary updates
# AMY: Add universe repo at this time, debootstrap does not include it
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test && add-apt-repository universe && apt-get update

# Now install the general dependencies we need for builds
RUN apt-get install -y \
    # General requirements for building KDE software
    # AMY: no CMake, see below
    build-essential git-core locales \
    # General requirements for building other software
    automake gcc-6 g++-6 libxml-parser-perl libpq-dev libaio-dev \
    # Needed for some frameworks
    bison gettext \
    # Qt and KDE Build Dependencies
    gperf libasound2-dev libatkmm-1.6-dev libbz2-dev libcairo-perl libcap-dev libcups2-dev libdbus-1-dev \
    libdrm-dev libegl1-mesa-dev libfontconfig1-dev libfreetype6-dev libgcrypt11-dev libgl1-mesa-dev \
    # AMY: on arm64, libegl1-mesa-dev does not bring in libxkbcommon-dev
    libxkbcommon-dev \
    libglib-perl libgsl0-dev libgsl0-dev gstreamer1.0-alsa libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
    libgtk2-perl libjpeg-dev libnss3-dev libpci-dev libpng12-dev libpulse-dev libssl-dev \
    libgstreamer-plugins-good1.0-dev libgstreamer-plugins-bad1.0-dev gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly libtiff5-dev libudev-dev libwebp-dev flex libmysqlclient-dev \
    # Mesa libraries for everything to use
    libx11-dev libxkbcommon-x11-dev libxcb-glx0-dev libxcb-keysyms1-dev libxcb-util0-dev libxcb-res0-dev libxcb1-dev libxcomposite-dev libxcursor-dev \
    libxdamage-dev libxext-dev libxfixes-dev libxi-dev libxrandr-dev libxrender-dev libxss-dev libxtst-dev mesa-common-dev \
    # Krita AppImage (Python) extra dependencies
    libffi-dev \
    # Kdenlive AppImage extra dependencies
    liblist-moreutils-perl libtool libpixman-1-dev subversion

# Setup a user account for everything else to be done under
RUN useradd -d /home/appimage/ -u 1000 --user-group --create-home -G video appimage

# Get locales in order
RUN locale-gen en_US en_US.UTF-8 en_NZ.UTF-8

###
### Prepare cmake
###

FROM base as cmake

# pip install cmake requires a good enough Python, which is a whole keg of deps
# RUN add-apt-repository ppa:deadsnakes/ppa && apt-get update && apt-get install -y python3.8 && pip install cmake

ARG CMAKE_VERSION=3.19.4

RUN cd /tmp && \
    wget -c https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz && \
    tar xf cmake-${CMAKE_VERSION}.tar.gz && \
    cd cmake-${CMAKE_VERSION} && \
    ./bootstrap --prefix=/tmp/cmake --parallel=$(nproc) && \
    make -j $(nproc) && \
    make -j $(nproc) install

###
### Prepare appimagetool
###

FROM base as appimagetool

# Install appimagetool
RUN cd /tmp && \
    wget -c "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-aarch64.AppImage" && \
    chmod +x appimagetool*AppImage && \
    mkdir appimagetool && \
    cd appimagetool && \
    qemu-aarch64-static /tmp/appimagetool*AppImage --appimage-extract && \
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
    make -j$(nproc) && \
    make -j$(nproc) install

###
### Prepare linuxdeployqt
###

FROM base as linuxdeployqt

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
    qemu-aarch64-static /tmp/src/linuxdeployqt*AppImage --appimage-extract

###
# Merge all tools (into /usr/local, that folder is ignored by Krita scripts)
###

FROM base

ARG BUILD_DATE
ARG BUILD_REF

LABEL org.label-schema.build-date=${BUILD_DATE}
LABEL org.label-schema.name="KDE Appimage Base (arm64)"
LABEL org.label-schema.url="https://amyspark.me/"
LABEL org.label-schema.vcs-ref=${BUILD_REF}
LABEL org.label-schema.vcs-url="e.g. https://github.com/amyspark/appimage-potato"
LABEL org.label-schema.vendor="Amyspark"
LABEL org.label-schema.schema-version="1.0"

# Install cmake

COPY --from=cmake /tmp/cmake /usr/local

# Install patchelf
COPY --from=patchelf /tmp/patchelf /usr/local

# Install linuxdeployqt
COPY --from=linuxdeployqt /tmp/linuxdeployqt/squashfs-root/usr/ /usr/local

# Install appimagetool
COPY --from=appimagetool  /tmp/appimagetool/squashfs-root/usr/ /usr/local

USER appimage
