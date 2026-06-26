#!/usr/bin/env bash
# 本体（受版本控制）：JChao_Skills/skills/skillman/scripts/skill-link.sh
# 活动路径 ~/.skill-library/bin/skill-link.sh 是指向本文件的软链——改这里即生效，零漂移。
# 把一个 skill 软链进某项目的 .claude/skills，或软链到全局 ~/.claude/skills。
# 用法: skill-link.sh <repo>/<skill> | self/<skill>   [项目路径 | --global]
#   源：<repo>/<skill> = ~/.skill-library/repos 内第三方仓；self/<skill> = 自建库
#       （JChao_Skills/skills，可用 JCHAO_SKILLS_DIR 覆盖）
#   目标：默认当前目录的 .claude/skills；给 --global 则软链到 ~/.claude/skills（全局曝光）
#   例: skill-link.sh baoyu-skills/baoyu-comic ~/0-WORKSPACE/30-QingYa
#       skill-link.sh mattpocock-skills/ask-matt     (二级分类仓，自动探测)
#       skill-link.sh yao-meta-skill/yao-meta-skill  (单 skill 仓，链仓根)
#       skill-link.sh self/wushixu --global          (自建 skill → 全局曝光)
set -euo pipefail
spec="${1:?用法: skill-link.sh <repo>/<skill> | self/<skill>  [项目路径 | --global]}"
shift
proj="$PWD"; global=0
while [ $# -gt 0 ]; do
  case "$1" in
    --global) global=1 ;;
    *)        proj="$1" ;;
  esac
  shift
done
repo="${spec%%/*}"; skill="${spec#*/}"
LIB="$HOME/.skill-library/repos"
SELF="${JCHAO_SKILLS_DIR:-/Users/qianli/0-WORKSPACE/60-Tools/JChao_Skills/skills}"

src=""
if [ "${repo}" = "self" ]; then
  # 自建源：本体在 JChao_Skills/skills/<skill>（可 JCHAO_SKILLS_DIR 覆盖）
  if [ -d "$SELF/$skill" ] && [ -f "$SELF/$skill/SKILL.md" ]; then src="$SELF/$skill"; fi
  : "${src:?未找到自建 skill ${skill}（查 ${SELF}/${skill}/）}"
else
  # 候选探测：① 一级 skills/<skill>  ② 仓根直挂 <skill>  ③ 二级 skills/<分类>/<skill>
  for cand in "$LIB/$repo/skills/$skill" "$LIB/$repo/$skill" "$LIB/$repo"/skills/*/"$skill"; do
    if [ -d "$cand" ] && [ -f "$cand/SKILL.md" ]; then src="$cand"; break; fi
  done
  # ④ 单 skill 仓：仓根即 skill（skill 名 == repo 名且仓根有 SKILL.md）
  if [ -z "$src" ] && [ "$skill" = "$repo" ] && [ -f "$LIB/$repo/SKILL.md" ]; then
    src="$LIB/$repo"
  fi
  : "${src:?未找到 ${repo} 内的 ${skill} （查 ${LIB}/${repo}/）}"
fi

if [ "$global" -eq 1 ]; then dstdir="$HOME/.claude/skills"; else dstdir="$proj/.claude/skills"; fi
dst="$dstdir/$skill"
mkdir -p "$dstdir"
if [ -e "$dst" ] || [ -L "$dst" ]; then echo "已存在: $dst"; exit 0; fi
ln -s "$src" "$dst"
echo "linked: $dst -> $src"
