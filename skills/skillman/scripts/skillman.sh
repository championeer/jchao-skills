#!/usr/bin/env bash
# skillman —— 个人 skill 库 ~/.skill-library 的全生命周期管家。
# 封装 bin/skill-link.sh，借鉴 _inventory/inventory.py 与 skill-library-manager 的模式。
# 管辖：repos/（git 第三方仓）+ skills/（全局曝光）+ 各项目 .claude/skills 接入 + 归档区。
# 不碰 /Volumes/Extreme-Pro/MedClaw_SkillLibrary（那是 skill-library-manager 的地盘）。
#
# 用法: skillman.sh <命令> [参数]
#   status                      全库概览（仓/全局/断链/归档数）
#   find <关键词>               搜 repos+全局+自建库(self/) 的名称+SKILL.md 描述，给 near-neighbor 提示
#   link <repo>/<skill>|self/<skill> [项目|--global]  接入项目或全局曝光（封装 skill-link.sh，自验）
#   audit [项目]                给项目→列接入清单逐项验链；不给→全库扫断链
#   archive <名称> [--force]    归档 repo/全局 skill（移到 _archive，不删）；有依赖需 --force
#   ingest <git-url> [名称]     git clone 进 repos/，完成后提示可 link
set -euo pipefail

LIB="$HOME/.skill-library"
REPOS="$LIB/repos"
GLOBAL="$LIB/skills"
CGLOBAL="$HOME/.claude/skills"   # Claude Code 全局发现点（--global 落点、自建直挂全局曝光）
SELF="${JCHAO_SKILLS_DIR:-/Users/qianli/0-WORKSPACE/60-Tools/JChao_Skills/skills}"   # 自建库（self/ 源；与 skill-link.sh 同口径，可 JCHAO_SKILLS_DIR 覆盖）
LINK="$LIB/bin/skill-link.sh"
SCAN_DIRS=("$GLOBAL" "$HOME/.agents/skills" "$HOME/.claude/skills")

die(){ echo "✗ $*" >&2; exit 1; }
[ -d "$LIB" ] || die "未找到个人库 $LIB"

# 从 SKILL.md 提取 frontmatter 单行字段
field_of(){ awk -v k="^$2:" '$0 ~ k {sub("^"$2":[[:space:]]*","");print;exit}' "$1" 2>/dev/null; }
desc_of(){ awk '/^description:/{sub(/^description:[[:space:]]*/,"");print;exit}' "$1" 2>/dev/null; }
name_of(){ awk '/^name:/{sub(/^name:[[:space:]]*/,"");print;exit}' "$1" 2>/dev/null; }

cmd_status(){
  echo "== ~/.skill-library 概览 =="
  local nrepo nglobal ndangle l d
  nrepo=$(find "$REPOS" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  nglobal=$(find "$GLOBAL" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')
  ndangle=0
  for d in "${SCAN_DIRS[@]}"; do
    [ -d "$d" ] || continue
    while IFS= read -r l; do [ -e "$l" ] || ndangle=$((ndangle+1)); done \
      < <(find "$d" -maxdepth 1 -type l 2>/dev/null)
  done
  echo "repos 第三方仓 : $nrepo"
  echo "skills 全局条目: $nglobal"
  echo "失效软链(断链): $ndangle"
  echo "归档目录       : $(find "$LIB" -maxdepth 1 -type d -name '_archive*' -exec basename {} \; 2>/dev/null | tr '\n' ' ')"
  echo ""
  echo "-- repos 明细（仓 → 含 SKILL.md 数）--"
  for r in "$REPOS"/*/; do
    [ -d "$r" ] || continue
    printf "  %-24s %s skills\n" "$(basename "$r")" "$(find "$r" -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')"
  done
}

cmd_find(){
  local kw="${1:?用法: skillman.sh find <关键词>}"
  echo "== 搜索 '$kw'（repos + 全局 + 自建 self/）=="
  local hits=0 f dir desc name rel
  while IFS= read -r f; do
    dir=$(dirname "$f"); desc=$(desc_of "$f"); name=$(name_of "$f")
    if printf '%s %s %s' "$f" "${name:-}" "${desc:-}" | grep -iqF -- "$kw"; then
      case "$dir" in
        "$SELF"/*) rel="self/$(basename "$dir")" ;;   # 自建库 → 直接给可用的 self/ spec
        *)         rel=${dir#"$LIB"/} ;;              # repos/… 或 skills/…（全局）
      esac
      hits=$((hits+1))
      printf "• %s\n    %s\n" "$rel" "${desc:0:140}"
    fi
  done < <(
    find -L "$REPOS" "$GLOBAL" -name SKILL.md -not -path '*/node_modules/*' 2>/dev/null
    # 自建库只取顶层 <skill>/SKILL.md（-maxdepth 2），避免 examples/tests 内嵌套 SKILL.md 误报成 self/<内层名>
    if [ -d "$SELF" ]; then
      find -L "$SELF" -maxdepth 2 -name SKILL.md 2>/dev/null
    fi
  )
  echo ""
  if [ "$hits" -gt 0 ]; then
    echo "→ 命中 $hits 个。接入: skillman.sh link <仓名>/<skill> | self/<skill>  [项目|--global]"
    echo "→ near-neighbor 纪律：造新 skill 前先确认以上近邻是否已够用。"
  else
    echo "→ 无命中。确属空白且会重复使用，才考虑用 yao-meta-skill 新建。"
  fi
}

cmd_link(){
  local spec="${1:?用法: skillman.sh link <repo>/<skill>|self/<skill> [项目|--global]}"
  shift || true
  [ -x "$LINK" ] || die "缺少可执行的 $LINK"
  # 解析目标：--global → ~/.claude/skills（全局曝光）；否则项目（默认 cwd）
  local proj="$PWD" global=0 a
  for a in "$@"; do
    case "$a" in
      --global) global=1 ;;
      *)        proj="$a" ;;
    esac
  done
  "$LINK" "$spec" "$@"
  # 自验（呼应教训：接入后必逐项核对，不凭"命令跑了"报成功）
  local skill="${spec#*/}" dstdir
  if [ "$global" -eq 1 ]; then dstdir="$HOME/.claude/skills"; else dstdir="$proj/.claude/skills"; fi
  local dst="$dstdir/$skill"
  if [ -L "$dst" ] && [ -f "$dst/SKILL.md" ]; then
    echo "✓ 验证通过: $dst -> $(readlink "$dst")"
  else
    die "验证失败: $dst 不是有效软链或缺 SKILL.md"
  fi
}

cmd_audit(){
  local proj="${1:-}"
  if [ -n "$proj" ]; then
    local sk="$proj/.claude/skills"
    [ -d "$sk" ] || die "项目无 .claude/skills: $sk"
    echo "== 审计项目接入: $sk =="
    local n=0 bad=0 e base
    for e in "$sk"/*; do
      [ -e "$e" ] || [ -L "$e" ] || continue
      n=$((n+1)); base=$(basename "$e")
      if [ -L "$e" ]; then
        if [ -f "$e/SKILL.md" ]; then
          printf "  ✓ %-28s -> %s\n" "$base" "$(readlink "$e")"
        else
          printf "  ✗ %-28s [断链或缺SKILL.md] -> %s\n" "$base" "$(readlink "$e")"; bad=$((bad+1))
        fi
      else
        printf "  ○ %-28s [本地目录,非软链]\n" "$base"
      fi
    done
    echo "—— 共 $n 项，问题 $bad 项 ——"
  else
    echo "== 全库健康扫描（断链）=="
    local total=0 d l
    for d in "${SCAN_DIRS[@]}"; do
      [ -d "$d" ] || continue
      while IFS= read -r l; do
        [ -e "$l" ] || { printf "  ✗ DANGLING %s -> %s\n" "${l/#$HOME/~}" "$(readlink "$l")"; total=$((total+1)); }
      done < <(find "$d" -maxdepth 1 -type l 2>/dev/null)
    done
    echo "—— 断链合计 $total ——"
    [ "$total" -eq 0 ] && echo "  （无断链，库健康）"
  fi
}

cmd_archive(){
  local name="${1:?用法: skillman.sh archive <名称> [--force]}"
  local force="${2:-}"
  local target=""
  if   [ -e "$REPOS/$name" ]  || [ -L "$REPOS/$name" ];  then target="$REPOS/$name"
  elif [ -e "$GLOBAL/$name" ] || [ -L "$GLOBAL/$name" ]; then target="$GLOBAL/$name"
  elif [ -L "$CGLOBAL/$name" ]; then target="$CGLOBAL/$name"   # ~/.claude/skills 软链=全局曝光指针，仅解除曝光（不碰实体目录如 gstack 子 skill）
  else die "未找到 ${name}（repos/、skills/、~/.claude/skills 均无）"; fi

  # 全局软链：解除曝光即可，本体不动
  if [ -L "$target" ]; then
    local pointee; pointee=$(readlink "$target")
    rm -f "$target"
    echo "✓ 已解除全局曝光（删软链）: $name"
    echo "  本体未动，仍在: $pointee"
    return 0
  fi

  # 真实目录/仓：先查依赖（指向它的软链），再 mv 归档
  echo "检查依赖（指向 $name 的软链）..."
  local deps=0 d l
  for d in "${SCAN_DIRS[@]}"; do
    [ -d "$d" ] || continue
    while IFS= read -r l; do
      case "$(readlink "$l")" in "$target"|"$target"/*) printf "  依赖: %s\n" "${l/#$HOME/~}"; deps=$((deps+1));; esac
    done < <(find "$d" -maxdepth 1 -type l 2>/dev/null)
  done
  if [ "$deps" -gt 0 ] && [ "$force" != "--force" ]; then
    die "发现 $deps 个依赖软链（归档会断链）。确认仍归档请加 --force。注：项目级 .claude/skills 依赖此处扫不到，请先 audit。"
  fi
  local arch="$LIB/_archive-$(date +%Y-%m-%d)"
  mkdir -p "$arch"
  mv "$target" "$arch/$name"
  echo "✓ 已归档（移动，未删除）: $name -> $arch/$name"
  [ "$deps" -gt 0 ] && echo "  ⚠ 上述 $deps 个软链现已断链，请 audit 后清理。"
}

cmd_ingest(){
  local url="${1:?用法: skillman.sh ingest <git-url> [名称]}"
  local name="${2:-}"
  [ -n "$name" ] || { name=$(basename "$url"); name=${name%.git}; }
  local dst="$REPOS/$name"
  { [ -e "$dst" ] || [ -L "$dst" ]; } && die "已存在: ${dst}（换名称或先 archive 旧的）"
  echo "git clone $url -> $dst"
  git clone "$url" "$dst"
  # 轻量 provenance（不动 .skill-lock.json，来源以 git remote 为准）
  local log="$LIB/_inventory/ingested.log"
  mkdir -p "$(dirname "$log")"
  printf '%s\t%s\t%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$name" "$url" >> "$log"
  echo "✓ 已摄入: $name"
  echo "-- 仓内可接入的 skill --"
  find "$dst" -name SKILL.md -not -path '*/node_modules/*' 2>/dev/null | while IFS= read -r f; do
    printf "  %-40s (link: %s/%s)\n" "${f#$dst/}" "$name" "$(basename "$(dirname "$f")")"
  done
  echo "→ 接入: skillman.sh link $name/<skill名> [项目]"
}

sub="${1:-}"; shift || true
case "$sub" in
  status)  cmd_status "$@";;
  find)    cmd_find "$@";;
  link)    cmd_link "$@";;
  audit)   cmd_audit "$@";;
  archive) cmd_archive "$@";;
  ingest)  cmd_ingest "$@";;
  ""|-h|--help|help) sed -n '2,16p' "$0";;
  *) die "未知命令: ${sub}（status|find|link|audit|archive|ingest）";;
esac
