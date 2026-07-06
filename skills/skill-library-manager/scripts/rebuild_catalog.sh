#!/bin/bash
# MedClaw Skill Library — 重建全量目录
# 用法: bash <skill-dir>/scripts/rebuild_catalog.sh
# 扫描repos/下所有仓库，重新生成 FULL_CATALOG.json 和 FULL_CATALOG.md

set -e

LIB="${MEDCLAW_SKILL_LIBRARY:-/Volumes/Extreme-Pro/MedClaw_SkillLibrary}"

echo "Scanning all repos in $LIB ..."

MEDCLAW_LIB="$LIB" python3 << 'PYEOF'
import os, json, re
from collections import defaultdict
from datetime import date

lib = os.environ["MEDCLAW_LIB"]
base = os.path.join(lib, "repos")
catalog = []

def extract_frontmatter(skill_md_path):
    try:
        with open(skill_md_path, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read(3000)
        fm_match = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
        if not fm_match:
            return None, None
        fm = fm_match.group(1)
        name_match = re.search(r'^name:\s*["\']?(.+?)["\']?\s*$', fm, re.MULTILINE)
        name = name_match.group(1).strip() if name_match else None
        desc_match = re.search(r'^description:\s*["\'](.+?)["\']', fm, re.MULTILINE | re.DOTALL)
        if not desc_match:
            desc_match = re.search(r'^description:\s*(.+?)$', fm, re.MULTILINE)
        desc = desc_match.group(1).strip()[:200] if desc_match else None
        return name, desc
    except:
        return None, None

def scan_skills_dir(skills_path, repo_name, category_default="uncategorized", category_map=None):
    if not os.path.isdir(skills_path):
        return
    for d in sorted(os.listdir(skills_path)):
        skill_dir = os.path.join(skills_path, d)
        if not os.path.isdir(skill_dir) or d.startswith('.'):
            continue
        skill_md = os.path.join(skill_dir, "SKILL.md")
        exists = os.path.exists(skill_md)
        name, desc = extract_frontmatter(skill_md) if exists else (None, None)
        cat = category_map.get(d, category_default) if category_map else category_default
        rel_path = os.path.relpath(skill_dir, base)
        catalog.append({
            "skill_id": d,
            "name": name or d,
            "description": desc or "",
            "repo": repo_name,
            "category": cat,
            "has_skill_md": exists,
            "local_path": f"repos/{rel_path}"
        })

# Load marketplace categories for Medical-Skills
mp_path = os.path.join(base, "OpenClaw-Medical-Skills/.claude-plugin/marketplace.json")
med_cat_map = {}
if os.path.exists(mp_path):
    with open(mp_path) as f:
        mp = json.load(f)
    for plugin in mp['plugins']:
        for s in plugin['skills']:
            sname = s.replace('./skills/', '').replace('/SKILL.md', '')
            med_cat_map[sname] = plugin['name']

# Scan all repos
scan_skills_dir(os.path.join(base, "OpenClaw-Medical-Skills/skills"), "OpenClaw-Medical-Skills", category_map=med_cat_map)
scan_skills_dir(os.path.join(base, "openclaw-master-skills/skills"), "openclaw-master-skills", "clawhub-official")
scan_skills_dir(os.path.join(base, "claude-code-skills/skills"), "claude-code-skills", "claude-community")
scan_skills_dir(os.path.join(base, "chineseresearchlatex/skills"), "chineseresearchlatex", "chinese-research")
scan_skills_dir(os.path.join(base, "openclaw-skills-security/skills"), "openclaw-skills-security", "security")

# Special: academic-research-skills (flat structure)
ars_path = os.path.join(base, "academic-research-skills")
for d in sorted(os.listdir(ars_path)):
    skill_dir = os.path.join(ars_path, d)
    skill_md = os.path.join(skill_dir, "SKILL.md")
    if not os.path.isdir(skill_dir) or d.startswith('.') or d in ('examples', 'shared'):
        continue
    exists = os.path.exists(skill_md)
    name, desc = extract_frontmatter(skill_md) if exists else (None, None)
    catalog.append({
        "skill_id": d, "name": name or d, "description": desc or "",
        "repo": "academic-research-skills", "category": "academic-research",
        "has_skill_md": exists, "local_path": f"repos/academic-research-skills/{d}"
    })

# Special: claude-skills (flat structure)
cs_path = os.path.join(base, "claude-skills")
for d in sorted(os.listdir(cs_path)):
    skill_dir = os.path.join(cs_path, d)
    skill_md = os.path.join(skill_dir, "SKILL.md")
    if not os.path.isdir(skill_dir) or d.startswith('.'):
        continue
    exists = os.path.exists(skill_md)
    name, desc = extract_frontmatter(skill_md) if exists else (None, None)
    catalog.append({
        "skill_id": d, "name": name or d, "description": desc or "",
        "repo": "claude-skills", "category": "claude-community",
        "has_skill_md": exists, "local_path": f"repos/claude-skills/{d}"
    })

# clawhub-installed (flat structure, manually downloaded skills)
scan_skills_dir(os.path.join(base, "clawhub-installed"), "clawhub-installed", "clawhub-manual")

# LabClaw (nested: skills/<category>/<skill>/SKILL.md)
labclaw_path = os.path.join(base, "LabClaw/skills")
labclaw_cat_map = {
    "bio": "labclaw-bioinformatics",
    "general": "labclaw-general",
    "literature": "labclaw-literature",
    "med": "labclaw-medical",
    "pharma": "labclaw-pharma",
    "vision": "labclaw-vision",
}
if os.path.isdir(labclaw_path):
    for cat_dir in sorted(os.listdir(labclaw_path)):
        cat_path = os.path.join(labclaw_path, cat_dir)
        if not os.path.isdir(cat_path) or cat_dir.startswith('.'):
            continue
        cat_label = labclaw_cat_map.get(cat_dir, f"labclaw-{cat_dir}")
        scan_skills_dir(cat_path, "LabClaw", cat_label)

# Special: autoresearch-skill (single skill in root)
ar_path = os.path.join(base, "autoresearch-skill")
ar_skill_md = os.path.join(ar_path, "SKILL.md")
if os.path.exists(ar_skill_md):
    name, desc = extract_frontmatter(ar_skill_md)
    catalog.append({
        "skill_id": "autoresearch-skill", "name": name or "autoresearch-skill",
        "description": desc or "",
        "repo": "autoresearch-skill", "category": "general-research",
        "has_skill_md": True, "local_path": "repos/autoresearch-skill"
    })

# Write JSON
with open(os.path.join(lib, "FULL_CATALOG.json"), 'w', encoding='utf-8') as f:
    json.dump(catalog, f, ensure_ascii=False, indent=2)

# Write Markdown
by_repo = defaultdict(lambda: defaultdict(list))
for s in catalog:
    by_repo[s['repo']][s['category']].append(s)

lines = [
    f"# MedClaw Skill Library — 全量技能目录",
    f"",
    f"> 自动生成于 {date.today()} | 共 {len(catalog)} 个Skills | {len(by_repo)}个源仓库",
    f">",
    f"> **搜索方式**: `bash scripts/search_skills.sh <关键词>` 或在本文件中Ctrl+F",
    f">",
    f"> **与项目相关的精选Skills**: 见 `SKILL_INVENTORY.md`",
    f"",
]

for repo_name in sorted(by_repo.keys()):
    cats = by_repo[repo_name]
    total = sum(len(v) for v in cats.values())
    lines.extend([f"---", f"", f"## {repo_name}（{total}个Skills）", f""])
    for cat_name in sorted(cats.keys()):
        skills = cats[cat_name]
        display_cat = cat_name.replace("-", " ").replace("_", " ").title()
        lines.extend([f"### {display_cat}（{len(skills)}）", f"", "| Skill | 简介 | SKILL.md |", "|-------|------|----------|"])
        for s in sorted(skills, key=lambda x: x['skill_id']):
            desc = s['description'][:100].replace("|", "\\|").replace("\n", " ")
            if len(s['description']) > 100: desc += "..."
            has_md = "✅" if s['has_skill_md'] else "❌"
            lines.append(f"| `{s['skill_id']}` | {desc} | {has_md} |")
        lines.append("")

with open(os.path.join(lib, "FULL_CATALOG.md"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print(f"Done: {len(catalog)} skills indexed, JSON + Markdown generated.")
PYEOF

echo "Catalog rebuilt successfully."
