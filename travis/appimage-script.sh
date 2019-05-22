#! /bin/bash

# Copyright (C) 2019 Syncplay
# Licensed under the MIT license - http://opensource.org/licenses/MIT

set -x
set -e

# use RAM disk if possible
if [ "$CI" == "" ] && [ -d /dev/shm ]; then
    TEMP_BASE=/dev/shm
else
    TEMP_BASE=/tmp
fi

BUILD_DIR=$(mktemp -d -p "$TEMP_BASE" appimagelint-build-XXXXXX)

cleanup () {
    if [ -d "$BUILD_DIR" ]; then
        rm -rf "$BUILD_DIR"
    fi
}

trap cleanup EXIT

# store repo root as variable
REPO_ROOT=$(readlink -f $(dirname $(dirname "$0")))
#REPO_ROOT="."
OLD_CWD=$(readlink -f .)

pushd "$BUILD_DIR"

wget https://github.com/TheAssassin/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
wget https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-conda/master/linuxdeploy-plugin-conda.sh

chmod +x linuxdeploy*.AppImage
chmod +x linuxdeploy*.sh

# set up custom AppRun script
cat > AppRun.sh <<\EAT
#! /bin/sh
# make sure to set APPDIR when run directly from the AppDir
if [ -z $APPDIR ]; then APPDIR=$(readlink -f $(dirname "$0")); fi
export LD_LIBRARY_PATH="$APPDIR"/usr/lib
export PATH="$PATH":"$APPDIR"/usr/bin

exec "$APPDIR"/usr/bin/python "$APPDIR"/usr/bin/syncplay "$@"
EAT
chmod +x AppRun.sh

# add AppStream metadata
mkdir -p AppDir/usr/share/metainfo/
cat > pl.syncplay.syncplay.appdata.xml <<\EAT
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
	<id>pl.syncplay.syncplay</id>
	<metadata_license>MIT</metadata_license>
	<project_license>Apache-2.0</project_license>
	<name>Syncplay</name>
	<summary>Client/server to synchronize media playback on mpv/VLC/MPC-HC/MPC-BE on many computers</summary>
	<description>
		<p>Syncplay synchronises the position and play state of multiple media players so that the viewers can watch the same thing at the same time. This means that when one person pauses/unpauses playback or seeks (jumps position) within their media player then this will be replicated across all media players connected to the same server and in the same 'room' (viewing session). When a new person joins they will also be synchronised. Syncplay also includes text-based chat so you can discuss a video as you watch it (or you could use third-party Voice over IP software to talk over a video).</p>
	</description>
	<launchable type="desktop-id">pl.syncplay.syncplay.desktop</launchable>
	<url type="homepage">https://syncplay.pl/</url>
	<screenshots>
		<screenshot type="default">
			<image>https://syncplay.pl/wp-content/themes/big-city-child/SyncplayExplained.png</image>
		</screenshot>
	</screenshots>
	<provides>
		<id>pl.syncplay.syncplay.desktop</id>
	</provides>
</component>
EAT
mv pl.syncplay.syncplay.appdata.xml AppDir/usr/share/metainfo/

# move and rename .desktop file
cp "$REPO_ROOT"/syncplay/resources/syncplay.desktop ./pl.syncplay.syncplay.desktop

#export CONDA_PACKAGES="Pillow"
export PIP_REQUIREMENTS="."
export PIP_WORKDIR="$REPO_ROOT"
export VERSION="$(cat $REPO_ROOT/syncplay/__init__.py | awk '/version/ {gsub("\047", "", $3); print $NF}')"
export OUTPUT=Syncplay-$VERSION-x86_64.AppImage

./linuxdeploy-x86_64.AppImage --appdir AppDir --plugin conda \
    -e $(which readelf) \
    -i "$REPO_ROOT"/syncplay/resources/syncplay.png -d pl.syncplay.syncplay.desktop \
    --output appimage --custom-apprun AppRun.sh

mv Syncplay*.AppImage "$OLD_CWD"