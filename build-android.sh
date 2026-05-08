#!/usr/bin/env bash
set -e
set -o pipefail

if [[ ! -d "$NDK_HOME" ]]; then
  echo "NDK_HOME not found"
  exit 1
fi

ROOT_DIR=$(pwd)
TMPDIR=$(mktemp -d)

cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/jni"

pushd "$TMPDIR"

echo 'include $(call all-subdir-makefiles)' > jni/Android.mk

ln -sf "$ROOT_DIR/hev-socks5-server" jni/hev-socks5-server

"$NDK_HOME/ndk-build" \
    NDK_PROJECT_PATH=. \
    APP_BUILD_SCRIPT=jni/Android.mk \
    APP_PLATFORM=android-24 \
    APP_ABI="armeabi-v7a arm64-v8a x86 x86_64" \
    NDK_LIBS_OUT="$ROOT_DIR/libs" \
    NDK_OUT="$TMPDIR/obj" \
    APP_CFLAGS="-O3" \
    APP_LDFLAGS="-Wl,--build-id=none"

popd

echo "Build finished!"
