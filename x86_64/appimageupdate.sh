#!/usr/bin/env bash

set -e
set -x

export REPO_ROOT=/tmp/src

pushd /tmp

export ARCH=${ARCH:-$(uname -m)}

if [ "$ARCH" == "i386" ]; then
    EXTRA_CMAKE_ARGS=("-DCMAKE_TOOLCHAIN_FILE=$REPO_ROOT/cmake/toolchains/i386-linux-gnu.cmake")
fi

cmake "$REPO_ROOT" \
    -DBUILD_QT_UI=ON \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    "${EXTRA_CMAKE_ARGS[@]}"

# now, compile and install to AppDir
make -j$(nproc)
make -j$(nproc) install DESTDIR=AppImageUpdate.AppDir
make -j$(nproc) install DESTDIR=appimageupdatetool.AppDir

# install resources into AppDirs
for appdir in AppImageUpdate.AppDir appimageupdatetool.AppDir; do
    mkdir -p "$appdir"/resources
    cp -v "$REPO_ROOT"/resources/*.xpm "$appdir"/resources/
done

# determine Git commit ID
# appimagetool uses this for naming the file
export VERSION=$(env GIT_DIR="$REPO_ROOT/.git" git rev-parse --short HEAD)

# remove unnecessary binaries from AppDirs
rm AppImageUpdate.AppDir/usr/bin/appimageupdatetool
rm appimageupdatetool.AppDir/usr/bin/AppImageUpdate
rm appimageupdatetool.AppDir/usr/lib/*qt*.so*

# remove other unnecessary data
find {appimageupdatetool,AppImageUpdate}.AppDir -type f -iname '*.a' -delete
rm -rf {appimageupdatetool,AppImageUpdate}.AppDir/usr/include

for app in appimageupdatetool AppImageUpdate; do
    find "$app".AppDir/

    if [ "$app" == "AppImageUpdate" ]; then export EXTRA_FLAGS=("--plugin" "qt"); fi

    # overwrite AppImage filename to get static filenames
    # see https://github.com/AppImage/AppImageUpdate/issues/89
    export OUTPUT="$app"-"$ARCH".AppImage

    # bundle application
    /tmp/linuxdeploy/AppRun --appdir "$app.AppDir" --output appimage "${EXTRA_FLAGS[@]}" -d "$REPO_ROOT"/resources/"$app".desktop -i "$REPO_ROOT"/resources/appimage.png
done

export OUTPUT="$(uname -m)-$(env GIT_DIR=/tmp/src/.git git rev-parse --short HEAD).AppImage"

mv "appimageupdatetool-$ARCH.AppImage" "/tmp/appimageupdatetool-$OUTPUT"
mv "AppImageUpdate-$ARCH.AppImage" "/tmp/AppImageUpdate-$OUTPUT"

popd
