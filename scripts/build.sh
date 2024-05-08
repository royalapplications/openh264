#!/usr/bin/env bash

set -e

OPENH264_VERSION_STABLE="2.4.1" # https://github.com/cisco/openh264/releases
IOS_VERSION_MIN="13.4"
MACOS_VERSION_MIN="11.0"
CODESIGN_ID="-"

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo "Script Path: ${SCRIPT_PATH}"

BUILD_ROOT_DIR="${SCRIPT_PATH}/../build"
echo "Build Path: ${BUILD_ROOT_DIR}"
mkdir -p "${BUILD_ROOT_DIR}"

if [[ -z $OPENH264_VERSION ]]; then
  echo "OPENH264_VERSION not set; falling back to ${OPENH264_VERSION_STABLE} (Stable)"
  OPENH264_VERSION="${OPENH264_VERSION_STABLE}"
fi

if [[ ! -f "${BUILD_ROOT_DIR}/v${OPENH264_VERSION}.tar.gz" ]]; then
  echo "Downloading v${OPENH264_VERSION}.tar.gz"
  curl -fL "https://github.com/cisco/openh264/archive/refs/tags/v${OPENH264_VERSION}.tar.gz" -o "${BUILD_ROOT_DIR}/v${OPENH264_VERSION}.tar.gz"
fi

BUILD_DIR="${BUILD_ROOT_DIR}/v${OPENH264_VERSION}"

if [[ ! -d "${BUILD_DIR}" ]]; then
  mkdir -p "${BUILD_DIR}"
  tar xzf "${BUILD_ROOT_DIR}/v${OPENH264_VERSION}.tar.gz" -C "${BUILD_DIR}" --strip-components=1
fi

TARGET_DIR="${BUILD_ROOT_DIR}/v${OPENH264_VERSION}_build"

if [[ -d "${TARGET_DIR}" ]]; then
  rm -rf "${TARGET_DIR}"
fi

mkdir "${TARGET_DIR}"

build() {
  local os="$1"
  local arch="$2"
  local build_target_dir="$3"

  if [[ -d "${build_target_dir}" ]]; then
    rm -rf "${build_target_dir}"
  fi

  mkdir "${build_target_dir}"

  echo "Cleaning"
  make clean -C "${BUILD_DIR}"

  echo "Making Openh264 for ${os} ${arch}"
  make CFLAGS="-arch ${arch}" LDFLAGS="-arch ${arch}" -C "${BUILD_DIR}" OS="${os}" ARCH="${arch}"

  make DESTDIR="${build_target_dir}" PREFIX="" install -C "${BUILD_DIR}"
}

TARGET_DIR_MACOS_ARM64="${TARGET_DIR}/macos-arm64"
TARGET_DIR_MACOS_X86="${TARGET_DIR}/macos-x86_64"

build "darwin" "arm64" "${TARGET_DIR_MACOS_ARM64}"
build "darwin" "x86_64" "${TARGET_DIR_MACOS_X86}"



# THREAD_COUNT=$(sysctl hw.ncpu | awk '{print $2}')

# build_sim_libs()
# {
#   local ARCH=$1
#   if [[ ! -d "${BUILD_DIR}/build/iphonesimulator-${ARCH}" ]]; then
#     pushd "${BUILD_DIR}"
#     ./Configure --openssldir="${BUILD_DIR}/build/ssl" no-asm no-shared no-apps no-docs no-module no-dso no-hw no-engine iossimulator-xcrun CFLAGS="-arch $ARCH -mios-simulator-version-min=${IOS_VERSION_MIN}"
#     make clean
#     make -j$THREAD_COUNT
#     mkdir "${BUILD_DIR}/build/iphonesimulator-${ARCH}"
#     cp libssl.a "${BUILD_DIR}/build/iphonesimulator-${ARCH}/"
#     cp libcrypto.a "${BUILD_DIR}/build/iphonesimulator-${ARCH}/"
#     make clean
# 	popd
#   fi
# }

# HOST_ARC="$( uname -m )"
# if [ "$HOST_ARC" = "arm64" ]; then
#   FOREIGN_ARC="x86_64"
# else
#   FOREIGN_ARC="arm64"
# fi
# NATIVE_BUILD_FLAGS="-mmacosx-version-min=${MACOS_VERSION_MIN}"

# if [[ ! -d "${BUILD_DIR}/build/lib" ]]; then
#   pushd "${BUILD_DIR}"
#   ./Configure --prefix="${BUILD_DIR}/build" --openssldir="${BUILD_DIR}/build/ssl" no-shared no-apps no-docs no-module darwin64-$HOST_ARC-cc CFLAGS="${NATIVE_BUILD_FLAGS}"
#   make clean
#   make -j$THREAD_COUNT
#   make -j$THREAD_COUNT install_sw # skip man pages, see https://github.com/openssl/openssl/issues/8170#issuecomment-461122307
#   make clean
#   popd
# fi

# if [[ ! -d "${BUILD_DIR}/build/macosx" ]]; then
#   pushd "${BUILD_DIR}"
#   ./Configure --openssldir="${BUILD_DIR}/build/ssl" no-shared no-apps no-docs no-module darwin64-$FOREIGN_ARC-cc CFLAGS="-arch ${FOREIGN_ARC} ${NATIVE_BUILD_FLAGS}"
#   make clean
#   make -j$THREAD_COUNT
#   mkdir "${BUILD_DIR}/build/macosx"
#   mkdir "${BUILD_DIR}/build/macosx/include" 
#   mkdir "${BUILD_DIR}/build/macosx/lib"
#   cp -r "${BUILD_DIR}/build/include/openssl" "${BUILD_DIR}/build/macosx/include/OpenSSL"
#   lipo -create "${BUILD_DIR}/build/lib/libssl.a"    libssl.a    -output "${BUILD_DIR}/build/macosx/lib/libssl.a"
#   lipo -create "${BUILD_DIR}/build/lib/libcrypto.a" libcrypto.a -output "${BUILD_DIR}/build/macosx/lib/libcrypto.a"
#   xcrun libtool -static -o "${BUILD_DIR}/build/macosx/lib/libOpenSSL.a" "${BUILD_DIR}/build/macosx/lib/libcrypto.a" "${BUILD_DIR}/build/macosx/lib/libssl.a"
#   make clean
#   popd
# fi

# if [[ ! -d "${BUILD_DIR}/build/iphonesimulator" ]]; then
#   build_sim_libs arm64
#   build_sim_libs x86_64
#   mkdir "${BUILD_DIR}/build/iphonesimulator"
#   mkdir "${BUILD_DIR}/build/iphonesimulator/include" 
#   mkdir "${BUILD_DIR}/build/iphonesimulator/lib"
#   cp -r "${BUILD_DIR}/build/include/openssl" "${BUILD_DIR}/build/iphonesimulator/include/OpenSSL"
#   lipo -create "${BUILD_DIR}/build/iphonesimulator-x86_64/libssl.a"    "${BUILD_DIR}/build/iphonesimulator-arm64/libssl.a"    -output "${BUILD_DIR}/build/iphonesimulator/lib/libssl.a"
#   lipo -create "${BUILD_DIR}/build/iphonesimulator-x86_64/libcrypto.a" "${BUILD_DIR}/build/iphonesimulator-arm64/libcrypto.a" -output "${BUILD_DIR}/build/iphonesimulator/lib/libcrypto.a"
#   xcrun libtool -static -o "${BUILD_DIR}/build/iphonesimulator/lib/libOpenSSL.a" "${BUILD_DIR}/build/iphonesimulator/lib/libcrypto.a" "${BUILD_DIR}/build/iphonesimulator/lib/libssl.a"
#   rm -rf "${BUILD_DIR}/build/iphonesimulator-arm64"
#   rm -rf "${BUILD_DIR}/build/iphonesimulator-x86_64"
# fi

# if [[ ! -d "${BUILD_DIR}/build/iphoneos" ]]; then
#   pushd "${BUILD_DIR}"
#   ./Configure --openssldir="${BUILD_DIR}/build/ssl" no-asm no-shared no-apps no-docs no-module no-dso no-hw no-engine ios64-xcrun -mios-version-min=${IOS_VERSION_MIN}
#   make clean
#   make -j$THREAD_COUNT
#   mkdir "${BUILD_DIR}/build/iphoneos" 
#   mkdir "${BUILD_DIR}/build/iphoneos/include" 
#   mkdir "${BUILD_DIR}/build/iphoneos/lib"
#   cp -r "${BUILD_DIR}/build/include/openssl" "${BUILD_DIR}/build/iphoneos/include/OpenSSL"
#   cp libssl.a "${BUILD_DIR}/build/iphoneos/lib/"
#   cp libcrypto.a "${BUILD_DIR}/build/iphoneos/lib/"
#   xcrun libtool -static -o "${BUILD_DIR}/build/iphoneos/lib/libOpenSSL.a" "${BUILD_DIR}/build/iphoneos/lib/libcrypto.a" "${BUILD_DIR}/build/iphoneos/lib/libssl.a"
#   make clean
#   popd
# fi

# if [[ ! -d "${BUILD_DIR}/build/OpenSSL.xcframework" ]]; then
#   xcodebuild -create-xcframework \
#     -library "${BUILD_DIR}/build/macosx/lib/libOpenSSL.a" \
#     -library "${BUILD_DIR}/build/iphonesimulator/lib/libOpenSSL.a" \
#     -library "${BUILD_DIR}/build/iphoneos/lib/libOpenSSL.a" \
#     -output "${BUILD_DIR}/build/OpenSSL.xcframework"

#   codesign \
#     --force --deep --strict \
#     --sign "${CODESIGN_ID}" \
#     "${BUILD_DIR}/build/OpenSSL.xcframework"
# fi