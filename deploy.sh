#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PUBLISH_REPO_DIR="${ROOT_DIR}/../salmon7.github.io"
cd "$ROOT_DIR"

echo "[1/6] 检查依赖..."
if [[ ! -d node_modules ]]; then
  npm install
fi

echo "[2/6] 清理并生成静态文件..."
npx hexo clean
npx hexo generate

echo "[3/6] 检查发布仓库..."
if [[ ! -d "$PUBLISH_REPO_DIR/.git" ]]; then
  echo "未找到发布仓库: $PUBLISH_REPO_DIR"
  echo "请先确保 salmon7.github.io 在 HexoBlog 同级目录。"
  exit 1
fi

echo "[4/6] 同步生成文件到发布仓库..."
rsync -a --delete "$ROOT_DIR/public/" "$PUBLISH_REPO_DIR/"

echo "[5/6] 提交并推送到 salmon7.github.io..."
cd "$PUBLISH_REPO_DIR"
git checkout master
git pull --ff-only origin master

git add -A
if git diff --cached --quiet; then
  echo "没有内容变化，跳过提交。"
else
  git commit -m "Site updated: $(date '+%Y-%m-%d %H:%M:%S')"
  git push origin master
fi

echo "[6/6] 发布完成，建议检查："
echo "- https://blog.zhang7long.com"
echo "- salmon7.github.io 仓库最新提交"
echo "- CNAME 是否仍为 blog.zhang7long.com"
