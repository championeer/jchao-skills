#!/usr/bin/env bash
# find-handoff.sh — 在指定目录中查找最新的 handoff 文件
# 用法: find-handoff.sh [目录路径]
# 默认搜索当前工作目录

set -euo pipefail

SEARCH_DIR="${1:-.}"

# 搜索范围：项目根目录 + handoffs/ 子目录
find_handoff_files() {
  local dir="$1"
  local files=()

  # 搜索根目录
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$dir" -maxdepth 1 -name '*-handoff*.md' -print0 2>/dev/null)

  # 搜索 handoffs/ 子目录
  if [[ -d "$dir/handoffs" ]]; then
    while IFS= read -r -d '' f; do
      files+=("$f")
    done < <(find "$dir/handoffs" -maxdepth 1 -name '*-handoff*.md' -print0 2>/dev/null)
  fi

  # 搜索 docs/handoffs/ 子目录
  if [[ -d "$dir/docs/handoffs" ]]; then
    while IFS= read -r -d '' f; do
      files+=("$f")
    done < <(find "$dir/docs/handoffs" -maxdepth 1 -name '*-handoff*.md' -print0 2>/dev/null)
  fi

  if [[ ${#files[@]} -gt 0 ]]; then
    printf '%s\n' "${files[@]}"
  fi
}

# 查找所有 handoff 文件，按修改时间排序（最新在最后）
HANDOFF_FILES=$(find_handoff_files "$SEARCH_DIR" | sort)

if [[ -z "$HANDOFF_FILES" ]]; then
  echo "NO_HANDOFF_FOUND"
  exit 0
fi

# 取最新的一个（文件名按 yymmdd 排序，最后一个最新）
LATEST=$(echo "$HANDOFF_FILES" | tail -1)

echo "$LATEST"
