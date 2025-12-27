#!/bin/bash
set -e

GOOS=$1
GOARCH=$2
GOAMD64_LEVEL=$3
VERSION_TAG=$4

# 剔除 with_ech，适配 v1.12+
BUILD_TAGS="with_gvisor,with_quic,with_dhcp,with_wireguard,with_utls,with_acme,with_clash_api,with_tailscale"

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

echo "Building for $GOOS/$GOARCH $GOAMD64_LEVEL (Version: $VERSION_TAG)"
go build -v -trimpath -tags "$BUILD_TAGS" -ldflags "$LDFLAGS" -o "$OUTPUT_NAME" ./cmd/sing-box