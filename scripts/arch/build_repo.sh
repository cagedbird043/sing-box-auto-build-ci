#!/bin/bash
set -e

# 参数定义
BRANCH=$1      # reF1nd-main 或 reF1nd-dev
VERSION=$2     # v1.12.14
BINARY_DIR=$3  # Artifacts 存放路径 (例如 $(pwd)/artifacts)
REPO_TOKEN=$4  # 你的 Fine-grained PAT

REPO_NAME="cagedbird-repo"
REPO_URL="https://x-access-token:${REPO_TOKEN}@github.com/Mice-Tailor-Infra/cagedbird-pacman-repo.git"

# 处理版本号
RAW_VER="${VERSION#v}"
if [ "$BRANCH" == "reF1nd-main" ]; then
    PKGNAME="sing-box-ref1nd"
    CLEAN_VER="$RAW_VER"
else
    PKGNAME="sing-box-ref1nd-dev"
    CLEAN_VER="${RAW_VER//-/_}"
fi

# 2. 预准备：先把两个架构的 .zst 包都打出来，存在内存/临时目录里
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

# 3. 核心：带重试逻辑的入库推送
MAX_RETRIES=5
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "🔄 尝试入库推送 (第 $((RETRY_COUNT+1)) 次)..."
    
    # 每次重试都重新 clone，确保基础环境绝对纯净
    rm -rf repo_dest
    git clone "$REPO_URL" repo_dest
    
    # 将刚才备份的包拷进去
    for ARCH in "x86_64" "aarch64"; do
        mkdir -p "repo_dest/$ARCH"
        # 只拷贝符合当前架构的包
        cp /tmp/pkg_bak/*-${ARCH}.pkg.tar.zst "repo_dest/$ARCH/" 2>/dev/null || true
    done
    
    # 更新索引并清理备份文件
    cd repo_dest
    for ARCH in "x86_64" "aarch64"; do
        if [ -d "$ARCH" ]; then
            cd "$ARCH"
            repo-add "$REPO_NAME.db.tar.zst" *.pkg.tar.zst
            rm -f *.old # 强迫症：清理旧索引
            cd ..
        fi
    done
    
    # 尝试提交
    git config user.name "CI-Bot"
    git config user.email "ci@cagedbird.top"
    git add .
    if git diff --quiet && git diff --staged --quiet; then
        echo "✅ 仓库内容无变动，无需推送。"
        exit 0
    fi
    
    git commit -m "Update $PKGNAME to $VERSION"
    
    if git push origin main; then
        echo "✨ 任务达成！入库成功。"
        exit 0
    else
        echo "⚠️ 推送冲突（有人抢坑），等待 5 秒后重试..."
        RETRY_COUNT=$((RETRY_COUNT+1))
        cd ..
        sleep 5
    fi
done

echo "❌ 失败：多次重试后仍无法解决并发冲突。"
exit 1