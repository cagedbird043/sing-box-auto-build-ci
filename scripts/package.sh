#!/bin/bash
set -e

GOOS=$1
GOARCH=$2
GOAMD64_LEVEL=$3
VERSION_TAG=$4
BRANCH=$5 # 新增参数：区分分支，防止产物重名

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR="${ROOT_DIR}/output"
mkdir -p "$OUT_DIR"

BINARY_NAME="sing-box"
[ "$GOOS" == "windows" ] && BINARY_NAME="sing-box.exe"

# 产物名包含分支标识，例如：sing-box-v1.12.14-reF1nd-main-android-arm64.tar.gz
PKG_NAME="sing-box-${VERSION_TAG}-${BRANCH}-${GOOS}-${GOARCH}${GOAMD64_LEVEL}"

if [ "$GOOS" == "windows" ]; then
    zip -qj "${OUT_DIR}/${PKG_NAME}.zip" "$BINARY_NAME"
else
    chmod +x "$BINARY_NAME"
    tar -czf "${OUT_DIR}/${PKG_NAME}.tar.gz" "$BINARY_NAME"
fi