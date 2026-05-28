#!/usr/bin/env bash
# 探测晴芽 miniapp backend 路径
#
# 用途：plugin skill / commands 调 `python -m app.cli.operator` 前先定位
# miniapp backend 的绝对路径，避免 hardcode 给跨机器迁移留口子。
#
# 输出：成功时 stdout 打印 backend 绝对路径（无尾换行干扰），exit 0
# 失败：stderr 提示候选路径 + 排错建议，exit 1

set -euo pipefail

# 候选路径列表（按优先级）：
# - 本机 Jason 的标准工作区位置
# - 后续可加：production server / docker-mounted 路径
CANDIDATES=(
  "$HOME/0-WORKSPACE/30-QingYa/产品/miniapp/backend"
)

for path in "${CANDIDATES[@]}"; do
  if [ -d "$path" ] && [ -f "$path/pyproject.toml" ]; then
    # 同时校验 operator 包存在（QY-68 + QY-69 已合并的标志）
    if [ -d "$path/app/cli/operator" ] && [ -f "$path/app/cli/operator/dump.py" ]; then
      echo "$path"
      exit 0
    fi
    # backend 在但 operator 包缺失 → 给具体提示
    echo "❌ 找到 backend ($path) 但缺 app/cli/operator/dump.py" >&2
    echo "提示：检查 QY-68/QY-69 是否已合并到 main" >&2
    exit 1
  fi
done

# 全部候选未命中
echo "❌ 未找到 miniapp backend" >&2
echo "已尝试以下候选路径：" >&2
for path in "${CANDIDATES[@]}"; do
  echo "  - $path" >&2
done
echo "" >&2
echo "请确认：" >&2
echo "  1. miniapp repo 已 clone 到 ~/0-WORKSPACE/30-QingYa/产品/miniapp/" >&2
echo "  2. 该目录下有 backend/pyproject.toml + backend/app/cli/operator/" >&2
exit 1
