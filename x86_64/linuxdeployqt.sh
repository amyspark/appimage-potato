#!/usr/bin/env bash

set -e
set -x

REPO_ROOT=/tmp/src

pushd "$REPO_ROOT"

qmake CONFIG+=release CONFIG+=force_debug_info linuxdeployqt.pro
make -j$(nproc)
mkdir -p linuxdeployqt.AppDir/usr/{bin,lib}
for f in patchelf desktop-file-validate appimagetool zsyncmake; do
    cp $(which $f) linuxdeployqt.AppDir/usr/bin/
done
cp ./bin/linuxdeployqt linuxdeployqt.AppDir/usr/bin/
cp -r /usr/local/lib/appimagekit linuxdeployqt.AppDir/usr/lib/
chmod +x linuxdeployqt.AppDir/AppRun
export VERSION="$(git rev-parse --short HEAD)"
./bin/linuxdeployqt linuxdeployqt.AppDir/linuxdeployqt.desktop -verbose=3 \
    -appimage \
    -executable=linuxdeployqt.AppDir/usr/bin/desktop-file-validate
chmod +x linuxdeployqt-*AppImage
mv linuxdeployqt*.AppImage /tmp/

popd
