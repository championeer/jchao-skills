---
name: x-post-archiver
description: >
  Downloads and archives X (Twitter) posts, articles, and threads as structured Markdown with media.
  Supports auth login, single and batch download with anti-detection measures.
  Use when the user wants to save, download, archive, or convert X/Twitter posts to Markdown.
  Triggers: "download tweet", "save this X post", "archive this tweet", "convert tweet to markdown",
  "batch download tweets", or when user provides x.com / twitter.com URLs and asks to save/download them.
allowed-tools: Bash(npx agent-browser:*), Bash(bash:*), Bash(node:*), Bash(curl:*), Bash(python3:*), Bash(mkdir:*), Bash(chmod:*)
---

# X Post Archiver

Archive X (Twitter) posts, articles, and threads as clean Markdown with all associated media.
Supports auth login, single URL and batch mode with built-in anti-detection.

## Why This Approach

| Method | Result | Why |
|--------|--------|-----|
| curl / WebFetch | Fails | X requires JavaScript rendering |
| Nitter / third-party | Unreliable | Frontends frequently go down |
| yt-dlp | Fails for Articles | Only supports video/media tweets |
| **oembed API** | Metadata only | Official API, gets author/date/handle |
| **agent-browser (Playwright)** | Full content | Renders JS like a real browser |

### Proven Pipeline

```
[oembed API]         → metadata (author, date, handle)
[state load]         → restore logged-in session (if auth file exists)
[agent-browser]      → open URL → render JS → snapshot (full text)
[agent-browser eval] → extract image URLs from DOM
[curl]               → download images
[Claude Code]        → parse snapshot → assemble clean Markdown
```

## Prerequisites

- **Node.js** (v18+), **npx**, **curl**, **python3**
- **agent-browser** — auto-installed via npx
- **Playwright Chromium** — auto-installed if missing

---

## Auth: Login & Save Session (Recommended)

Anonymous access to X is unreliable — X may show login walls that block content rendering.
The `login` command solves this by saving a logged-in browser session for reuse.

### Why Auth Matters

| Mode | Reliability | Limitation |
|------|-------------|-----------|
| **Anonymous** | Unstable | X may return login wall instead of content; varies by IP/region |
| **With Auth** | Stable | Full content always renders; can access protected tweets you follow |

### First-Time Setup (one-time, ~2 minutes)

```bash
bash <SKILL_DIR>/scripts/download.sh login
```

This will:
1. Open a **visible** browser window to X's login page
2. Wait for you to manually log in (username, password, 2FA)
3. After you confirm login, save session to `~/.claude/skills/x-post-archiver/x-auth.json`

### How Auth Is Used

The auth file is loaded **automatically** in this priority:

1. `--auth <FILE>` flag (explicit path)
2. Default location: `~/.claude/skills/x-post-archiver/x-auth.json` (auto-detected)
3. No auth file → anonymous mode (with warning)

When auth is loaded, the browser starts with full login state (cookies, localStorage, etc.)
before navigating to any X URL. This means:
- No login walls
- Full article content always renders
- Can access tweets from accounts you follow (including protected)
- Significantly reduces block/rate-limit risk in batch mode

### Auth on Another Machine

To use auth on a different machine:
1. Run `login` on that machine, OR
2. Copy `x-auth.json` from the original machine to the same path

### Auth Expiry

X sessions typically last weeks to months. If downloads start failing again:
```bash
bash <SKILL_DIR>/scripts/download.sh login   # Re-login to refresh
```

---

## Workflow: Single URL

### Phase 0: Ask User Preferences

Before starting, gather these from the user via AskUserQuestion:

1. **Output location**: Where to save? (default: current working directory)
2. **Download media**: Download images/screenshots? (default: yes)
3. **Article naming**: Use article title or tweet ID as directory name? (default: title)
4. **Language preference**: Keep original language or add translation? (default: original only)

### Phase 1: Preflight

```bash
bash <SKILL_DIR>/scripts/download.sh preflight
```

### Phase 2: Download

```bash
bash <SKILL_DIR>/scripts/download.sh download "<URL>" "<OUTPUT_DIR>" [--auth FILE] [--no-images] [--timeout N]
```

### Phase 3: Assemble Markdown (Claude Code)

1. **Read** `<OUTPUT_DIR>/.meta.json` for metadata
2. **Read** `<OUTPUT_DIR>/.snapshot.txt` for page content
3. **Read** `<OUTPUT_DIR>/.images.json` for image mapping
4. **Parse** snapshot into clean Markdown (see Parsing Rules below)
5. **Save** as `<OUTPUT_DIR>/article.md`

### Phase 4: Verification

Confirm markdown exists, images downloaded, report directory structure.

---

## Workflow: Batch Mode

### Phase 0: Ask User Preferences (Batch)

In addition to single-mode preferences, ask:

1. **URL source**: Provide a file with URLs, or paste URLs directly?
2. **Speed vs safety**: Conservative (slow, safe) or aggressive (faster, riskier)?
   - Conservative: 30-60s delay, 2 retries, 120s cooldown (recommended for 10+ URLs)
   - Moderate: 15-45s delay, 2 retries, 90s cooldown (OK for 5-10 URLs)
   - Aggressive: 8-20s delay, 1 retry, 60s cooldown (risky for >5 URLs)
3. **Resume support**: Enable resume mode? (skip already-downloaded URLs)

### Phase 1: Prepare URL File

If user provides URLs directly (pasted or in conversation), create the URL file:

Example `urls.txt`:
```
# OpenClaw related articles
https://x.com/servasyy_ai/status/2020475413055885385
https://x.com/someone/status/1234567890

# AI discussion threads
https://x.com/another/status/9876543210
```

### Phase 2: Preflight

```bash
bash <SKILL_DIR>/scripts/download.sh preflight
```

### Phase 3: Run Batch Download

```bash
bash <SKILL_DIR>/scripts/download.sh batch "<URL_FILE>" "<BASE_DIR>" [options]
```

**Recommended presets (with auth for best results):**

```bash
# Conservative (10+ URLs, safest)
bash <SKILL_DIR>/scripts/download.sh batch urls.txt ./archive \
  --auth ~/.claude/skills/x-post-archiver/x-auth.json \
  --delay-min 30 --delay-max 60 --max-retries 2 --cooldown 120 --resume

# Moderate (5-10 URLs) — auth auto-detected if at default path
bash <SKILL_DIR>/scripts/download.sh batch urls.txt ./archive \
  --delay-min 15 --delay-max 45 --max-retries 2 --cooldown 90 --resume

# Aggressive (< 5 URLs, with auth = low risk)
bash <SKILL_DIR>/scripts/download.sh batch urls.txt ./archive \
  --delay-min 8 --delay-max 20 --max-retries 1 --cooldown 60
```

### Phase 4: Assemble Markdown for Each Article

After batch completes:
1. **Read** `<BASE_DIR>/_batch_report.json` for results summary
2. For each successful download (`status: "success"`):
   a. Read `<tweet_id_dir>/.snapshot.txt`
   b. Read `<tweet_id_dir>/.meta.json`
   c. Parse and assemble `<tweet_id_dir>/article.md`
3. Report failed URLs to user for manual retry

### Phase 5: Verification

Report batch summary to user:
- How many succeeded / failed / skipped
- List any failed URLs
- Total directory structure

---

## Anti-Detection Measures

The script implements multiple layers of protection:

### 0. Auth Session (most effective)
- Logged-in sessions are treated as real users by X
- Dramatically reduces login wall and rate-limit triggers
- Auth state is loaded once per browser session, persists across navigations

### 1. Browser Session Reuse
- Opens browser **once**, navigates between URLs
- Avoids repeated browser launch/close (looks like real user browsing)
- On block detection: closes and reopens browser (fresh session, re-loads auth)

### 2. Random Delays
- Configurable min/max delay between requests
- Uses true random (python `random.randint`), not predictable patterns
- Default: 15-45 seconds between requests

### 3. Block Detection (`detect_block`)
Automatically detects when X is blocking access by analyzing the snapshot:

| Signal | Meaning | Action |
|--------|---------|--------|
| Snapshot < 15 lines | Page didn't render | Retry with backoff |
| Login wall + no article content | Rate limited | Retry with backoff |
| "Something went wrong" | Error page | Retry with backoff |
| Article content present | Success (even with login prompt) | Proceed normally |

### 4. Exponential Backoff
On block detection:
- 1st retry: wait `cooldown` seconds (default 120s)
- 2nd retry: wait `cooldown × 2` seconds (240s)
- After max retries: mark URL as failed, continue to next

### 5. Consecutive Block Circuit Breaker
If 2+ URLs in a row are blocked:
- Triggers extended cooldown (`cooldown × 3`)
- Closes and reopens browser (new session + re-loads auth)
- Resets consecutive block counter

### 6. Resume Mode (`--resume`)
- Skips URLs whose output directory already has a `.snapshot.txt`
- Allows safe re-run after interruption or partial failure
- No wasted requests on already-downloaded content

### Risk Level Reference

| Batch Size | With Auth | Without Auth | Recommended Delay |
|------------|-----------|--------------|-------------------|
| 1-3 URLs | Almost zero | Very Low | 8-15s |
| 5-10 URLs | Very Low | Low | 15-45s |
| 10-30 URLs | Low | Low-Medium | 30-60s |
| 30-100 URLs | Low-Medium | Medium | 45-90s |
| 100+ URLs | Medium | High | 60-120s + breaks |

For 100+ URLs, consider splitting across multiple sessions/days.

---

## Snapshot Parsing Rules

The snapshot is an accessibility tree. Article content is inside `article` elements:

- `heading [level=2]` → `## heading text`
- `heading [level=3]` → `### heading text`
- `text:` lines → paragraph text
- `blockquote:` → `> blockquote text`
- `list:` / `listitem:` → markdown list items
- `link "Image"` with `/url: .../media/...` → `![](media/img_NNN.jpg)`
- `link "SOMETHING.md"` → `` `SOMETHING.md` ``
- Ignore: navigation, footer, trending, sign-up, buttons (reply/repost/like)

## Markdown Output Format

```markdown
# <Article Title>

> **Author**: <name> ([@<handle>](https://x.com/<handle>))
> **Date**: <date>
> **Original**: [<url>](<url>)
> **Stats**: <replies> replies · <reposts> reposts · <likes> likes · <views> views

---

<article body with proper markdown formatting>
<images referenced as ![description](media/img_NNN.jpg)>
```

## File Structure

### Single Download
```
<article-directory>/
├── article.md
└── media/
    ├── full_page.png
    ├── img_001.jpg
    └── ...
```

### Batch Download
```
<base-directory>/
├── _batch_report.json
├── urls.txt
├── <tweet_id_1>/
│   ├── article.md
│   └── media/
│       ├── full_page.png
│       └── img_001.jpg
├── <tweet_id_2>/
│   ├── article.md
│   └── media/
│       └── full_page.png
└── ...
```

## Platform Notes

| Platform | Support | Notes |
|----------|---------|-------|
| **macOS** | Full | All tools pre-installed or via Homebrew |
| **Linux** | Full | May need `npx playwright install-deps` |
| **WSL** | Full | Follow Linux instructions inside WSL |
| **Windows (native)** | Not supported | Use WSL: `wsl --install` in PowerShell (admin) |
| **Git Bash** | Partial | Basic features work, WSL recommended |

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| `agent-browser: not found` | Not installed | Auto-installs via npx |
| `Executable doesn't exist` | Playwright missing | Auto-installs chromium |
| Browser timeout | Slow page load | Increase `--timeout` |
| Empty snapshot / login wall | Not logged in / rate limited | Run `login` to save auth session |
| Image download 403 | CDN restriction | Uses Referer header; falls back to screenshot |
| Batch interrupted | Network / crash | Re-run with `--resume` to continue |
| Auth expired | Session too old | Re-run `login` to refresh |

## Script Reference

```bash
# Environment check
bash download.sh preflight

# Login & save session (one-time setup, recommended)
bash download.sh login [AUTH_FILE]

# Single download (auto-loads auth if available)
bash download.sh download <URL> <DIR> [--auth FILE] [--no-images] [--timeout N]

# Batch download
bash download.sh batch <URL_FILE> <DIR> \
  [--auth FILE] \
  [--delay-min N] [--delay-max N] \
  [--max-retries N] [--cooldown N] \
  [--resume] [--no-images] [--timeout N]

# Help
bash download.sh help
```
