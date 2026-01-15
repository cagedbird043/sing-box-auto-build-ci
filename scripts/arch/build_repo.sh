#!/bin/bash
set -e

# 参数定义
BRANCH=$1      # reF1nd-main 或 reF1nd-dev
VERSION=$2     # v1.12.14
BINARY_DIR=$3  # Artifacts 存放路径 (例如 $(pwd)/artifacts)
# REPO_TOKEN 不再直接用于 git 认证，gh CLI 会使用环境变量中的 GH_TOKEN

REPO_NAME="cagedbird-repo"
TARGET_REPO_OWNER="Mice-Tailor-Infra"
TARGET_REPO_NAME="cagedbird-pacman-repo"
TARGET_REPO="$TARGET_REPO_OWNER/$TARGET_REPO_NAME"

# 处理版本号
RAW_VER="${VERSION#v}"
if [ "$BRANCH" == "reF1nd-main" ]; then
    PKGNAME="sing-box-ref1nd"
    CLEAN_VER="$RAW_VER"
    REL_SUFFIX=""
else
    PKGNAME="sing-box-ref1nd-dev"
    CLEAN_VER="${RAW_VER//-/_}"
    REL_SUFFIX="-dev"
fi

# 2. 预准备：构建全架构安装包
echo "🛠️ 正在本地构建全架构安装包..."
mkdir -p /tmp/pkg_bak

for ARCH in "x86_64" "aarch64"; do
    if [ "$ARCH" == "x86_64" ]; then
        ART_DIR="$BINARY_DIR/bin-$BRANCH-linux-amd64v3"
        [ ! -d "$ART_DIR" ] && ART_DIR="$BINARY_DIR/bin-$BRANCH-linux-amd64"
    else
        ART_DIR="$BINARY_DIR/bin-$BRANCH-linux-arm64"
    fi

    TAR_PATH=$(find "$ART_DIR" -name "*.tar.gz" | head -n 1)
    if [ -f "$TAR_PATH" ]; then
        BUILD_DIR="build_$ARCH"; mkdir -p "$BUILD_DIR"
        cp scripts/arch/PKGBUILD "$BUILD_DIR/PKGBUILD"
        tar -xzf "$TAR_PATH" -O sing-box > "$BUILD_DIR/sing-box-bin"
        
        sed -i "s/_PKGNAME_/$PKGNAME/g" "$BUILD_DIR/PKGBUILD"
        sed -i "s/_PKGVER_/$CLEAN_VER/g" "$BUILD_DIR/PKGBUILD"
        sed -i "s/_RAWVER_/$RAW_VER/g" "$BUILD_DIR/PKGBUILD"
        sed -i "s/_ARCH_OPTS_/$ARCH/g" "$BUILD_DIR/PKGBUILD"
        
        chmod -R 777 "$BUILD_DIR"
        (cd "$BUILD_DIR" && sudo -u nobody CARCH=$ARCH makepkg -f --nodeps)
        
        # 存入备份目录
        cp "$BUILD_DIR"/*.pkg.tar.zst /tmp/pkg_bak/
    fi
done

# 3. 核心：发布到 GitHub Releases (分架构)
for ARCH in "x86_64" "aarch64"; do
    TAG="arch-${ARCH}${REL_SUFFIX}"
    echo "🚀 正在处理架构 $ARCH -> Release Tag: $TAG"

    # 确保 Release 存在
    gh release create "$TAG" -R "$TARGET_REPO" --title "$TAG" --notes "Arch Pacman Repository for $ARCH ($BRANCH)" || true

    # 创建工作目录
    WORKDIR="repo_$ARCH"
    mkdir -p "$WORKDIR"
    
    # 尝试从 Release 下载现有的数据库 (如果不存在则忽略)
    echo "📩 尝试同步云端元数据..."
    gh release download "$TAG" -R "$TARGET_REPO" -p "$REPO_NAME.db.tar.zst" --dir "$WORKDIR" || echo "New repository metadata will be created."

    # 拷贝刚才打好的新包
    cp /tmp/pkg_bak/*-${ARCH}.pkg.tar.zst "$WORKDIR/" 2>/dev/null || true

    # 更新索引
    cd "$WORKDIR"
    if [ "$(ls *.pkg.tar.zst 2>/dev/null)" ]; then
        echo "📦 正在更新仓库索引..."
        repo-add "$REPO_NAME.db.tar.zst" *.pkg.tar.zst
        rm -f *.old # 清理旧索引
        
        # 上传新包和更新后的元数据到 Release
        # --clobber 会覆盖已存在的同名文件 (对于 .db 特别重要)
        echo "📤 正在上传产物至 GitHub Releases..."
        gh release upload "$TAG" -R "$TARGET_REPO" --clobber *
    else
        echo "⚠️ 未发现 $ARCH 架构的包文件，跳过。"
    fi
    cd ..
done

echo "✨ 任务达成！所有架构已发布至 GitHub Releases。"