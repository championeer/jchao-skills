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
#   update                      定期更新全部 repos/（--ff-only；dirty 跳过；audit 断链；
#                               日志 _inventory/update-log.md；异常写 .update-attention）
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

cmd_update(){
  # 定期更新 repos/ 下全部第三方仓（launchd 每周触发，也可手动跑）。
  # 纪律：只 --ff-only（拒绝自动 merge）；dirty 仓跳过不覆盖；结果倒序落盘可回溯；
  #       任何异常（跳过/失败/断链）写 flag 文件，由 SessionStart 软提醒接力。
  local logf="$LIB/_inventory/update-log.md"
  local flag="$LIB/.update-attention"
  mkdir -p "$(dirname "$logf")"
  local updated=0 skipped=0 failed=0 dangling=0
  local report="" r name old new out changed
  echo "== skill 库定期更新 $(date '+%Y-%m-%d %H:%M') =="
  for r in "$REPOS"/*/; do
    [ -d "$r/.git" ] || continue
    name=$(basename "$r")
    if [ -n "$(git -C "$r" status --porcelain 2>/dev/null)" ]; then
      report="${report}- ⚠ ${name}: 本地有改动，跳过 pull（处理后可手动重跑）
"
      skipped=$((skipped+1)); continue
    fi
    old=$(git -C "$r" rev-parse --short HEAD 2>/dev/null) || { failed=$((failed+1)); continue; }
    # GitHub SSH 偶发抖动是常态，失败后隔 2s 重试一次再定性
    # mode: 0=失败 1=ff 正常 2=分叉 rebase（本地对第三方 skill 有定制 commit 时的常态）
    local mode=1
    out=$(git -C "$r" pull --ff-only 2>&1) \
      || { sleep 2; out=$(git -C "$r" pull --ff-only 2>&1) || mode=0; }
    if [ "$mode" -eq 0 ] && printf '%s' "$out" | grep -qi 'diverg'; then
      # 本地领先 commit 与上游分叉 → rebase 重放本地定制；冲突则还原上报，绝不留半截状态
      if out=$(git -C "$r" pull --rebase 2>&1); then
        mode=2
      else
        git -C "$r" rebase --abort >/dev/null 2>&1 || true
      fi
    fi
    if [ "$mode" -eq 0 ]; then
      report="${report}- ✗ ${name}: pull 失败 — $(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200 ; true)
"
      failed=$((failed+1)); continue
    fi
    new=$(git -C "$r" rev-parse --short HEAD)
    if [ "$old" != "$new" ]; then
      # 变更涉及的顶级目录（近似 skill 粒度），供快速判断影响面
      changed=$(git -C "$r" diff --name-only "$old" "$new" 2>/dev/null \
        | cut -d/ -f1 | sort -u | head -8 | tr '\n' ' ')
      if [ "$mode" -eq 2 ]; then
        report="${report}- ✓ ${name}: ${old}..${new}（rebase 重放本地定制；变更: ${changed:-?}）
"
      else
        report="${report}- ✓ ${name}: ${old}..${new}（变更: ${changed:-?}）
"
      fi
      updated=$((updated+1))
    fi
  done
  # —— 第二段：Claude Code plugins（superpowers 等走 marketplace 机制，repos/ 覆盖不到）——
  # launchd 环境 PATH 干净，claude CLI 须显式探测；找不到记异常不静默
  local CLAUDE_BIN="" c
  for c in "$HOME/.local/bin/claude" /opt/homebrew/bin/claude /usr/local/bin/claude; do
    [ -x "$c" ] && { CLAUDE_BIN="$c"; break; }
  done
  local p_updated=0 p_failed=0 p_total=0 pid pout
  if [ -n "$CLAUDE_BIN" ]; then
    echo "-- plugins 更新中（marketplace 刷新 + 逐个检查，约数分钟）--"
    "$CLAUDE_BIN" plugin marketplace update >/dev/null 2>&1 || {
      report="${report}- ⚠ plugin marketplace 刷新失败（继续用旧索引检查）
"
    }
    while IFS= read -r pid; do
      p_total=$((p_total+1))
      if pout=$("$CLAUDE_BIN" plugin update "$pid" 2>&1); then
        if ! printf '%s' "$pout" | grep -q 'already at the latest'; then
          report="${report}- ✓ plugin ${pid}: $(printf '%s' "$pout" | tail -1 | cut -c1-120 ; true)
"
          p_updated=$((p_updated+1))
        fi
      else
        report="${report}- ✗ plugin ${pid}: 更新失败 — $(printf '%s' "$pout" | tr '\n' ' ' | cut -c1-160 ; true)
"
        p_failed=$((p_failed+1))
      fi
    done < <("$CLAUDE_BIN" plugin list --json 2>/dev/null \
      | /usr/bin/python3 -c 'import json,sys; [print(p["id"]) for p in json.load(sys.stdin) if p.get("enabled")]' 2>/dev/null)
    if [ "$p_total" -eq 0 ]; then
      report="${report}- ⚠ plugin 清单读取失败（claude plugin list --json 无输出）
"
      p_failed=$((p_failed+1))
    fi
    [ "$p_updated" -gt 0 ] && report="${report}- ℹ plugin 有更新，需重启 Claude Code 会话生效
"
  else
    report="${report}- ⚠ 未找到 claude CLI，跳过 plugins 更新
"
    p_failed=$((p_failed+1))
  fi

  # pull 后全库断链审计（上游改名/删目录的兜底；audit 有断链时返回非零，勿被 set -e 杀掉）
  local audit_out=""
  audit_out=$(cmd_audit 2>&1) || true
  # 注意：合计行是"—— 断链合计 N ——"，$NF 抓到的是全角破折号，须剥掉非数字
  dangling=$(printf '%s\n' "$audit_out" | awk '/断链合计/{gsub(/[^0-9]/,""); print; exit}')
  dangling="${dangling:-0}"
  if [ "$dangling" != "0" ]; then
    report="${report}$(printf '%s\n' "$audit_out" | grep 'DANGLING' | sed 's/^/- ✗ 断链: /' ; true)
"
  fi

  local summary="repos 更新 ${updated}/跳过 ${skipped}/失败 ${failed} · plugins 更新 ${p_updated}/失败 ${p_failed} · 断链 ${dangling}"
  [ -n "$report" ] || report="- （全部已是最新，无变化）
"
  # 日志倒序追加（新条目在顶部）
  local tmp="$logf.tmp.$$"
  {
    printf '## %s — %s\n%s\n' "$(date '+%Y-%m-%d %H:%M')" "$summary" "$report"
    if [ -f "$logf" ]; then cat "$logf"; fi   # 勿写成 [ ] && cat：首跑无旧日志时尾命令返 1 会被 set -e 杀
  } > "$tmp" && mv "$tmp" "$logf"

  printf '%s\n%s' "$summary" "$report"
  echo "日志: ${logf}"
  # 异常 → flag（SessionStart 软提醒读它）；正常 → 清 flag
  if [ "$skipped" != "0" ] || [ "$failed" != "0" ] || [ "$dangling" != "0" ] || [ "$p_failed" != "0" ]; then
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M')" "$summary" > "$flag"
    echo "⚠ 存在异常，已写提醒标记: ${flag}"
  else
    /bin/rm -f "$flag"
  fi
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
  update)  cmd_update "$@";;
  ""|-h|--help|help) sed -n '2,18p' "$0";;
  *) die "未知命令: ${sub}（status|find|link|audit|archive|ingest|update）";;
esac
