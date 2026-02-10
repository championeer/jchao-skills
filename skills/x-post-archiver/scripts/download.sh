#!/usr/bin/env bash
# =============================================================================
# X Post Archiver - Download Script (v2 - batch + anti-detection)
#
# Usage:
#   bash download.sh preflight                            # Check environment
#   bash download.sh download <URL> <OUTPUT_DIR> [opts]   # Single post
#   bash download.sh batch <URL_FILE> <BASE_DIR> [opts]   # Batch download
#
# Shared Options:
#   --no-images        Skip image downloading
#   --timeout N        Browser render wait in seconds (default: 8)
#
# Batch Options:
#   --delay-min N      Min delay between requests in seconds (default: 15)
#   --delay-max N      Max delay between requests in seconds (default: 45)
#   --max-retries N    Max retries per URL on block detection (default: 2)
#   --cooldown N       Cooldown seconds after block detection (default: 120)
#   --resume           Skip URLs whose output directory already exists
# =============================================================================
set -euo pipefail

# ─── Globals ──────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLATFORM=""
DOWNLOAD_IMAGES=true
BROWSER_TIMEOUT=8
AGENT_BROWSER_CMD="npx agent-browser"

# Batch / anti-detection globals
DELAY_MIN=15
DELAY_MAX=45
MAX_RETRIES=2
COOLDOWN=120
RESUME_MODE=false
CONSECUTIVE_BLOCKS=0
BROWSER_OPEN=false

# ─── Colors (safe for non-TTY) ───────────────────────────────────────────────
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
  BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''
fi

info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
step()  { echo -e "${CYAN}[STEP]${NC} $*"; }

# ─── Platform Detection ──────────────────────────────────────────────────────
detect_platform() {
  case "$(uname -s)" in
    Darwin*)  PLATFORM="macos" ;;
    Linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        PLATFORM="wsl"
      else
        PLATFORM="linux"
      fi
      ;;
    CYGWIN*|MINGW*|MSYS*)
      PLATFORM="windows-git-bash"
      ;;
    *)
      PLATFORM="unknown"
      ;;
  esac
  echo "$PLATFORM"
}

# ─── Dependency Check ────────────────────────────────────────────────────────
check_cmd() {
  local cmd="$1"
  local name="${2:-$1}"
  local install_hint="${3:-}"
  if command -v "$cmd" &>/dev/null; then
    ok "$name found: $(command -v "$cmd")"
    return 0
  else
    error "$name NOT found"
    [ -n "$install_hint" ] && echo "    Install: $install_hint"
    return 1
  fi
}

preflight() {
  local errors=0
  echo "==========================================="
  echo " X Post Archiver - Environment Preflight"
  echo "==========================================="
  echo ""

  PLATFORM=$(detect_platform)
  info "Platform: $PLATFORM"

  if [ "$PLATFORM" = "unknown" ]; then
    error "Unsupported platform. This skill requires macOS, Linux, or WSL."
    echo ""
    echo "On Windows, install WSL:"
    echo "  1. Open PowerShell as Admin"
    echo "  2. Run: wsl --install"
    echo "  3. Restart and run this inside WSL"
    return 1
  fi

  [ "$PLATFORM" = "windows-git-bash" ] && warn "Git Bash detected. WSL is recommended."

  echo ""
  info "Checking dependencies..."
  echo ""

  case "$PLATFORM" in
    macos)     check_cmd node "Node.js" "brew install node" || ((errors++)) ;;
    linux|wsl) check_cmd node "Node.js" "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs" || ((errors++)) ;;
    *)         check_cmd node "Node.js" "Install from https://nodejs.org" || ((errors++)) ;;
  esac

  check_cmd npx "npx" "Comes with Node.js" || ((errors++))
  check_cmd curl "curl" "sudo apt-get install curl" || ((errors++))

  case "$PLATFORM" in
    macos)     check_cmd python3 "Python3" "brew install python3" || ((errors++)) ;;
    linux|wsl) check_cmd python3 "Python3" "sudo apt-get install python3" || ((errors++)) ;;
    *)         check_cmd python3 "Python3" "Install from https://python.org" || ((errors++)) ;;
  esac

  echo ""
  info "Checking agent-browser..."
  if npx agent-browser --version &>/dev/null 2>&1; then
    ok "agent-browser available via npx"
  else
    warn "agent-browser not cached yet. Will be installed on first use via npx."
  fi

  info "Checking Playwright Chromium..."
  local pw_cache=""
  case "$PLATFORM" in
    macos) pw_cache="$HOME/Library/Caches/ms-playwright" ;;
    *)     pw_cache="$HOME/.cache/ms-playwright" ;;
  esac

  if ls "$pw_cache"/chromium-*/chrome-*/chrome 2>/dev/null || \
     ls "$pw_cache"/chromium-*/chrome-mac-arm64/Google\ Chrome\ for\ Testing.app 2>/dev/null; then
    ok "Playwright Chromium found"
  else
    warn "Playwright Chromium not found. Will auto-install on first run."
    warn "To pre-install: npx playwright install chromium"
    [[ "$PLATFORM" =~ linux|wsl ]] && warn "On Linux, also run: npx playwright install-deps"
  fi

  echo ""
  echo "==========================================="
  if [ $errors -gt 0 ]; then
    error "$errors required dependency(ies) missing."
    return 1
  else
    ok "All dependencies found. Ready to archive!"
    return 0
  fi
}

# ─── Ensure Playwright ────────────────────────────────────────────────────────
ensure_playwright() {
  if ! $AGENT_BROWSER_CMD open "about:blank" &>/dev/null 2>&1; then
    info "Installing Playwright Chromium (first-time setup)..."
    npx playwright install chromium 2>&1 | tail -3
  fi
  $AGENT_BROWSER_CMD close &>/dev/null 2>&1 || true
}

# ─── Random Delay (anti-detection) ───────────────────────────────────────────
random_delay() {
  local min="${1:-$DELAY_MIN}"
  local max="${2:-$DELAY_MAX}"
  local delay

  if command -v python3 &>/dev/null; then
    delay=$(python3 -c "import random; print(random.randint($min, $max))")
  else
    delay=$(( min + RANDOM % (max - min + 1) ))
  fi

  info "Waiting ${delay}s before next request (anti-detection)..."
  sleep "$delay"
}

# ─── Block Detection ─────────────────────────────────────────────────────────
# Returns: 0 = not blocked, 1 = blocked/login wall, 2 = error page
detect_block() {
  local snapshot_file="$1"

  if [ ! -f "$snapshot_file" ]; then
    return 2
  fi

  local line_count
  line_count=$(wc -l < "$snapshot_file" | tr -d ' ')

  # Very short snapshot = likely blocked
  if [ "$line_count" -lt 15 ]; then
    warn "Snapshot too short ($line_count lines) - possible block"
    return 1
  fi

  # Check for login wall indicators (content is ONLY login prompt, no article)
  local has_article has_login_wall has_error
  has_article=$(grep -c 'article\|heading.*level=' "$snapshot_file" 2>/dev/null || echo "0")
  has_login_wall=$(grep -c 'Don.*t miss what.*happening\|Log in.*Sign up' "$snapshot_file" 2>/dev/null || echo "0")
  has_error=$(grep -c 'Something went wrong\|Try again\|This account doesn' "$snapshot_file" 2>/dev/null || echo "0")

  # If there IS article content, it's fine even if login prompt exists (X shows both)
  if [ "$has_article" -gt 3 ]; then
    return 0
  fi

  if [ "$has_login_wall" -gt 0 ] && [ "$has_article" -lt 3 ]; then
    warn "Login wall detected without article content"
    return 1
  fi

  if [ "$has_error" -gt 0 ]; then
    warn "Error page detected"
    return 2
  fi

  return 0
}

# ─── Browser Management ──────────────────────────────────────────────────────
browser_ensure_open() {
  if [ "$BROWSER_OPEN" = false ]; then
    info "Starting browser session..."
    $AGENT_BROWSER_CMD open "about:blank" &>/dev/null 2>&1
    BROWSER_OPEN=true
    sleep 1
  fi
}

browser_navigate() {
  local url="$1"
  browser_ensure_open
  $AGENT_BROWSER_CMD open "$url" 2>&1 | tail -1
}

browser_close() {
  if [ "$BROWSER_OPEN" = true ]; then
    $AGENT_BROWSER_CMD close &>/dev/null 2>&1 || true
    BROWSER_OPEN=false
  fi
}

# Cleanup on exit
trap browser_close EXIT

# ─── Fetch Oembed Metadata ───────────────────────────────────────────────────
fetch_oembed() {
  local url="$1"
  local output_file="$2"

  local oembed_url="https://publish.twitter.com/oembed?url=${url}&omit_script=true"

  info "Fetching oembed metadata..."
  local response
  response=$(curl -sL --max-time 15 "$oembed_url" 2>/dev/null || echo '{}')

  if echo "$response" | python3 -c "import sys,json; json.load(sys.stdin)" 2>/dev/null; then
    echo "$response" > "$output_file"

    local author_name author_url html_content
    author_name=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('author_name','unknown'))" 2>/dev/null || echo "unknown")
    author_url=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('author_url',''))" 2>/dev/null || echo "")
    html_content=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('html',''))" 2>/dev/null || echo "")

    ok "Author: $author_name ($author_url)"

    # Resolve t.co links
    local tco_links
    tco_links=$(echo "$html_content" | python3 -c "
import sys, re
html = sys.stdin.read()
links = re.findall(r'https://t\.co/\w+', html)
for l in links:
    print(l)
" 2>/dev/null || true)

    if [ -n "$tco_links" ]; then
      info "Resolving shortened URLs..."
      while IFS= read -r tco; do
        local resolved
        resolved=$(curl -sLI -o /dev/null -w '%{url_effective}' "$tco" 2>/dev/null || echo "$tco")
        ok "  $tco -> $resolved"
        python3 -c "
import json
with open('$output_file','r') as f: data = json.load(f)
data.setdefault('resolved_urls', {})
data['resolved_urls']['$tco'] = '$resolved'
with open('$output_file','w') as f: json.dump(data, f, ensure_ascii=False, indent=2)
" 2>/dev/null || true
      done <<< "$tco_links"
    fi
  else
    warn "Failed to fetch oembed metadata."
    echo '{"error": "oembed_fetch_failed"}' > "$output_file"
  fi
}

# ─── Single URL: Browser Fetch ───────────────────────────────────────────────
# Reuses browser session. Does NOT open/close browser.
fetch_with_browser() {
  local url="$1"
  local output_dir="$2"

  info "Navigating to URL..."
  browser_navigate "$url"

  info "Waiting ${BROWSER_TIMEOUT}s for content to render..."
  sleep "$BROWSER_TIMEOUT"

  # Snapshot
  info "Capturing page snapshot..."
  $AGENT_BROWSER_CMD snapshot > "${output_dir}/.snapshot.txt" 2>/dev/null
  local snapshot_lines
  snapshot_lines=$(wc -l < "${output_dir}/.snapshot.txt" | tr -d ' ')
  ok "Snapshot: ${snapshot_lines} lines"

  # Block detection
  if ! detect_block "${output_dir}/.snapshot.txt"; then
    return 1  # Caller handles retry
  fi

  # Screenshot
  info "Taking full-page screenshot..."
  $AGENT_BROWSER_CMD screenshot "${output_dir}/media/full_page.png" --full 2>/dev/null
  ok "Screenshot saved"

  # Extract images from DOM
  info "Extracting image URLs from DOM..."
  local images_json
  images_json=$($AGENT_BROWSER_CMD eval "
    JSON.stringify(
      [...document.querySelectorAll('article img, [data-testid=\"tweetPhoto\"] img')]
        .map((img, i) => ({
          index: i,
          src: img.src,
          alt: img.alt || '',
          width: img.naturalWidth,
          height: img.naturalHeight
        }))
        .filter(img => img.src && !img.src.includes('emoji') && !img.src.includes('profile_images') && img.width > 100)
    )
  " 2>/dev/null || echo '[]')

  echo "$images_json" > "${output_dir}/.images.json"
  local img_count
  img_count=$(echo "$images_json" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  ok "Found ${img_count} article images"

  # Download images
  if [ "$DOWNLOAD_IMAGES" = true ] && [ "$img_count" -gt 0 ]; then
    info "Downloading images..."
    echo "$images_json" | python3 -c "
import json, sys, subprocess, os

images = json.load(sys.stdin)
output_dir = '${output_dir}'
mapping = []

for i, img in enumerate(images):
    src = img['src']
    ext = 'jpg'
    if '.png' in src: ext = 'png'
    elif '.gif' in src: ext = 'gif'
    elif '.webp' in src: ext = 'webp'

    filename = f'img_{i+1:03d}.{ext}'
    filepath = os.path.join(output_dir, 'media', filename)

    download_url = src
    if 'pbs.twimg.com' in src:
        if '?' in src:
            download_url = src.split('?')[0] + '?format=' + ext + '&name=large'
        elif 'format=' not in src:
            download_url = src + '?format=' + ext + '&name=large'

    result = subprocess.run(
        ['curl', '-sL', '--max-time', '30',
         '-H', 'Referer: https://x.com/',
         '-o', filepath, download_url],
        capture_output=True
    )

    if result.returncode == 0 and os.path.getsize(filepath) > 0:
        mapping.append({'original': src, 'local': filename, 'alt': img['alt']})
        print(f'  [OK] {filename} ({os.path.getsize(filepath)} bytes)')
    else:
        print(f'  [FAIL] {filename}')

with open(os.path.join(output_dir, '.images.json'), 'w') as f:
    json.dump(mapping, f, ensure_ascii=False, indent=2)
" 2>/dev/null
    ok "Image download complete"
  fi

  return 0
}

# ─── Download Single URL (with retry) ────────────────────────────────────────
download_single() {
  local url="$1"
  local output_dir="$2"
  local retry_count=0

  # Validate URL
  if [[ ! "$url" =~ (x\.com|twitter\.com)/.+/status/ ]]; then
    error "Invalid URL: $url"
    return 1
  fi

  url=$(echo "$url" | sed 's|^http://|https://|')

  info "Archiving: $url"
  info "Output:    $output_dir"

  mkdir -p "${output_dir}/media"

  # Oembed (safe, no rate limit concern)
  fetch_oembed "$url" "${output_dir}/.meta.json"

  # Browser fetch with retry
  while [ $retry_count -le $MAX_RETRIES ]; do
    if fetch_with_browser "$url" "$output_dir"; then
      # Success - reset consecutive block counter
      CONSECUTIVE_BLOCKS=0
      break
    else
      retry_count=$((retry_count + 1))
      CONSECUTIVE_BLOCKS=$((CONSECUTIVE_BLOCKS + 1))

      if [ $retry_count -gt $MAX_RETRIES ]; then
        error "Max retries ($MAX_RETRIES) exceeded for: $url"
        echo '{"status": "blocked", "url": "'"$url"'"}' > "${output_dir}/.status.json"
        return 1
      fi

      # Exponential backoff: cooldown * 2^(retry-1)
      local backoff=$(( COOLDOWN * (1 << (retry_count - 1)) ))
      warn "Block detected. Retry $retry_count/$MAX_RETRIES after ${backoff}s cooldown..."

      # Close and reopen browser (get fresh session)
      browser_close
      sleep "$backoff"
      browser_ensure_open
    fi
  done

  # Write success status
  python3 -c "
import json, os
output_dir = '${output_dir}'
meta_file = os.path.join(output_dir, '.meta.json')
snapshot_file = os.path.join(output_dir, '.snapshot.txt')
images_file = os.path.join(output_dir, '.images.json')
summary = {
    'status': 'success',
    'url': '${url}',
    'output_dir': output_dir,
    'snapshot_lines': sum(1 for _ in open(snapshot_file)) if os.path.exists(snapshot_file) else 0,
    'image_count': len(json.load(open(images_file))) if os.path.exists(images_file) else 0
}
if os.path.exists(meta_file):
    meta = json.load(open(meta_file))
    summary['author_name'] = meta.get('author_name', 'unknown')
print(json.dumps(summary, ensure_ascii=False, indent=2))
" 2>/dev/null || echo '{"status": "success"}'

  return 0
}

# ─── Extract Tweet ID from URL ────────────────────────────────────────────────
extract_tweet_id() {
  echo "$1" | python3 -c "
import sys, re
url = sys.stdin.read().strip()
m = re.search(r'/status/(\d+)', url)
print(m.group(1) if m else 'unknown')
" 2>/dev/null || echo "unknown"
}

# ─── Batch Download ───────────────────────────────────────────────────────────
do_batch() {
  local url_file="$1"
  local base_dir="$2"

  if [ ! -f "$url_file" ]; then
    error "URL file not found: $url_file"
    return 1
  fi

  # Parse URLs (skip comments and blank lines)
  local urls=()
  while IFS= read -r line; do
    line=$(echo "$line" | sed 's/#.*//' | xargs)  # strip comments + whitespace
    [ -n "$line" ] && urls+=("$line")
  done < "$url_file"

  local total=${#urls[@]}
  if [ "$total" -eq 0 ]; then
    error "No valid URLs found in $url_file"
    return 1
  fi

  echo "==========================================="
  echo " X Post Archiver - Batch Mode"
  echo "==========================================="
  echo ""
  info "URL file:    $url_file"
  info "Output base: $base_dir"
  info "Total URLs:  $total"
  info "Delay:       ${DELAY_MIN}-${DELAY_MAX}s between requests"
  info "Max retries: $MAX_RETRIES (cooldown: ${COOLDOWN}s)"
  info "Resume mode: $RESUME_MODE"
  echo ""

  mkdir -p "$base_dir"

  # Ensure browser is ready
  ensure_playwright
  browser_ensure_open

  # Track results
  local success=0
  local failed=0
  local skipped=0
  local results_file="${base_dir}/_batch_report.json"

  echo '[]' > "$results_file"

  # Process each URL
  local i=0
  for url in "${urls[@]}"; do
    i=$((i + 1))
    local tweet_id
    tweet_id=$(extract_tweet_id "$url")
    local output_dir="${base_dir}/${tweet_id}"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    step "[$i/$total] $url"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Resume mode: skip if already downloaded
    if [ "$RESUME_MODE" = true ] && [ -f "${output_dir}/.snapshot.txt" ]; then
      ok "Already downloaded (resume mode). Skipping."
      skipped=$((skipped + 1))

      # Append to report
      python3 -c "
import json
with open('$results_file','r') as f: data = json.load(f)
data.append({'index': $i, 'url': '$url', 'status': 'skipped', 'dir': '$output_dir'})
with open('$results_file','w') as f: json.dump(data, f, ensure_ascii=False, indent=2)
" 2>/dev/null
      continue
    fi

    # Download with error handling
    local status="success"
    if download_single "$url" "$output_dir"; then
      success=$((success + 1))
      ok "[$i/$total] Done: $tweet_id"
    else
      failed=$((failed + 1))
      status="failed"
      error "[$i/$total] Failed: $tweet_id"
    fi

    # Append result to report
    python3 -c "
import json
with open('$results_file','r') as f: data = json.load(f)
data.append({'index': $i, 'url': '$url', 'tweet_id': '$tweet_id', 'status': '$status', 'dir': '$output_dir'})
with open('$results_file','w') as f: json.dump(data, f, ensure_ascii=False, indent=2)
" 2>/dev/null

    # Anti-detection: check if we should pause longer
    if [ $CONSECUTIVE_BLOCKS -ge 2 ]; then
      warn "Multiple consecutive blocks detected. Extended cooldown..."
      local extended=$(( COOLDOWN * 3 ))
      info "Pausing ${extended}s to avoid IP-level block..."
      browser_close
      sleep "$extended"
      browser_ensure_open
      CONSECUTIVE_BLOCKS=0
    fi

    # Normal delay between requests (skip for last URL)
    if [ $i -lt $total ]; then
      random_delay "$DELAY_MIN" "$DELAY_MAX"
    fi
  done

  # Close browser
  browser_close

  # Print summary
  echo ""
  echo "==========================================="
  echo " Batch Download Summary"
  echo "==========================================="
  ok "Success:  $success"
  [ $skipped -gt 0 ] && info "Skipped:  $skipped"
  [ $failed -gt 0 ] && error "Failed:   $failed"
  echo "Total:    $total"
  echo ""
  info "Report:   $results_file"
  info "Next:     Claude Code reads each .snapshot.txt and assembles article.md"
  echo "==========================================="

  # Output JSON summary
  python3 -c "
import json
print(json.dumps({
    'status': 'batch_complete',
    'total': $total,
    'success': $success,
    'failed': $failed,
    'skipped': $skipped,
    'report': '$results_file',
    'base_dir': '$base_dir'
}, indent=2))
" 2>/dev/null
}

# ─── Single Download (original mode) ─────────────────────────────────────────
do_download() {
  local url="$1"
  local output_dir="$2"

  ensure_playwright
  browser_ensure_open

  echo ""
  if download_single "$url" "$output_dir"; then
    echo ""
    echo "==========================================="
    ok "Download complete!"
    echo ""
    echo "Files:"
    ls -lh "${output_dir}/" 2>/dev/null | grep -v "^total"
    echo ""
    echo "Media:"
    ls -lh "${output_dir}/media/" 2>/dev/null | grep -v "^total"
    echo "==========================================="
    echo ""
    info "Next: Claude Code will read .snapshot.txt and assemble article.md"
  fi

  browser_close
}

# ─── Parse Options ────────────────────────────────────────────────────────────
parse_options() {
  while [ $# -gt 0 ]; do
    case "$1" in
      --no-images)    DOWNLOAD_IMAGES=false ;;
      --timeout)      BROWSER_TIMEOUT="${2:-8}"; shift ;;
      --delay-min)    DELAY_MIN="${2:-15}"; shift ;;
      --delay-max)    DELAY_MAX="${2:-45}"; shift ;;
      --max-retries)  MAX_RETRIES="${2:-2}"; shift ;;
      --cooldown)     COOLDOWN="${2:-120}"; shift ;;
      --resume)       RESUME_MODE=true ;;
      *)              warn "Unknown option: $1" ;;
    esac
    shift
  done
}

# ─── Entry Point ──────────────────────────────────────────────────────────────
main() {
  local command="${1:-help}"
  shift || true

  case "$command" in
    preflight|check)
      preflight
      ;;

    download)
      local url="${1:-}"
      local output_dir="${2:-}"
      [ -z "$url" ] || [ -z "$output_dir" ] && {
        error "Usage: bash download.sh download <URL> <OUTPUT_DIR> [options]"
        return 1
      }
      shift 2 || true
      parse_options "$@"
      do_download "$url" "$output_dir"
      ;;

    batch)
      local url_file="${1:-}"
      local base_dir="${2:-}"
      [ -z "$url_file" ] || [ -z "$base_dir" ] && {
        error "Usage: bash download.sh batch <URL_FILE> <BASE_DIR> [options]"
        echo ""
        echo "URL_FILE format (one URL per line, # for comments):"
        echo "  # My saved articles"
        echo "  https://x.com/user1/status/123456"
        echo "  https://x.com/user2/status/789012"
        return 1
      }
      shift 2 || true
      parse_options "$@"
      do_batch "$url_file" "$base_dir"
      ;;

    help|*)
      echo "X Post Archiver - Download Script v2"
      echo ""
      echo "Usage:"
      echo "  bash download.sh preflight                            # Check environment"
      echo "  bash download.sh download <URL> <DIR> [options]       # Single download"
      echo "  bash download.sh batch <URL_FILE> <DIR> [options]     # Batch download"
      echo ""
      echo "Shared Options:"
      echo "  --no-images        Skip image downloading"
      echo "  --timeout N        Browser render wait seconds (default: 8)"
      echo ""
      echo "Batch Options:"
      echo "  --delay-min N      Min delay between requests (default: 15)"
      echo "  --delay-max N      Max delay between requests (default: 45)"
      echo "  --max-retries N    Retries per URL on block (default: 2)"
      echo "  --cooldown N       Cooldown after block in seconds (default: 120)"
      echo "  --resume           Skip already-downloaded URLs"
      echo ""
      echo "URL File Format:"
      echo "  # Comments start with #"
      echo "  https://x.com/user/status/123456"
      echo "  https://x.com/user/status/789012"
      ;;
  esac
}

main "$@"
