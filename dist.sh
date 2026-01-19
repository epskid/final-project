#!/usr/bin/env sh
# builds the executable and creates a zip archive with the resources & executable

set -eu

PLATFORM="$1"

case $PLATFORM in
  linux)
    EXE="final"
    zig build --release=fast
    ;;
  windows)
    EXE="final.exe"
    zig build -Dtarget=native-windows-gnu --release=fast
    ;;
  *)
    echo "unknown platform: $PLATFORM" > /dev/stderr
    exit 1
    ;;
esac

cp "zig-out/bin/$EXE" $EXE
zip -r "dist-$PLATFORM.zip" resources $EXE
rm $EXE
