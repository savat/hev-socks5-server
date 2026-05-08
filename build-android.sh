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
echo "Working directory: $(pwd)"
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

# ตรวจสอบว่า source code อยู่ที่ไหน
echo "Looking for source code..."
SOURCE_FOUND=""

# ลองหลายๆ ตำแหน่ง
if [[ -d "$ROOT_DIR/hev-socks5-server" ]]; then
    echo "Found source at: $ROOT_DIR/hev-socks5-server"
    ln -sf "$ROOT_DIR/hev-socks5-server" jni/hev-socks5-server
    SOURCE_FOUND="yes"
elif [[ -d "$ROOT_DIR/src" ]]; then
    echo "Found source at: $ROOT_DIR/src"
    ln -sf "$ROOT_DIR/src" jni/hev-socks5-server
    SOURCE_FOUND="yes"
elif [[ -d "$ROOT_DIR/source" ]]; then
    echo "Found source at: $ROOT_DIR/source"
    ln -sf "$ROOT_DIR/source" jni/hev-socks5-server
    SOURCE_FOUND="yes"
elif [[ -d "$ROOT_DIR/jni/hev-socks5-server" ]]; then
    echo "Found source at: $ROOT_DIR/jni/hev-socks5-server"
    ln -sf "$ROOT_DIR/jni/hev-socks5-server" jni/hev-socks5-server
    SOURCE_FOUND="yes"
elif [[ -f "$ROOT_DIR/Android.mk" ]]; then
    echo "Found Android.mk at root, copying to jni/"
    cp "$ROOT_DIR/Android.mk" jni/
    # สร้าง symbolic link สำหรับทุกโฟลเดอร์ใน root (ยกเว้น jni)
    for dir in "$ROOT_DIR"/*/ ; do
        dirname=$(basename "$dir")
        if [[ "$dirname" != "jni" && "$dirname" != "libs" && "$dirname" != "obj" ]]; then
            if [[ -d "$dir" ]]; then
                ln -sf "$dir" "jni/$dirname"
            fi
        fi
    done
    SOURCE_FOUND="yes"
else
    echo "ERROR: Cannot find source code"
    echo "Current directory structure:"
    ls -la "$ROOT_DIR"
    echo ""
    echo "Looking for .c and .cpp files:"
    find "$ROOT_DIR" -name "*.c" -o -name "*.cpp" -o -name "*.mk" | head -20
    exit 1
fi

if [[ -z "$SOURCE_FOUND" ]]; then
    echo "ERROR: No source code found"
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
    -j$(nproc)

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
  echo ""
  echo "Checking what was built:"
  find "$ROOT_DIR/libs" -name "*.so" 2>/dev/null || echo "No .so files found in libs/"
  find "$ROOT_DIR/obj" -name "*.so" 2>/dev/null || echo "No .so files found in obj/"
  echo "========================================="
  exit 1
fi

echo "Build finished!"
