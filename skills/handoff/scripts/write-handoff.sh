#!/usr/bin/env bash
# write-handoff.sh — 生成 handoff 文件路径（处理重名）
# 用法: write-handoff.sh [目录路径]
# 输出: 可写入的 handoff 文件完整路径

set -euo pipefail

OUTPUT_DIR="${1:-.}"
TODAY=$(date +%y%m%d)
BASE_NAME="${TODAY}-handoff"

# 确定文件路径，避免覆盖
if [[ ! -f "$OUTPUT_DIR/${BASE_NAME}.md" ]]; then
  echo "$OUTPUT_DIR/${BASE_NAME}.md"
else
  SEQ=2
  while [[ -f "$OUTPUT_DIR/${BASE_NAME}-${SEQ}.md" ]]; do
    ((SEQ++))
  done
  echo "$OUTPUT_DIR/${BASE_NAME}-${SEQ}.md"
fi
