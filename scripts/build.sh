#!/bin/bash
set -e

GOOS=$1
GOARCH=$2
GOAMD64_LEVEL=$3
VERSION_TAG=$4

# 设置 Tags (包含 ref1nd 特色 tags)
BUILD_TAGS="with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_tailscale,with_ech"

# 1. 强制使用本地最新的工具链，不再进行回退切换
export GOTOOLCHAIN=local
export GOOS=$GOOS
export GOARCH=$GOARCH
export CGO_ENABLED=0

if [ "$GOARCH" == "amd64" ] && [ -n "$GOAMD64_LEVEL" ]; then
    export GOAMD64=$GOAMD64_LEVEL
fi

# 注入版本信息并编译
LDFLAGS="-s -w -X 'github.com/sagernet/sing-box/constant.Version=${VERSION_TAG}' -buildid= -checklinkname=0"

OUTPUT_NAME="sing-box"
[ "$GOOS" == "windows" ] && OUTPUT_NAME="sing-box.exe"

echo "使用工具链信息: $(go version)"
echo "开始构建: $GOOS $GOARCH $GOAMD64_LEVEL (Tag: $VERSION_TAG)"
go build -v -trimpath -tags "$BUILD_TAGS" -ldflags "$LDFLAGS" -o "$OUTPUT_NAME" ./cmd/sing-box
