#!/usr/bin/env bash

set -e

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo "Script Path: ${SCRIPT_PATH}"

if [[ -z $OPENH264_VERSION ]]; then
  echo "OPENH264_VERSION not set; aborting"
  exit 1
fi

BUILD_DIR="${SCRIPT_PATH}/../build/openh264-${OPENH264_VERSION}/build"
echo "Build Path: ${BUILD_DIR}"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "Build dir not found: ${BUILD_DIR}"
  exit 1
fi

pushd "${BUILD_DIR}"

echo "Creating ${BUILD_DIR}/openh264.tar.gz"
rm -f "openh264.tar.gz"
tar czf "openh264.tar.gz" iphoneos iphonesimulator macosx

echo "Creating ${BUILD_DIR}/Openh264.xcframework.tar.gz"
rm -f "Openh264.xcframework.tar.gz"
tar czf "Openh264.xcframework.tar.gz" Openh264.xcframework

popd