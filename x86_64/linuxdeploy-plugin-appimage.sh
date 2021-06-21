#!/usr/bin/env bash
set -e
set -x

pushd /tmp

REPO_ROOT=/tmp/src

git clone --recursive https://github.com/linuxdeploy/linuxdeploy-plugin-appimage $REPO_ROOT

cd $REPO_ROOT

if [ "$ARCH" == "i386" ]; then
    EXTRA_CMAKE_ARGS=("-DCMAKE_TOOLCHAIN_FILE=$REPO_ROOT/cmake/toolchains/i386-linux-gnu.cmake")
else
    EXTRA_CMAKE_ARGS=()
fi

cmake . -DCMAKE_INSTALL_PREFIX=/tmp/linuxdeploy-plugin-appimage.AppDir/usr -DCMAKE_BUILD_TYPE=RelWithDebInfo "${EXTRA_CMAKE_ARGS[@]}"

cmake --build . --target install --parallel $(nproc)

popd
