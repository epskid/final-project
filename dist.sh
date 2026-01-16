#!/usr/bin/env sh
# builds the executable and creates a zip archive with the resources & executable

set -eux

PLATFORM="$1"
EXE=""

case $PLATFORM in
  linux)
    zig build --release=fast
    EXE="final"
    ;;
  windows)
    zig build -Dtarget=native-windows-gnu --release=fast
    EXE="final.exe"
    ;;
  *)
    echo "unknown platform: $PLATFORM" > /dev/stderr
    exit 1
    ;;
esac

cp "zig-out/bin/$EXE" $EXE
zip -r "dist-$PLATFORM.zip" resources $EXE
rm $EXE
