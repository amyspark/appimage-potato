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

### NOTE: from here on, there should be neatly packed artifacts
### - on their folders
### - and on their appimages

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
### Prepare static binutils
###

FROM base as binutils

RUN cd /tmp && \
    wget -c https://ftp.gnu.org/gnu/binutils/binutils-2.36.tar.bz2 && \
    tar xf binutils-2.36.tar.bz2 && \
    cd binutils-2.36/ && \
    ./configure --prefix=/tmp/binutils --disable-nls --enable-static-link --disable-shared-plugins --disable-dynamicplugin --disable-tls --disable-pie && \
    make -j$(nproc) && \
    make clean && \
    make -j$(nproc) LDFLAGS="-all-static" && \
    make -j$(nproc) install

###
### Prepare appimagetool
###

FROM base as appimagebase

RUN apt-get install -y automake desktop-file-utils libcairo2-dev \
    libglib2.0-dev libssl-dev libfuse-dev libtool pkg-config vim zsync

FROM appimagebase as appimagetool

RUN git clone --recursive https://github.com/AppImage/AppImageKit.git /tmp/src

RUN cd /tmp/src && \
    cmake . -DCMAKE_INSTALL_PREFIX=/tmp/appimagetool.AppDir/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBUILD_TESTING=ON && \
    cmake --build . --target install --parallel

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
    /tmp/appimagetool*AppImage --appimage-extract && \
    chmod +rx squashfs-root/usr/lib/appimagekit


###
### Prepare linuxdeploy-plugin-appimage
###

FROM appimagebase as linuxdeploy-plugin-appimage

COPY --from=patchelf /tmp/patchelf/ /usr/local
COPY --from=binutils /tmp/binutils/ /usr/local
COPY --from=appimagetool /tmp/appimagetool/ /tmp/appimagetool/

RUN apt-get install -y \
    gcc-multilib g++-multilib libc6-dev libstdc++-5-dev zlib1g-dev libfuse-dev

COPY linuxdeploy-plugin-appimage.sh /

RUN chmod +x /linuxdeploy-plugin-appimage.sh && \
    cd /tmp && \
    /linuxdeploy-plugin-appimage.sh && \
    mv /tmp/appimagetool/squashfs-root/ /tmp/linuxdeploy-plugin-appimage.AppDir/appimagetool-prefix/ && \
    ln -s ../../appimagetool-prefix/AppRun /tmp/linuxdeploy-plugin-appimage.AppDir/usr/bin/appimagetool && \
    cp /tmp/src/resources/linuxdeploy-plugin-appimage.desktop /tmp/linuxdeploy-plugin-appimage.AppDir/ && \
    cp /tmp/src/resources/linuxdeploy-plugin-appimage.svg /tmp/linuxdeploy-plugin-appimage.AppDir/ && \
    cp /tmp/src/resources/linuxdeploy-plugin-appimage.svg /tmp/linuxdeploy-plugin-appimage.AppDir/.DirIcon && \
    /tmp/linuxdeploy-plugin-appimage.AppDir/usr/bin/appimagetool /tmp/linuxdeploy-plugin-appimage.AppDir/ -v \
    linuxdeploy-plugin-appimage-"$(uname -m)"-"$(env GIT_DIR=/tmp/src/.git git rev-parse --short HEAD)".AppImage && \
    sha256sum /tmp/linuxdeploy-plugin-appimage-*.AppImage && \
    chmod +x /tmp/linuxdeploy-plugin-appimage*AppImage && \
    mkdir linuxdeploy-plugin-appimage && \
    cd linuxdeploy-plugin-appimage && \
    /tmp/linuxdeploy-plugin-appimage*AppImage --appimage-extract

###
### Prepare linuxdeploy
### It depends on linuxdeploy-plugin-appimage
###

FROM appimagebase as linuxdeploy

COPY --from=patchelf /tmp/patchelf/ /usr/local
COPY --from=binutils /tmp/binutils/ /usr/local
COPY --from=linuxdeploy-plugin-appimage /tmp/linuxdeploy-plugin-appimage /tmp/linuxdeploy-plugin-appimage

RUN apt-get install -y \
    libmagic-dev libjpeg-dev libpng-dev cimg-dev \
    gcc-multilib g++-multilib libc6-dev libstdc++-5-dev zlib1g-dev libfuse-dev

RUN git clone --recursive https://github.com/linuxdeploy/linuxdeploy.git /tmp/src

COPY linuxdeploy.sh /

RUN chmod +x /linuxdeploy.sh && \
    cd /tmp && \
    /linuxdeploy.sh && \
    chmod +x linuxdeploy*AppImage && \
    mkdir linuxdeploy && \
    cd linuxdeploy && \
    /tmp/linuxdeploy*AppImage --appimage-extract

###
### Prepare linuxdeploy-plugin-qt
###

FROM appimagebase as linuxdeploy-plugin-qt

COPY --from=patchelf /tmp/patchelf/ /usr/local
COPY --from=binutils /tmp/binutils/ /usr/local
COPY --from=linuxdeploy /tmp/linuxdeploy/squashfs-root/ /tmp/linuxdeploy/

ARG linuxdeployqt_commit=e911a13b1b5de76b7813e0af177d3bda1aedacfc

RUN apt-get install -y \
    libmagic-dev libjpeg-dev libpng-dev cimg-dev mesa-common-dev \
    automake gcc g++ \
    qt5-default qtbase5-dev qttools5-dev-tools \
    libgl1-mesa-dev

COPY linuxdeploy-plugin-qt.sh /

RUN git clone https://github.com/linuxdeploy/linuxdeploy-plugin-qt.git /tmp/src && \
    cd /tmp/src && \
    git checkout $linuxdeployqt_commit && \
    git submodule update --init --recursive

RUN cd /tmp && \
    chmod +x /linuxdeploy-plugin-qt.sh && \
    /linuxdeploy-plugin-qt.sh && \
    /tmp/linuxdeploy/AppRun --appdir /tmp/linuxdeploy-plugin-qt.AppDir \
        -d /tmp/src/resources/linuxdeploy-plugin-qt.desktop \
        -i /tmp/src/resources/linuxdeploy-plugin-qt.svg \
        -e "$(which patchelf)" \
        -e "$(which strip)" \
        --output appimage && \
    sha256sum /tmp/linuxdeploy-plugin-qt-*.AppImage && \
    chmod +x /tmp/linuxdeploy-plugin-qt*AppImage && \
    mkdir linuxdeploy-plugin-qt && \
    cd linuxdeploy-plugin-qt && \
    /tmp/linuxdeploy-plugin-qt*AppImage --appimage-extract && \
    chmod +rx squashfs-root/usr/bin

###
### Prepare AppImageUpdate (ok, this is the real last plugin)
###

FROM appimagebase as appimageupdate

ARG appimageupdate_commit=b6cfe00a13ab51914b5fd3c695d3406033cf1938

COPY --from=patchelf /tmp/patchelf/ /usr/local
COPY --from=binutils /tmp/binutils/ /usr/local
COPY --from=linuxdeploy-plugin-qt /tmp/linuxdeploy-plugin-qt/squashfs-root/ /tmp/linuxdeploy/
COPY --from=linuxdeploy /tmp/linuxdeploy/squashfs-root/ /tmp/linuxdeploy/

RUN apt-get install -y \
    qt5-default qtbase5-dev qttools5-dev-tools \
    libgl1-mesa-dev libdrm-dev mesa-common-dev \
    build-essential cmake libssl-dev autoconf automake libtool \
    wget vim-common desktop-file-utils pkgconf \
    libglib2.0-dev libcairo2-dev librsvg2-dev libfuse-dev git \
    libcurl4-openssl-dev wget

RUN git clone https://github.com/AppImage/AppImageUpdate.git /tmp/src && \
    cd /tmp/src && \
    git checkout $appimageupdate_commit && \
    git submodule update --init --recursive

COPY appimageupdate.sh /

RUN cd /tmp && \
    chmod +x /appimageupdate.sh && \
    /appimageupdate.sh && \
    cd /tmp && \
    chmod +x appimageupdate*AppImage && \
    mkdir appimageupdate && \
    cd appimageupdate && \
    /tmp/appimageupdate*AppImage --appimage-extract

###
### Prepare linuxdeployqt (I made a mistake, this is the one we use at KDE)
###

FROM appimagebase as linuxdeployqt

ARG linuxdeployqt_commit=b4697483c98120007019c3456914cfd1dba58384

COPY --from=patchelf /tmp/patchelf/ /usr/local
COPY --from=binutils /tmp/binutils/ /usr/local
COPY --from=appimagetool /tmp/appimagetool/squashfs-root/usr/ /usr/local

RUN git clone https://github.com/probonopd/linuxdeployqt.git /tmp/src && \
    cd /tmp/src && \
    git checkout $linuxdeployqt_commit && \
    git submodule update --init --recursive

RUN apt-get install -y \
    qt5-default qtbase5-dev qttools5-dev-tools

COPY linuxdeployqt.sh /

RUN cd /tmp && \
    chmod +x /linuxdeployqt.sh && \
    /linuxdeployqt.sh && \
    mkdir /tmp/linuxdeployqt && \
    cd /tmp/linuxdeployqt && \
    /tmp/linuxdeployqt*AppImage --appimage-extract

###
# Merge all tools (into /usr/local, that folder is ignored by Krita scripts)
###

FROM base

ARG BUILD_REF
ARG BUILD_DATE

LABEL org.label-schema.build-date=${BUILD_DATE}
LABEL org.label-schema.name="KDE Appimage Base (x86_64) (AppImageUpdate)"
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

# Install homegrown appimageupdate
# appimageupdate must only have the AppImageUpdate binary
COPY --from=appimageupdate /tmp/appimageupdate /usr/local/bin/

# Summarize AppImage artifacts
COPY --from=appimagetool  /tmp/*.AppImage /tmp/
COPY --from=appimageupdate /tmp/*.AppImage /tmp/
COPY --from=linuxdeploy-plugin-appimage /tmp/*.AppImage /tmp/
COPY --from=linuxdeploy /tmp/*.AppImage /tmp/
COPY --from=linuxdeploy-plugin-qt /tmp/*.AppImage /tmp/
COPY --from=linuxdeployqt /tmp/*.AppImage /tmp/
RUN sha256sum /tmp/*.AppImage

USER appimage
