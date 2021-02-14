FROM ubuntu:16.04

LABEL Description="KDE Appimage Base (cross) (armhf)" Author="Amy <amy@amyspark.me>"

# Start off as root
USER root

# Setup the various repositories we are going to need for our dependencies
# Some software demands a newer GCC because they're using C++14 stuff, which is just insane
RUN apt-get update && apt-get install -y apt-transport-https ca-certificates gnupg software-properties-common wget
RUN wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | apt-key add -
# Add ARMHF (or aarch64) architecture, fix relevant APT entries
RUN dpkg --add-architecture armhf && perl -pe "s/deb http:\/\/(?:archive|security)\.ubuntu\.com\/ubuntu/deb [arch=armhf] http:\/\/ports.ubuntu.com/g" /etc/apt/sources.list > /etc/apt/sources.list.d/arm.list && perl -pi.bak -e "s/deb (http:\/\/)/deb [arch=amd64] \$1/g" /etc/apt/sources.list
RUN add-apt-repository -y ppa:openjdk-r/ppa && apt-add-repository 'deb [arch=amd64] https://apt.kitware.com/ubuntu/ xenial main'

# Update the system and bring in our core operating requirements
# NO apt-get upgrade -y &&
RUN apt-get update && apt-get install -y openssh-server openjdk-8-jre-headless kitware-archive-keyring

# Some software demands a newer GCC because they're using C++14 stuff, which is just insane
# We do this after the general system update to ensure it doesn't bring in any unnecessary updates
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test && apt-get update

ENV ARCH=armhf

# Now install the general dependencies we need for builds
RUN apt-get install -y \
    # General requirements for building KDE software
    build-essential cmake git-core locales \
    # General requirements for building other software
    automake gcc-6 g++-6 libxml-parser-perl libpq-dev:${ARCH} libaio-dev:${ARCH} \
    # Needed for some frameworks
    bison gettext \
    # Qt and KDE Build Dependencies
    gperf libasound2-dev:${ARCH} libatkmm-1.6-dev:${ARCH} libbz2-dev:${ARCH} libcairo-perl:${ARCH} libcap-dev:${ARCH} libcups2-dev:${ARCH} libdbus-1-dev:${ARCH}\
    libdrm-dev:${ARCH} libegl1-mesa-dev:${ARCH} libfontconfig1-dev:${ARCH} libfreetype6-dev:${ARCH} libgcrypt11-dev:${ARCH} libgl1-mesa-dev:${ARCH} \
    libglib-perl libgsl0-dev:${ARCH} libgsl0-dev:${ARCH} gstreamer1.0-alsa:${ARCH} libgstreamer1.0-dev:${ARCH} libgstreamer-plugins-base1.0-dev:${ARCH} \
    libgtk2-perl libjpeg-dev:${ARCH} libnss3-dev:${ARCH} libpci-dev:${ARCH} libpng12-dev:${ARCH} libpulse-dev:${ARCH} libssl-dev:${ARCH} \
    libgstreamer-plugins-good1.0-dev:${ARCH} libgstreamer-plugins-bad1.0-dev:${ARCH} gstreamer1.0-plugins-base:${ARCH}\
    gstreamer1.0-plugins-good:${ARCH} gstreamer1.0-plugins-ugly:${ARCH} libtiff5-dev libudev-dev:${ARCH} libwebp-dev:${ARCH} flex libmysqlclient-dev:${ARCH} \
    # Mesa libraries for everything to use
    libx11-dev:${ARCH} libxkbcommon-x11-dev:${ARCH} libxcb-glx0-dev:${ARCH} libxcb-keysyms1-dev:${ARCH} libxcb-util0-dev:${ARCH} libxcb-res0-dev:${ARCH} libxcb1-dev:${ARCH} libxcomposite-dev:${ARCH} libxcursor-dev:${ARCH} \
    libxdamage-dev:${ARCH} libxext-dev:${ARCH} libxfixes-dev:${ARCH} libxi-dev:${ARCH} libxrandr-dev:${ARCH} libxrender-dev:${ARCH} libxss-dev:${ARCH} libxtst-dev:${ARCH} mesa-common-dev:${ARCH} \
    # Krita AppImage (Python) extra dependencies
    libffi-dev:${ARCH} \
    # Kdenlive AppImage extra dependencies
    liblist-moreutils-perl libtool libpixman-1-dev:${ARCH} subversion

# Setup a user account for everything else to be done under
RUN useradd -d /home/appimage/ -u 1000 --user-group --create-home -G video appimage
# Make sure SSHD will be able to startup
# RUN mkdir /var/run/sshd/
# Get locales in order
RUN locale-gen en_US en_US.UTF-8 en_NZ.UTF-8

# Switch over to our new user and add in the utilities needed for appimage builds
USER appimage
COPY setup-utilities /home/appimage/
RUN /home/appimage/setup-utilities

# Now we go back to being root for the final phase
USER root

# # We want to run SSHD so that Jenkins can remotely connect to this container
# EXPOSE 22
# CMD ["/usr/sbin/sshd", "-D"]

# CXC: install a reasonable enough Python
# RUN add-apt-repository ppa:deadsnakes/ppa && apt-get update && apt-get install python3.9 && update-alternatives --install /usr/bin/python python /usr/bin/python3.9 0

# RUN wget https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--glibc--stable-2020.08-1.tar.bz2 && wget https://toolchains.bootlin.com/downloads/releases/toolchains/armv7-eabihf/tarballs/armv7-eabihf--glibc--stable-2020.08-1.sha256 && sha256sum -c armv7-eabihf--glibc--stable-2020.08-1.sha256
# RUN tar xf armv7-eabihf--glibc--stable-2020.08-1.tar.bz2 -C /opt && /opt/armv7-eabihf--glibc--stable-2020.08-1/relocate-sdk.sh
# RUN 

# Python cross-compile
RUN add-apt-repository ppa:deadsnakes/ppa && apt-get update && apt-get install -y python3.8
