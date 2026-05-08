#!/usr/bin/env bash
set -e
set -o pipefail

if [[ ! -d "$NDK_HOME" ]]; then
  echo "ERROR: NDK_HOME not found at: $NDK_HOME"
  echo "Please set NDK_HOME environment variable"
  exit 1
fi

# รับค่า APP_ABI จาก environment variable
if [[ -z "$APP_ABI" ]]; then
  echo "WARNING: APP_ABI not set, using default: arm64-v8a"
  APP_ABI="arm64-v8a"
fi

echo "========================================="
echo "Building for ABI: $APP_ABI"
echo "NDK_HOME: $NDK_HOME"
echo "========================================="

ROOT_DIR=$(pwd)
TMPDIR=$(mktemp -d)

cleanup() {
  echo "Cleaning up temporary directory..."
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

mkdir -p "$TMPDIR/jni"

pushd "$TMPDIR" > /dev/null

# สร้าง Android.mk
echo 'include $(call all-subdir-makefiles)' > jni/Android.mk

# สร้าง symbolic link ไปยัง source code
ln -sf "$ROOT_DIR/hev-socks5-server" jni/hev-socks5-server

# ตรวจสอบว่า source code มีอยู่
if [[ ! -d "jni/hev-socks5-server" ]]; then
  echo "ERROR: Source code not found at jni/hev-socks5-server"
  exit 1
fi

echo "Starting NDK build for ABI: $APP_ABI"

# Build เฉพาะ ABI ที่กำหนด
"$NDK_HOME/ndk-build" \
    NDK_PROJECT_PATH=. \
    APP_BUILD_SCRIPT=jni/Android.mk \
    APP_PLATFORM=android-24 \
    APP_ABI="$APP_ABI" \
    NDK_LIBS_OUT="$ROOT_DIR/libs" \
    NDK_OUT="$TMPDIR/obj" \
    APP_CFLAGS="-O3" \
    APP_LDFLAGS="-Wl,--build-id=none" \
    -j$(nproc)  # ใช้ CPU แบบเต็มประสิทธิภาพ

popd > /dev/null

# ตรวจสอบว่าไฟล์ถูกสร้างหรือไม่
if [[ -f "libs/$APP_ABI/libhev-socks5-server.so" ]]; then
  echo "========================================="
  echo "✅ Build successful for ABI: $APP_ABI"
  echo "Output: libs/$APP_ABI/libhev-socks5-server.so"
  ls -la "libs/$APP_ABI/libhev-socks5-server.so"
  echo "========================================="
else
  echo "========================================="
  echo "❌ Build failed for ABI: $APP_ABI"
  echo "Expected output not found at: libs/$APP_ABI/libhev-socks5-server.so"
  echo "========================================="
  exit 1
fi

echo "Build finished!"
