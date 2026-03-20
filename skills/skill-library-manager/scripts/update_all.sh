#!/bin/bash
# MedClaw Skill Library - 一键更新所有技能仓库
# 用法: bash <skill-dir>/scripts/update_all.sh

set -e

LIB="${MEDCLAW_SKILL_LIBRARY:-/Volumes/Extreme-Pro/MedClaw_SkillLibrary}"
REPO_DIR="$LIB/repos"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$SCRIPT_DIR/update.log"

echo "======================================" | tee -a "$LOG_FILE"
echo "MedClaw Skill Library Update - $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"

update_repo() {
    local repo_name="$1"
    local repo_path="$REPO_DIR/$repo_name"

    if [ -d "$repo_path/.git" ]; then
        echo "Updating: $repo_name ..." | tee -a "$LOG_FILE"
        cd "$repo_path"
        git fetch origin 2>&1 | tee -a "$LOG_FILE"
        local LOCAL=$(git rev-parse HEAD)
        local REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "no-upstream")
        if [ "$LOCAL" = "$REMOTE" ]; then
            echo "  Already up to date." | tee -a "$LOG_FILE"
        elif [ "$REMOTE" = "no-upstream" ]; then
            echo "  No upstream branch configured, skipping pull." | tee -a "$LOG_FILE"
        else
            git pull --ff-only origin main 2>/dev/null || git pull --ff-only origin master 2>/dev/null || echo "  Pull failed (non-fast-forward or branch mismatch)" | tee -a "$LOG_FILE"
            echo "  Updated to $(git rev-parse --short HEAD)" | tee -a "$LOG_FILE"
        fi
    else
        echo "SKIP: $repo_name (not a git repository)" | tee -a "$LOG_FILE"
    fi
}

# Update all repos
for repo in "$REPO_DIR"/*/; do
    repo_name=$(basename "$repo")
    update_repo "$repo_name"
done

echo ""
echo "Update complete at $(date '+%Y-%m-%d %H:%M:%S')" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"
