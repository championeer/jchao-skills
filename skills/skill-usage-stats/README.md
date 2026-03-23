# Skill Usage Stats Skill

统计并显示 OpenClaw 技能（Skills）的调用频次。

## 目录结构
- `SKILL.md`: Skill 定义。
- `README.md`: 本文档。
- `stats.py`: 基于日志分析的统计脚本。

## 工作原理
1. 解析 `~/.openclaw/logs/gateway.log` 文件。
2. 提取 `skills/` 路径后的首个目录名作为技能名称。
3. 统计各技能出现的频率。

## 使用方法
### 命令行调用
```bash
python3 stats.py
```

## 部署说明
- 本体：`/Users/qianli/0-WORKSPACE/60-Tools/JChao_Skills/skills/skill-usage-stats`
- 软链：`/Users/qianli/.openclaw/workspace/skills/skill-usage-stats`
