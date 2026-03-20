#!/bin/bash
# append-log.sh — Append a work log entry to today's daily log
# Usage: bash append-log.sh <project_tag> <title> <bullets> [tags]

set -euo pipefail

LOG_BASE="$HOME/0-WORKSPACE/40-Founder/40-Logs"
TODAY=$(date +%Y-%m-%d)
MONTH=$(date +%Y-%m)
NOW=$(date +%H:%M)

# Core projects that get the #core tag automatically
CORE_PROJECTS="AIPO MedClaw QingYa"

PROJECT_TAG="${1:?Usage: append-log.sh <project_tag> <title> <bullets> [tags]}"
TITLE="${2:?Missing title}"
BULLETS="${3:?Missing bullet points}"
TAGS="${4:-}"

LOG_DIR="$LOG_BASE/$MONTH"
LOG_FILE="$LOG_DIR/$TODAY.md"

# Auto-prepend #core tag for core projects
IS_CORE=false
for cp in $CORE_PROJECTS; do
  if [ "$PROJECT_TAG" = "$cp" ]; then
    IS_CORE=true
    break
  fi
done

if [ "$IS_CORE" = true ]; then
  # Prepend #core if not already present
  if [[ "$TAGS" != *"#core"* ]]; then
    TAGS="#core $TAGS"
  fi
fi

# Trim whitespace from tags
TAGS=$(echo "$TAGS" | xargs)

# Create month directory if needed
mkdir -p "$LOG_DIR"

# Create daily log file from template if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
  cat > "$LOG_FILE" <<EOF
# $TODAY

## 今日要事（Top 3）

1.
2.
3.

## 工作记录


## 思考 & 洞察


## 明日计划

EOF
  echo "Created new daily log: $LOG_FILE"
fi

# Build the entry
ENTRY="### $NOW · $PROJECT_TAG · $TITLE"

# Build tags line
TAGS_LINE=""
if [ -n "$TAGS" ]; then
  TAGS_LINE="Tags: $TAGS"
fi

# Insert before "## 思考 & 洞察" section
TEMP_FILE=$(mktemp)
INSERTED=false

while IFS= read -r line; do
  if [[ "$line" == "## 思考 & 洞察" ]] && [ "$INSERTED" = false ]; then
    echo "$ENTRY" >> "$TEMP_FILE"
    if [ -n "$TAGS_LINE" ]; then
      echo "$TAGS_LINE" >> "$TEMP_FILE"
    fi
    echo "$BULLETS" >> "$TEMP_FILE"
    echo "" >> "$TEMP_FILE"
    INSERTED=true
  fi
  echo "$line" >> "$TEMP_FILE"
done < "$LOG_FILE"

# If we couldn't find the marker, just append to end
if [ "$INSERTED" = false ]; then
  echo "" >> "$TEMP_FILE"
  echo "$ENTRY" >> "$TEMP_FILE"
  if [ -n "$TAGS_LINE" ]; then
    echo "$TAGS_LINE" >> "$TEMP_FILE"
  fi
  echo "$BULLETS" >> "$TEMP_FILE"
fi

mv "$TEMP_FILE" "$LOG_FILE"

CORE_LABEL=""
if [ "$IS_CORE" = true ]; then
  CORE_LABEL=" [CORE]"
fi

echo "Logged:${CORE_LABEL} $NOW · $PROJECT_TAG · $TITLE → $LOG_FILE"
if [ -n "$TAGS" ]; then
  echo "Tags: $TAGS"
fi
