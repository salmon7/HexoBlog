#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "[1/4] 检查依赖..."
if [[ ! -d node_modules ]]; then
  npm install
fi

echo "[2/4] 清理并生成静态文件..."
npx hexo clean
npx hexo generate

echo "[3/4] 发布到 salmon7.github.io..."
npx hexo deploy

echo "[4/4] 发布完成，建议检查："
echo "- https://blog.zhang7long.com"
echo "- salmon7.github.io 仓库是否有新提交"
echo "- CNAME 是否仍为 blog.zhang7long.com"
