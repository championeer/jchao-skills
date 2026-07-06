#!/usr/bin/env bash
# write-handoff.sh — 生成 handoff 文件路径（目录归属 + 同日重名）
# 用法: write-handoff.sh [目录路径]
# 输出: 可写入的 handoff 文件完整路径
#
# 目录归属（与 find-handoff.sh / SKILL.md 三方一致）：
#   有 handoffs/       → 写入 handoffs/
#   有 docs/handoffs/  → 写入 docs/handoffs/
#   否则               → 创建 handoffs/ 并写入（2026-07-06 起 handoffs/ 是默认归宿，
#                        不再回落项目根——根目录 handoff 散乱是历史痛点，见 SKILL.md §文件命名与存储）
#
# 历史 bug（2026-06-09 修）：原版只在传入目录【根】下检测重名，不识别
# handoffs/ 子目录 → 既把文件写错位置（散落项目根、与既有 handoffs/ 脱节），
# 又因根目录下无同名文件而永远返回无序号的 `YYMMDD-handoff.md`，导致同日
# 第 2/3 份的序号递增彻底失效（详见 30-QingYa/产品/miniapp/tasks/lessons.md
# "2026-06-08" 条衍生 + handoffs/260609-handoff-3.md 踩坑记录）。
# 注：[[ -d ]] 会跟随软链，故 miniapp/handoffs -> 根 handoffs 的软链场景同样正确。

set -euo pipefail

OUTPUT_DIR="${1:-.}"
TODAY=$(date +%y%m%d)
BASE_NAME="${TODAY}-handoff"

# 确定目标目录（优先已有 handoffs/，其次已有 docs/handoffs/，都没有则创建 handoffs/）
if [[ -d "$OUTPUT_DIR/handoffs" ]]; then
  TARGET_DIR="$OUTPUT_DIR/handoffs"
elif [[ -d "$OUTPUT_DIR/docs/handoffs" ]]; then
  TARGET_DIR="$OUTPUT_DIR/docs/handoffs"
else
  TARGET_DIR="$OUTPUT_DIR/handoffs"
  mkdir -p "$TARGET_DIR"
fi

# 在目标目录里确定文件路径，避免覆盖同日已有文件
if [[ ! -f "$TARGET_DIR/${BASE_NAME}.md" ]]; then
  echo "$TARGET_DIR/${BASE_NAME}.md"
else
  SEQ=2
  while [[ -f "$TARGET_DIR/${BASE_NAME}-${SEQ}.md" ]]; do
    ((SEQ++))
  done
  echo "$TARGET_DIR/${BASE_NAME}-${SEQ}.md"
fi
