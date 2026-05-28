#!/usr/bin/env bash
# 检查 miniapp postgres docker 容器是否在跑
#
# 用途：plugin skill / commands 调 `python -m app.cli.operator dump` 前
# 提前 fail-fast，避免 DB 连接失败错误堆栈 + 给用户具体启动提示。
#
# 输出：postgres 在跑 → stdout 打印 "✓ postgres 运行中"，exit 0
# 失败：stderr 给启动命令，exit 1

set -euo pipefail

# 用 docker ps 直接查 postgres 容器（兼容 docker compose v1/v2 + bare docker）。
# 不假设 compose 文件位置或工程名，避免 sudo / cwd 依赖。
#
# 实际环境观察（Jason 本机 2026-05-28）：
#   - deploy-postgres-1 (compose 起的)
#   - my-postgres (bare docker 起的，备用)
# 任何一个 status=running 即认为可用。
if docker ps \
    --filter "name=postgres" \
    --filter "status=running" \
    --format "{{.Names}}" 2>/dev/null | grep -q .; then
  echo "✓ postgres 运行中"
  exit 0
fi

# 没找到运行中的 postgres
echo "❌ postgres 容器未运行" >&2
echo "" >&2
echo "启动命令：" >&2
echo "  cd ~/0-WORKSPACE/30-QingYa/产品/miniapp/deploy" >&2
echo "  sudo docker compose up -d postgres" >&2
echo "" >&2
echo "或检查是否已被停止：" >&2
echo "  docker ps -a --filter name=postgres" >&2
exit 1
