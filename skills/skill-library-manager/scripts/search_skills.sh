#!/bin/bash
# MedClaw Skill Library — 技能搜索工具
# 用法:
#   search_skills.sh <关键词>              # 按名称/描述搜索
#   search_skills.sh --repo <仓库名>       # 按来源仓库筛选
#   search_skills.sh --cat <分类名>        # 按分类筛选
#   search_skills.sh --list-repos          # 列出所有仓库
#   search_skills.sh --list-cats           # 列出所有分类
#   search_skills.sh --stats               # 统计概览

LIB="${MEDCLAW_SKILL_LIBRARY:-/Volumes/Extreme-Pro/MedClaw_SkillLibrary}"
CATALOG="$LIB/FULL_CATALOG.json"

if [ ! -f "$CATALOG" ]; then
    echo "Error: Catalog not found at $CATALOG"
    exit 1
fi

case "$1" in
    --list-repos)
        echo "=== 源仓库列表 ==="
        python3 -c "
import json
with open('$CATALOG') as f: data = json.load(f)
repos = {}
for s in data: repos[s['repo']] = repos.get(s['repo'], 0) + 1
for r, c in sorted(repos.items(), key=lambda x: -x[1]):
    print(f'  {r}: {c} skills')
"
        ;;
    --list-cats)
        echo "=== 分类列表 ==="
        python3 -c "
import json
with open('$CATALOG') as f: data = json.load(f)
cats = {}
for s in data: cats[s['category']] = cats.get(s['category'], 0) + 1
for c, n in sorted(cats.items(), key=lambda x: -x[1]):
    print(f'  {c}: {n} skills')
"
        ;;
    --stats)
        echo "=== 技能库统计 ==="
        python3 -c "
import json
with open('$CATALOG') as f: data = json.load(f)
total = len(data)
with_md = sum(1 for s in data if s['has_skill_md'])
repos = len(set(s['repo'] for s in data))
cats = len(set(s['category'] for s in data))
print(f'  总Skills数: {total}')
print(f'  有SKILL.md: {with_md}')
print(f'  源仓库数: {repos}')
print(f'  分类数: {cats}')
"
        ;;
    --repo)
        shift
        REPO="$1"
        python3 -c "
import json
with open('$CATALOG') as f: data = json.load(f)
results = [s for s in data if '$REPO'.lower() in s['repo'].lower()]
print(f'=== 仓库 \"$REPO\" 匹配 {len(results)} 个Skills ===')
for s in results:
    desc = s['description'][:80] + '...' if len(s['description']) > 80 else s['description']
    print(f\"  {s['skill_id']:45s} {desc}\")
"
        ;;
    --cat)
        shift
        CAT="$1"
        python3 -c "
import json
with open('$CATALOG') as f: data = json.load(f)
results = [s for s in data if '$CAT'.lower() in s['category'].lower()]
print(f'=== 分类 \"$CAT\" 匹配 {len(results)} 个Skills ===')
for s in results:
    desc = s['description'][:80] + '...' if len(s['description']) > 80 else s['description']
    print(f\"  {s['skill_id']:45s} [{s['repo'][:20]}] {desc}\")
"
        ;;
    --help|-h)
        echo "MedClaw Skill Library 搜索工具"
        echo ""
        echo "用法:"
        echo "  $0 <关键词>              按名称/描述模糊搜索"
        echo "  $0 --repo <仓库名>       按来源仓库筛选"
        echo "  $0 --cat <分类名>        按分类筛选"
        echo "  $0 --list-repos          列出所有仓库及数量"
        echo "  $0 --list-cats           列出所有分类及数量"
        echo "  $0 --stats               统计概览"
        echo "  $0 --help                显示帮助"
        ;;
    *)
        KEYWORD="$1"
        if [ -z "$KEYWORD" ]; then
            echo "用法: $0 <关键词> 或 $0 --help"
            exit 1
        fi
        python3 -c "
import json
with open('$CATALOG') as f: data = json.load(f)
kw = '$KEYWORD'.lower()
results = [s for s in data if kw in s['skill_id'].lower() or kw in s['name'].lower() or kw in s['description'].lower() or kw in s['category'].lower()]
print(f'=== 搜索 \"$KEYWORD\" → {len(results)} 个结果 ===')
print()
for s in results:
    desc = s['description'][:90] + '...' if len(s['description']) > 90 else s['description']
    print(f\"  {s['skill_id']}\")
    print(f\"    来源: {s['repo']}  |  分类: {s['category']}\")
    print(f\"    路径: {s['local_path']}\")
    if desc:
        print(f\"    简介: {desc}\")
    print()
"
        ;;
esac
