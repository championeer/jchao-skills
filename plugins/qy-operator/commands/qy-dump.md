---
description: 晴芽对话数据导出（dump-conversations 短 alias）
argument-hint: [--user=...] [--since=...] [--for-content] [--dry-run] ...
---

调用 `dump-conversations` skill 进行多维度对话数据导出。

参数透传给 backend `app.cli.operator dump`，完整列表见 `${CLAUDE_PLUGIN_ROOT}/skills/dump-conversations/SKILL.md`。常用：

- `/qy-dump --user=<user_id> --since=2026-05-01` — 单用户复盘
- `/qy-dump --since=2026-05-20 --risk-min=P1 --include-request-stats` — 本周高风险事件
- `/qy-dump --since=2026-05-20 --keyword=住院 --for-content` — 自媒体素材采集（强锁 full 脱敏 + audit 留痕）
- `/qy-dump --since=2026-05-20 --format=json --anonymize=none --output=~/qy-analysis/W21/` — 二次分析

## 执行流程

1. 跑 `${CLAUDE_PLUGIN_ROOT}/scripts/find-backend.sh` 拿 miniapp backend 路径
2. 跑 `${CLAUDE_PLUGIN_ROOT}/scripts/ensure-pg.sh` 确认 postgres 在跑（不跑给提示后停下）
3. 任何带过滤的请求**优先 dry-run** 让用户看命中规模：
   ```bash
   cd <BACKEND_DIR> && uv run python -m app.cli.operator dump $ARGUMENTS --dry-run
   ```
4. 用户确认后**移除 `--dry-run` 重跑**正式导出：
   ```bash
   cd <BACKEND_DIR> && uv run python -m app.cli.operator dump $ARGUMENTS
   ```
5. 报告输出目录 + 命中行数 + 脱敏档位 + for-content 标记。

## 用户参数

$ARGUMENTS

按 `dump-conversations` skill 中的 SKILL.md 工作流执行，遇到 stderr 错误码（exit 1=参数错 / exit 2=DB 错）参考 SKILL.md 的「失败兜底」表给用户人类可读建议。
