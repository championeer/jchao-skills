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
