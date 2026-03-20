# Daily Briefing Skill

一个用于每日从 Obsidian 笔记库中汇总待办事项（Tasks）和日程（Events）的 OpenClaw Skill。

## 目录结构
- `SKILL.md`: Skill 定义文件。
- `README.md`: 本文档。
- `brief.py`: 核心逻辑脚本，负责扫描指定目录下的 Markdown 文件。

## 工作原理
1. **Tasks 扫描**: 遍历 `/Users/qianli/1-NOTES/20-Structured/tasks/` 目录及其子目录，寻找包含 `due:YYYY-MM-DD` 格式的任务行。
2. **Events 扫描**: 在 `/Users/qianli/1-NOTES/20-Structured/events/YYYY/YYYY-MM.md` 文件中寻找 `## YYYY-MM-DD` 二级标题下的列表项。

## 使用方法
### 命令行调用
```bash
# 获取今日汇总
python3 brief.py

# 获取指定日期汇总
python3 brief.py --date 2026-03-20
```

### OpenClaw 集成
已配置 Cron 任务，每日 08:01 自动执行并汇报。

## 部署说明
本体存放于：`/Users/qianli/0-WORKSPACE/60-Tools/JChao_Skills/skills/daily-briefing`
软链接至：`/Users/qianli/.openclaw/workspace/skills/daily-briefing`
