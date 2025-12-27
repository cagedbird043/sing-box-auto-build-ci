#!/bin/bash
set -e

GOOS=$1
GOARCH=$2
GOAMD64_LEVEL=$3
VERSION_TAG=$4

# 获取脚本所在目录的上一级作为工程根目录
# 这样无论在 source 还是 test_env 运行，产物都统一放在根目录下的 output
ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
OUT_DIR="${ROOT_DIR}/output"
mkdir -p "$OUT_DIR"

BINARY_NAME="sing-box"
[ "$GOOS" == "windows" ] && BINARY_NAME="sing-box.exe"

# 如果二进制不存在，报错
if [ ! -f "$BINARY_NAME" ]; then
    echo "❌ 错误: 找不到二进制文件 $BINARY_NAME"
    exit 1
fi

# 构造重命名逻辑
PKG_NAME="sing-box-${VERSION_TAG}-${GOOS}-${GOARCH}${GOAMD64_LEVEL}"

echo "正在包装: $PKG_NAME"

if [ "$GOOS" == "windows" ]; then
    zip -qj "${OUT_DIR}/${PKG_NAME}.zip" "$BINARY_NAME"
else
    chmod +x "$BINARY_NAME"
    # 使用 -C 参数切换目录，避免把路径层级也压进去
    tar -czf "${OUT_DIR}/${PKG_NAME}.tar.gz" "$BINARY_NAME"
fi

echo "✅ 产物已导出至: ${OUT_DIR}"