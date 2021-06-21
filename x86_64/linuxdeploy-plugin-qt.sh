#!/usr/bin/env bash
set -e
set -x

REPO_ROOT=/tmp/src

pushd $REPO_ROOT

# tar czf ../test-$(env GIT_DIR=/tmp/src/.git git rev-parse --short HEAD).tar.gz --exclude-ignore-recursive=.gitignore --exclude=.git --sort=name --owner=0 --group=0 --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime .

if [ "$ARCH" == "i386" ]; then
    EXTRA_CMAKE_ARGS=("-DCMAKE_TOOLCHAIN_FILE=$REPO_ROOT/cmake/toolchains/i386-linux-gnu.cmake" "-DUSE_SYSTEM_CIMG=OFF")
else
    EXTRA_CMAKE_ARGS=()
fi

cmake . -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo "${EXTRA_CMAKE_ARGS[@]}"

DESTDIR=/tmp/linuxdeploy-plugin-qt.AppDir cmake --build . --target install --parallel

popd
