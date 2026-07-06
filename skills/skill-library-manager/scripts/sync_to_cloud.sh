#!/bin/bash
# MedClaw Skill Library — 同步到 Cloudflare
# 用法: CLOUDFLARE_API_TOKEN=xxx bash <skill-dir>/scripts/sync_to_cloud.sh
# 将本地技能库同步到 Cloudflare D1 + R2（每个skill的全部文件）

set -e

LIB="${MEDCLAW_SKILL_LIBRARY:-/Volumes/Extreme-Pro/MedClaw_SkillLibrary}"
DB_NAME="medclaw-skills"
TMPDIR="$LIB/worker/_sync_tmp"

# Check prerequisites
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
  echo "Error: CLOUDFLARE_API_TOKEN not set"
  exit 1
fi

if ! command -v wrangler &> /dev/null; then
  echo "Error: wrangler CLI not found. Install with: npm install -g wrangler"
  exit 1
fi

mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

echo "=== MedClaw Skill Library → Cloudflare Sync ==="
echo ""

# ─── Phase 1: D1 Sync ───
echo "[1/2] Syncing catalog to D1..."

MEDCLAW_LIB="$LIB" MEDCLAW_TMPDIR="$TMPDIR" python3 << 'PYEOF'
import json, os
from datetime import datetime, timezone

lib = os.environ["MEDCLAW_LIB"]
tmpdir = os.environ["MEDCLAW_TMPDIR"]

with open(os.path.join(lib, "FULL_CATALOG.json"), "r", encoding="utf-8") as f:
    catalog = json.load(f)

lines = ["DELETE FROM skills;"]

chunk_size = 100
for i in range(0, len(catalog), chunk_size):
    chunk = catalog[i:i+chunk_size]
    values = []
    for s in chunk:
        repo = s["repo"].replace("'", "''")
        sid = s["skill_id"].replace("'", "''")
        name = s["name"].replace("'", "''")
        desc = s.get("description", "").replace("'", "''")
        cat = s["category"].replace("'", "''")
        has_md = 1 if s.get("has_skill_md", False) else 0
        values.append(f"('{repo}','{sid}','{name}','{desc}','{cat}',{has_md})")
    lines.append(f"INSERT INTO skills (repo, skill_id, name, description, category, has_skill_md) VALUES {','.join(values)};")

now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
lines.append(f"INSERT OR REPLACE INTO sync_meta (key, value) VALUES ('last_synced', '{now}');")

sql_path = os.path.join(tmpdir, "sync.sql")
with open(sql_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines))

print(f"  Generated SQL: {len(catalog)} skills in {(len(catalog) + chunk_size - 1) // chunk_size} batches")
PYEOF

wrangler d1 execute "$DB_NAME" --file="$TMPDIR/sync.sql" --remote 2>&1 | tail -3
echo "  D1 sync complete."
echo ""

# ─── Phase 2: R2 Sync ───
echo "[2/2] Syncing ALL skill files to R2..."

MEDCLAW_LIB="$LIB" python3 << 'PYEOF'
import json, os, subprocess, sys
from concurrent.futures import ThreadPoolExecutor, as_completed

lib = os.environ["MEDCLAW_LIB"]
bucket = "medclaw-skills"

def upload_one(local_path, r2_key):
    try:
        file_size = os.path.getsize(local_path)
        timeout = 120 if file_size > 1048576 else 60  # 2min for >1MB files
        result = subprocess.run(
            ["wrangler", "r2", "object", "put", f"{bucket}/{r2_key}", f"--file={local_path}", "--remote"],
            capture_output=True, text=True, timeout=timeout,
            env={**os.environ, "CLOUDFLARE_API_TOKEN": os.environ["CLOUDFLARE_API_TOKEN"]}
        )
        return (r2_key, result.returncode == 0)
    except:
        return (r2_key, False)

# Build upload list: scan ALL files in each skill directory
with open(os.path.join(lib, "FULL_CATALOG.json"), "r", encoding="utf-8") as f:
    catalog = json.load(f)

uploads = []
skip_names = {'.DS_Store', '.git', '__pycache__'}

for s in catalog:
    skill_dir = os.path.join(lib, s["local_path"])
    if not os.path.isdir(skill_dir):
        continue
    repo = s["repo"]
    sid = s["skill_id"]
    for root, dirs, files in os.walk(skill_dir):
        dirs[:] = [d for d in dirs if d not in skip_names]
        for fname in files:
            if fname in skip_names:
                continue
            local = os.path.join(root, fname)
            rel = os.path.relpath(local, skill_dir)
            r2_key = f"skills/{repo}/{sid}/{rel}"
            uploads.append((local, r2_key))

# Add deployment docs
deploy_dir = os.path.join(lib, "deployments")
if os.path.isdir(deploy_dir):
    for fname in os.listdir(deploy_dir):
        if fname.endswith(".md"):
            uploads.append((os.path.join(deploy_dir, fname), f"deployments/{fname}"))

total_size = sum(os.path.getsize(l) for l, _ in uploads if os.path.exists(l))
print(f"  Found {len(uploads)} files ({total_size / 1048576:.1f} MB)")
print(f"  Uploading with 10 parallel workers...")

success = 0
fail = 0
failed_keys = []

with ThreadPoolExecutor(max_workers=10) as pool:
    futures = {pool.submit(upload_one, local, key): key for local, key in uploads}
    for i, future in enumerate(as_completed(futures), 1):
        key, ok = future.result()
        if ok:
            success += 1
        else:
            fail += 1
            failed_keys.append(key)
        if i % 200 == 0 or i == len(uploads):
            print(f"  Progress: {i}/{len(uploads)} (ok:{success} fail:{fail})")

if failed_keys:
    print(f"\n  Failed uploads ({fail}):")
    for k in failed_keys[:20]:
        print(f"    - {k}")
    if len(failed_keys) > 20:
        print(f"    ... and {len(failed_keys) - 20} more")

print(f"\n  R2 sync complete: {success} uploaded, {fail} failed out of {len(uploads)}")
PYEOF

echo ""
echo "=== Sync complete ==="
