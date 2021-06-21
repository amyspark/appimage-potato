#!/usr/bin/env bash
set -e
set -x

pushd /tmp

REPO_ROOT=/tmp/src

if [ "$ARCH" == "i386" ]; then
    EXTRA_CMAKE_ARGS=("-DCMAKE_TOOLCHAIN_FILE=$REPO_ROOT/cmake/toolchains/i386-linux-gnu.cmake" "-DUSE_SYSTEM_CIMG=OFF")
else
    EXTRA_CMAKE_ARGS=()
fi

cmake "$REPO_ROOT" -DCMAKE_INSTALL_PREFIX=/tmp/linuxdeploy -DUSE_CCACHE=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo "${EXTRA_CMAKE_ARGS[@]}"

cmake --build . --target linuxdeploy --parallel

patchelf_path="$(realpath $(which patchelf))"
strip_path="$(realpath $(which strip))"

# args are used more than once
LINUXDEPLOY_ARGS=("--appdir" "/tmp/linuxdeploy.AppDir" "-e" "bin/linuxdeploy" "-i" "$REPO_ROOT/resources/linuxdeploy.png" "-d" "$REPO_ROOT/resources/linuxdeploy.desktop" "-e" "$patchelf_path" "-e" "$strip_path")

# deploy patchelf which is a dependency of linuxdeploy
bin/linuxdeploy "${LINUXDEPLOY_ARGS[@]}"

# bundle AppImage plugin
mkdir -p /tmp/linuxdeploy.AppDir/plugins

mv /tmp/linuxdeploy-plugin-appimage/squashfs-root/ /tmp/linuxdeploy.AppDir/plugins/linuxdeploy-plugin-appimage

ln -s ../../plugins/linuxdeploy-plugin-appimage/usr/bin/linuxdeploy-plugin-appimage /tmp/linuxdeploy.AppDir/usr/bin/linuxdeploy-plugin-appimage

# build AppImage using plugin
/tmp/linuxdeploy.AppDir/usr/bin/linuxdeploy-plugin-appimage --appdir /tmp/linuxdeploy.AppDir/

export OUTPUT="linuxdeploy-$(uname -m)-$(env GIT_DIR=/tmp/src/.git git rev-parse --short HEAD).AppImage"

# skip this step, fuse is not available in docker
# # rename AppImage to avoid "Text file busy" issues when using it to create another one
# mv "linuxdeploy-$(uname -m).AppImage" test.AppImage

# # verify that the resulting AppImage works
# ./test.AppImage "${LINUXDEPLOY_ARGS[@]}"

# # check whether AppImage plugin is found and works
# ./test.AppImage "${LINUXDEPLOY_ARGS[@]}" --output appimage

mv "linuxdeploy-$(uname -m).AppImage" /tmp/$OUTPUT

popd
