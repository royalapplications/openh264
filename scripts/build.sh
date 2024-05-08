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
  echo "Unpacking v${OPENH264_VERSION}.tar.gz to ${BUILD_DIR}"

  mkdir -p "${BUILD_DIR}"
  tar xzf "${BUILD_ROOT_DIR}/v${OPENH264_VERSION}.tar.gz" -C "${BUILD_DIR}" --strip-components=1
fi

TARGET_DIR="${BUILD_ROOT_DIR}/openh264-${OPENH264_VERSION}"

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

  local cflags="-Wall -fPIC -MMD -MP -arch ${arch}"
  local ldflags="-stdlib=libc++ -arch ${arch}"

  local os_name=""

  if [ "$os" = "darwin" ]; then
    os_name="macOS"
    local sdk_root=$(xcrun --sdk macosx --show-sdk-path)

    cflags="${cflags} -isysroot ${sdk_root} -mmacosx-version-min=${MACOS_VERSION_MIN}"
    ldflags="${ldflags} -isysroot ${sdk_root} -mmacosx-version-min=${MACOS_VERSION_MIN}"
  elif [ "$os" = "ios" ]; then
    os_name="iOS"
    local sdk_root=$(xcrun --sdk iphoneos --show-sdk-path)

    cflags="${cflags} -isysroot ${sdk_root} -miphoneos-version-min=${IOS_VERSION_MIN} -target ${arch}-apple-ios"
    ldflags="${ldflags} -isysroot ${sdk_root} -miphoneos-version-min=${IOS_VERSION_MIN} -target ${arch}-apple-ios"
  elif [ "$os" = "iossimulator" ]; then
    os_name="iOS Simulator"
    local sdk_root=$(xcrun --sdk iphonesimulator --show-sdk-path)

    cflags="${cflags} -isysroot ${sdk_root} -miphoneos-version-min=${IOS_VERSION_MIN} -target ${arch}-apple-ios-simulator"
    ldflags="${ldflags} -isysroot ${sdk_root} -miphoneos-version-min=${IOS_VERSION_MIN}  -target ${arch}-apple-ios-simulator"
  fi

  echo "Cleaning"
  make clean -C "${BUILD_DIR}"

  echo "Making Openh264 for ${os_name} ${arch}"
  make -C "${BUILD_DIR}" \
    ARCH="${arch}" \
    CFLAGS="${cflags}" \
    LDFLAGS="${ldflags}"

  make install -C "${BUILD_DIR}" \
    DESTDIR="${build_target_dir}" \
    PREFIX="" \
    ARCH="${arch}" \
    CFLAGS="${cflags}" \
    LDFLAGS="${ldflags}"

  echo "Removing all dylibs"
  find "${build_target_dir}/lib" -iname '*.dylib' -delete

  echo "Removing pkgconfig dir"
  rm -fr "${build_target_dir}/lib/pkgconfig"
}

make_universal_lib() {
  local file_name="$1"
  local target_dir="$2"
  local source_dir_1="$3"
  local source_dir_2="$4"

  if [[ -d "${target_dir}" ]]; then
    rm -rf "${target_dir}"
  fi

  mkdir -p "${target_dir}"

  echo "Making universal binary at ${target_dir}/${file_name} out of ${source_dir_1}/${file_name} and ${source_dir_2}/${file_name}"

  lipo -create \
    "${source_dir_1}/${file_name}" \
    "${source_dir_2}/${file_name}" \
    -output "${target_dir}/${file_name}"
}

TARGET_DIR_MACOS_ARM64="${TARGET_DIR}/macosx-arm64"
TARGET_DIR_MACOS_X86="${TARGET_DIR}/macosx-x86_64"
TARGET_DIR_IOS_ARM64="${TARGET_DIR}/iphoneos"
TARGET_DIR_IOS_SIMULATOR_ARM64="${TARGET_DIR}/iphonesimulator-arm64"
TARGET_DIR_IOS_SIMULATOR_X86="${TARGET_DIR}/iphonesimulator-x86_64"

build "darwin" "arm64" "${TARGET_DIR_MACOS_ARM64}"
build "darwin" "x86_64" "${TARGET_DIR_MACOS_X86}"
build "ios" "arm64" "${TARGET_DIR_IOS_ARM64}"
build "iossimulator" "arm64" "${TARGET_DIR_IOS_SIMULATOR_ARM64}"
build "iossimulator" "x86_64" "${TARGET_DIR_IOS_SIMULATOR_X86}"

TARGET_DIR_MACOS_UNIVERSAL="${TARGET_DIR}/macosx"
TARGET_DIR_IOS_SIMULATOR_UNIVERSAL="${TARGET_DIR}/iphonesimulator"

make_universal_lib \
  "libopenh264.a" \
  "${TARGET_DIR_MACOS_UNIVERSAL}/lib" \
  "${TARGET_DIR_MACOS_ARM64}/lib" \
  "${TARGET_DIR_MACOS_X86}/lib"

cp -r \
  "${TARGET_DIR_MACOS_ARM64}/include" \
  "${TARGET_DIR_MACOS_UNIVERSAL}/include"

make_universal_lib \
  "libopenh264.a" \
  "${TARGET_DIR_IOS_SIMULATOR_UNIVERSAL}/lib" \
  "${TARGET_DIR_IOS_SIMULATOR_ARM64}/lib" \
  "${TARGET_DIR_IOS_SIMULATOR_X86}/lib"

cp -r \
  "${TARGET_DIR_IOS_SIMULATOR_ARM64}/include" \
  "${TARGET_DIR_IOS_SIMULATOR_UNIVERSAL}/include"

echo "Creating Apple-Universal XCFramework at ${TARGET_DIR}/Openh264.xcframework"

xcodebuild -create-xcframework \
  -library "${TARGET_DIR_MACOS_UNIVERSAL}/lib/libopenh264.a" \
  -library "${TARGET_DIR_IOS_ARM64}/lib/libopenh264.a" \
  -library "${TARGET_DIR_IOS_SIMULATOR_UNIVERSAL}/lib/libopenh264.a" \
  -output "${TARGET_DIR}/Openh264.xcframework"

echo "Codesigning XCFramework"

codesign \
    --force --deep --strict \
    --sign "${CODESIGN_ID}" \
    "${TARGET_DIR}/Openh264.xcframework"