---
name: worklog
description: This skill should be used when the user asks to "log work", "记录工作", "写日志", "worklog", "记录一下", "工作日志", "log this session", or wants to summarize current session work into the daily work log. Also triggers on "/worklog".
---

# Work Log Skill

Record a summary of the current session's work into the daily work log at `~/0-WORKSPACE/40-Founder/40-Logs/`.

## When to Use

Invoke at the end of a task or session to capture what was accomplished. Designed for use across Claude Code, Codex, and Openclaw.

## Workflow

### 1. Determine Project Context

Identify the project from the current working directory:

| Working Directory Pattern | Project Tag | Category |
|---------------------------|-------------|----------|
| `10-AIPO` or `AIPO`      | AIPO        | core     |
| `20-MedClaw` or `MedClaw` | MedClaw    | core     |
| `30-QingYa` or `QingYa`  | QingYa      | core     |
| `40-Founder`              | Founder     | ops      |
| `50-Knowledge`            | Knowledge   | ops      |
| `60-Tools`                | Tools       | ops      |
| Other                     | Misc        | ops      |

### 2. Summarize the Session

Review the conversation history and produce a concise summary:

- **One-line title**: What was accomplished (imperative verb + object)
- **Key items**: 3-5 bullet points of concrete deliverables or decisions
- **Tags**: Assign tags from the taxonomy below

Keep it factual and brief. No filler. Record what was **done**, not what was discussed.

### 3. Assign Tags

Every entry gets tags for later filtering and analysis. Combine one or more from each applicable dimension:

**Project tags** (always include):
- `#AIPO` / `#MedClaw` / `#QingYa` — specific core product
- `#Founder` / `#Knowledge` / `#Tools` — for non-product work

**Core product marker** (auto-added by script for AIPO, MedClaw, QingYa):
- `#core` — marks this entry as core product work

**Work type** (pick the most fitting one):
- `#feature` — new functionality
- `#bugfix` — bug or issue fix
- `#refactor` — code restructuring without behavior change
- `#design` — UI/UX design work
- `#infra` — infrastructure, deployment, CI/CD
- `#docs` — documentation
- `#planning` — strategy, architecture, roadmap decisions
- `#research` — investigation, competitive analysis, market research
- `#ops` — operations, maintenance, admin tasks

Pass tags as a space-separated string (e.g., `"#AIPO #feature"`). The script auto-prepends `#core` for the three core projects — do not add `#core` manually.

### 4. Append to Daily Log

Run the bundled script to append the entry:

```bash
bash ~/.claude/skills/worklog/scripts/append-log.sh "<project_tag>" "<title>" "<bullet_points>" "<tags>"
```

**Arguments:**
- `$1` — Project tag (e.g., `AIPO`, `MedClaw`)
- `$2` — One-line title
- `$3` — Bullet points, one per line, each starting with `- `
- `$4` — Tags, space-separated (e.g., `"#AIPO #feature"`)

The script handles:
- Creating `YYYY-MM/` directory if missing
- Creating the daily log file from template if it doesn't exist
- Auto-prepending `#core` tag for AIPO, MedClaw, QingYa
- Appending a timestamped entry with tags under `## 工作记录`

### 5. Confirm

After appending, read back the updated log file and confirm to the user what was recorded.

## Log Entry Format

Each appended entry follows this format:

```markdown
### HH:MM · ProjectTag · Title
Tags: #core #AIPO #feature
- Bullet point 1
- Bullet point 2
- Bullet point 3
```

Non-core project entries omit the `#core` tag:

```markdown
### HH:MM · Tools · Title
Tags: #Tools #ops
- Bullet point 1
```

## Examples

**Core project — AIPO bug fix:**

```bash
bash ~/.claude/skills/worklog/scripts/append-log.sh "AIPO" "修复登录页面移动端布局问题" \
  "- 修复了登录按钮在 iPhone SE 上的溢出问题
- 更新了响应式断点从 375px 到 360px
- 添加了移动端登录页的 snapshot 测试" \
  "#AIPO #bugfix"
```

Output in log:
```markdown
### 14:30 · AIPO · 修复登录页面移动端布局问题
Tags: #core #AIPO #bugfix
- 修复了登录按钮在 iPhone SE 上的溢出问题
- 更新了响应式断点从 375px 到 360px
- 添加了移动端登录页的 snapshot 测试
```

**Non-core project — Founder ops:**

```bash
bash ~/.claude/skills/worklog/scripts/append-log.sh "Founder" "规划创始人工作区目录结构" \
  "- 设计了 40-Founder 完整目录结构
- 创建了 worklog skill" \
  "#Founder #planning"
```

Output in log:
```markdown
### 16:02 · Founder · 规划创始人工作区目录结构
Tags: #Founder #planning
- 设计了 40-Founder 完整目录结构
- 创建了 worklog skill
```

## Searching Tags

Tags enable quick filtering across all logs:

```bash
# All core product work
grep -r "#core" ~/0-WORKSPACE/40-Founder/40-Logs/

# All AIPO entries
grep -r "#AIPO" ~/0-WORKSPACE/40-Founder/40-Logs/

# All bug fixes across all projects
grep -r "#bugfix" ~/0-WORKSPACE/40-Founder/40-Logs/

# Core features this month
grep "#core.*#feature\|#feature.*#core" ~/0-WORKSPACE/40-Founder/40-Logs/2026-03/
```

## Notes

- One log file per day, multiple entries accumulate throughout the day
- The `今日要事` and `明日计划` sections are for manual use, not auto-filled
- If invoked without clear work to log, ask the user what to record
- Cross-project sessions: if a session touches multiple projects, log the primary one and mention the other in bullet points
