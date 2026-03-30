---
name: daily-briefing
description: 生成每日简报，汇总当天的任务和事件。当用户说"今日简报"、"daily briefing"、"今天有什么安排"、"今天的任务"时触发。
---

# Daily Briefing Skill

Generate a daily summary of tasks and events from the user's note repository.

## Usage

```bash
# Get summary for today
python3 /Users/qianli/.openclaw/workspace/skills/daily-briefing/brief.py

# Get summary for a specific date
python3 /Users/qianli/.openclaw/workspace/skills/daily-briefing/brief.py --date 2026-03-20
```

## Implementation

The skill looks into:
- `/Users/qianli/1-NOTES/20-Structured/tasks/` for lines containing `due:YYYY-MM-DD`.
- `/Users/qianli/1-NOTES/20-Structured/events/YYYY/YYYY-MM.md` for a section `## YYYY-MM-DD`.
