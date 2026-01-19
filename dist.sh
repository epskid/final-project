#!/usr/bin/env sh
# builds the executable and creates a zip archive with the resources & executable

set -eux

RELEASE="$1"
PLATFORM="$2"

case $PLATFORM in
  linux)
    EXE="final"
    zig build --release="$RELEASE"
    ;;
  windows)
    EXE="final.exe"
    zig build -Dtarget=native-windows-gnu --release="$RELEASE"
    ;;
  *)
    echo "unknown platform: $PLATFORM" > /dev/stderr
    exit 1
    ;;
esac

cp "zig-out/bin/$EXE" $EXE
zip -r "dist-$PLATFORM-$RELEASE.zip" resources $EXE
rm $EXE
