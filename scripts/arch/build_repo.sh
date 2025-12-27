#!/bin/bash
set -e

# 参数定义
BRANCH=$1      # reF1nd-main 或 reF1nd-dev
VERSION=$2     # v1.12.14
BINARY_DIR=$3  # Artifacts 存放路径
REPO_TOKEN=$4  # 你的 Fine-grained PAT

REPO_NAME="cagedbird-repo"
REPO_URL="https://x-access-token:${REPO_TOKEN}@github.com/cagedbird043/cagedbird-pacman-repo.git"

# 1. 确定包名和版本 (Arch 不允许版本号带横杠)
if [ "$BRANCH" == "reF1nd-main" ]; then
    PKGNAME="sing-box-ref1nd"
    CLEAN_VER="${VERSION#v}"
else
    PKGNAME="sing-box-ref1nd-dev"
    CLEAN_VER="${VERSION#v}"
    CLEAN_VER="${CLEAN_VER//-/_}" # 1.13.0-alpha.34 -> 1.13.0_alpha.34
fi

# 2. 准备工作区并克隆仓库仓
mkdir -p arch_work
cd arch_work
git clone "$REPO_URL" repo_dest

# 3. 准备源码辅助文件 (从上游抓取 release 源码包)
wget -O source.tar.gz "https://github.com/SagerNet/sing-box/archive/${VERSION}.tar.gz"
mkdir -p src_aux
tar -xzf source.tar.gz -C src_aux --strip-components=1

# 4. 架构循环构建：x86_64 和 aarch64
ARCHS=("x86_64" "aarch64")
for ARCH in "${ARCHS[@]}"; do
    echo "📦 Packaging for $ARCH..."
    
    # 匹配对应的二进制产物
    if [ "$ARCH" == "x86_64" ]; then
        # 优先使用 v3，没有则回退
        BIN_SRC="$BINARY_DIR/bin-$BRANCH-linux-amd64v3/sing-box"
        [ ! -f "$BIN_SRC" ] && BIN_SRC="$BINARY_DIR/bin-$BRANCH-linux-amd64/sing-box"
    else
        BIN_SRC="$BINARY_DIR/bin-$BRANCH-linux-arm64/sing-box"
    fi

    [ ! -f "$BIN_SRC" ] && { echo "⚠️ 跳过 $ARCH: 找不到二进制"; continue; }

    # 准备 makepkg 目录
    BUILD_DIR="build_$ARCH"
    mkdir -p "$BUILD_DIR"
    cp ../scripts/arch/PKGBUILD "$BUILD_DIR/PKGBUILD"
    cp -r src_aux "$BUILD_DIR/"
    cp "$BIN_SRC" "$BUILD_DIR/sing-box-bin"
    
    # 注入变量到 PKGBUILD
    sed -i "s/_PKGNAME_/$PKGNAME/g" "$BUILD_DIR/PKGBUILD"
    sed -i "s/_PKGVER_/$CLEAN_VER/g" "$BUILD_DIR/PKGBUILD"
    sed -i "s/_ARCH_OPTS_/$ARCH/g" "$BUILD_DIR/PKGBUILD"

    # 执行打包 (在容器内通常需要授权 nobody 用户)
    chmod -R 777 "$BUILD_DIR"
    cd "$BUILD_DIR"
    # 使用 --nodeps 因为我们已经有二进制了，不需要安装 go
    sudo -u nobody CARCH=$ARCH makepkg -f --nodeps
    
    # 将结果拷贝到仓库目录
    cd ..
    mkdir -p "repo_dest/$ARCH"
    cp "$BUILD_DIR"/*.pkg.tar.zst "repo_dest/$ARCH/"
    
    # 更新 Pacman 数据库
    cd "repo_dest/$ARCH"
    repo-add "$REPO_NAME.db.tar.zst" *.pkg.tar.zst
    cd ../..
done

# 5. 提交回仓库仓
cd repo_dest
git config user.name "CI-Bot"
git config user.email "ci@cagedbird.top"
git add .
git commit -m "Update $PKGNAME to $VERSION" || echo "No changes to commit"
git push