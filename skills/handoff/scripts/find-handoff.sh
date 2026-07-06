#!/usr/bin/env bash
# find-handoff.sh — 在指定目录中查找最新的 handoff 文件
# 用法: find-handoff.sh [目录路径]
# 默认搜索当前工作目录
#
# 查找逻辑：两梯队硬优先（2026-07-06 改）——
#   第一梯队：handoffs/ 与 docs/handoffs/（规范位置）
#   第二梯队：目录根（仅第一梯队空时才启用，历史遗留兜底）
# 第一梯队有命中就完全无视根目录——根目录的 *handoff*.md 视为噪声
# （说明文档 / 旧遗留），纯 mtime 混搜会被它劫持"最新"。
# 梯队内排序：按 mtime descending（最近修改的在前），用 /bin/ls -t 实现。
#
# 历史 bug：原版用 lexicographic sort + tail -1，遇到同日多 handoff 时
# 字母序会把无 number 后缀的（如 `260526-handoff.md`）排在带 number 后缀
# 的（如 `260526-handoff-14.md`）之后（因 `.` 0x2E > `-` 0x2D），返回错的"最新"。
# 修复时机：2026-05-26（QY-63 PR #115 期间踩坑，详见 30-QingYa/产品/miniapp/
# tasks/lessons.md 的 "2026-05-26: handoff 接手前手工验证最新文件" 条目）。
#
# 用 /bin/ls 绝对路径调用，避免被用户 shell alias（如 eza）污染。

set -euo pipefail

SEARCH_DIR="${1:-.}"

# 收集候选：先扫第一梯队（handoffs/ + docs/handoffs/），空了才扫第二梯队（目录根）。
# -L 跟随符号链接：子项目的 handoffs/ 常是指向根 handoffs/ 的软链
# （如 miniapp/handoffs -> ../../handoffs）。不加 -L 时 find 不进入
# 作为起点的软链目录 → 漏掉全部文件返回 NO_HANDOFF_FOUND（2026-05-29 踩坑）。
collect_from() {
  local loc
  for loc in "$@"; do
    if [[ -d "$loc" ]]; then
      while IFS= read -r -d '' f; do
        CANDIDATES+=("$f")
      done < <(find -L "$loc" -maxdepth 1 -name '*-handoff*.md' -print0 2>/dev/null)
    fi
  done
}

CANDIDATES=()
collect_from "$SEARCH_DIR/handoffs" "$SEARCH_DIR/docs/handoffs"
if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  collect_from "$SEARCH_DIR"
fi

if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
  echo "NO_HANDOFF_FOUND"
  exit 0
fi

# 按 mtime descending 排序，取最新一个。
# /bin/ls -t 在 macOS（BSD ls）和 Linux（GNU ls）都支持。
# head -1 取 descending 序列的第一个（=最近修改）。
LATEST=$(/bin/ls -t "${CANDIDATES[@]}" 2>/dev/null | head -1)

echo "$LATEST"
