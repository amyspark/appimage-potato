FROM ubuntu:16.04 as base

# Start off as root
USER root

# Setup the various repositories we are going to need for our dependencies
# Some software demands a newer GCC because they're using C++14 stuff, which is just insane
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates gnupg software-properties-common wget
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add -
RUN add-apt-repository -y ppa:openjdk-r/ppa && apt-add-repository 'deb https://apt.kitware.com/ubuntu/ xenial main'

# Update the system and bring in our core operating requirements
RUN apt-get update && apt-get upgrade -y && apt-get install -y openssh-server openjdk-8-jre-headless

# Some software demands a newer GCC because they're using C++14 stuff, which is just insane
# We do this after the general system update to ensure it doesn't bring in any unnecessary updates
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test && apt-get update

# Krita's dependencies (libheif's avif plugins) need Rust 
RUN add-apt-repository -y ppa:ubuntu-mozilla-security/rust-updates && apt-get update && apt-get install -y cargo rustc

# Now install the general dependencies we need for builds
RUN apt-get install -y \
  # General requirements for building KDE software
  build-essential cmake git-core locales \
  # General requirements for building other software
  automake gcc-6 g++-6 libxml-parser-perl libpq-dev libaio-dev \
  # Needed for some frameworks
  bison gettext \
  # Qt and KDE Build Dependencies
  gperf libasound2-dev libatkmm-1.6-dev libbz2-dev libcairo-perl libcap-dev libcups2-dev libdbus-1-dev \
  libdrm-dev libegl1-mesa-dev libfontconfig1-dev libfreetype6-dev libgcrypt11-dev libgl1-mesa-dev \
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
# Krita's dependencies (libheif's avif plugins) need meson and ninja, both aren't available in binary form for 16.04
# The deadsnakes PPA packs setuptools and pip inside python3.9-venv, let's deploy it manually
RUN add-apt-repository -y ppa:deadsnakes/ppa && apt-get update && apt-get install -y python3.9 python3.9-dev python3.9-venv && python3.9 -m ensurepip 
RUN python3.9 -m pip install meson ninja

# Setup a user account for everything else to be done under
RUN useradd -d /home/appimage/ -u 1000 --user-group --create-home -G video appimage
# Make sure SSHD will be able to startup
RUN mkdir /var/run/sshd/
# Get locales in order
RUN locale-gen en_US en_US.UTF-8 en_NZ.UTF-8

###
### Prepare appimagetool
###

FROM base as appimagetool

# Install appimagetool
RUN cd /tmp && \
  wget -c "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" && \
  chmod +x appimagetool*AppImage && \
  mkdir appimagetool && \
  cd appimagetool && \
  /tmp/appimagetool*AppImage --appimage-extract && \
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

# Install appimagetool
RUN cd /tmp && \
  wget -c "https://github.com/probonopd/linuxdeployqt/releases/download/continuous/linuxdeployqt-continuous-x86_64.AppImage" && \
  chmod +x linuxdeployqt*AppImage && \
  mkdir linuxdeployqt && \
  cd linuxdeployqt && \
  /tmp/linuxdeployqt*AppImage --appimage-extract

###
# Merge all tools (into /usr/local, that folder is ignored by Krita scripts)
###

FROM base

ARG BUILD_REF
ARG BUILD_DATE

LABEL org.label-schema.build-date=${BUILD_DATE}
LABEL org.label-schema.name="KDE Appimage Base (x86_64)"
LABEL org.label-schema.url="https://amyspark.me/"
LABEL org.label-schema.vcs-ref=${BUILD_REF}
LABEL org.label-schema.vcs-url="e.g. https://github.com/amyspark/appimage-potato"
LABEL org.label-schema.vendor="Amyspark"
LABEL org.label-schema.schema-version="1.0"

# Install patchelf
COPY --from=patchelf /tmp/patchelf /usr/local

# Install linuxdeployqt
COPY --from=linuxdeployqt /tmp/linuxdeployqt/squashfs-root/usr/ /usr/local

# Install appimagetool
COPY --from=appimagetool  /tmp/appimagetool/squashfs-root/usr/ /usr/local

# Amyspark: add alternatives
# TODO: GCC 9 requires Binutils 2.26 and Ubuntu doesn't provide it
# TODO: GCC 7 breaks OCIO because of auto_ptr deprecation
# RUN apt-get install -y gcc-7 g++-7 && \
#   update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-5 10 && \
#   update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-6 20 && \
#   update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 30 && \
#   update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-5 10 && \
#   update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-6 20 && \
#   update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 30

USER appimage
