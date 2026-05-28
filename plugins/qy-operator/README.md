# qy-operator — 晴芽运营工具 Plugin

为晴芽**平台运营人员（当前 = Jason）** 做的一套 Claude Code plugin，封装一系列工具型 Skills，覆盖对话数据的**统计 / 深度分析 / 用户画像 / 多维度本地导出**四大能力。

## MVP 范围（v1.0.0）

仅实现 4 大能力中的第 1 个：**多维度对话导出**。

| 能力 | 状态 | Skill |
|---|---|---|
| 多维度对话导出 | ✅ MVP | `dump-conversations` |
| 整体统计 | ⏳ 后续 | `stats-report`（占位） |
| 用户画像 | ⏳ 后续 | `user-profile`（占位） |
| 深度内容分析 | ⏳ 后续 | `content-analyze`（占位） |

## 安装

本 plugin 本体跟踪在 `JChao_Skills` repo，使用**软链**方式装到 30-QingYa workspace：

```bash
# 1. 本体已在 JChao_Skills 仓库（本目录）
ls ~/0-WORKSPACE/60-Tools/JChao_Skills/plugins/qy-operator/

# 2. 软链到 30-QingYa workspace 的 .claude/plugins/
mkdir -p ~/0-WORKSPACE/30-QingYa/.claude/plugins
ln -s ~/0-WORKSPACE/60-Tools/JChao_Skills/plugins/qy-operator \
      ~/0-WORKSPACE/30-QingYa/.claude/plugins/qy-operator

# 3. 验证
cd ~/0-WORKSPACE/30-QingYa
# Claude Code 应能识别 /qy-dump 命令
```

**为什么链到 30-QingYa 而不是 miniapp**：本 plugin 是运营工具，跨子项目用（无论在 `30-QingYa/产品/miniapp/`、`30-QingYa/营销运营/`、`30-QingYa/内容/` 任何位置开 Claude Code 都要能用）。

## 使用方式

### 触发双入口

| 形式 | 命令 | 用于 |
|---|---|---|
| 完整名 | `/qy-operator:dump-conversations --user=oABC --since=2026-05-01` | explicit / 文档示例 |
| 短 alias | `/qy-dump --user=oABC --since=2026-05-01` | 日常用 |

### 常用场景

```bash
# 场景 1：单用户 30 天完整对话（自己复盘）
/qy-dump --user=oABC123 --since=2026-04-27
  # = light 脱敏 + md 默认

# 场景 2：本周高风险事件
/qy-dump --since=2026-05-20 --risk-min=P1 --include-request-stats

# 场景 3：自媒体素材采集（强锁 full 脱敏 + md）
/qy-dump --since=2026-05-20 --keyword=住院 --for-content

# 场景 4：二次分析喂 Jupyter
/qy-dump --since=2026-05-20 --format=json --anonymize=none \
         --output=~/qy-analysis/2026-W21/
```

完整参数 / 边界 / 脱敏档位说明见 `skills/dump-conversations/SKILL.md`，可用场景示例见 `skills/dump-conversations/references/usage-examples.md`。

## 依赖

- **miniapp backend** 已实现 `app.cli.operator` 包（QY-68 + QY-69）：
  - 路径：`~/0-WORKSPACE/30-QingYa/产品/miniapp/backend/app/cli/operator/`
  - 入口：`uv run python -m app.cli.operator dump <args>`
- **postgres** docker 容器：`~/0-WORKSPACE/30-QingYa/产品/miniapp/deploy/docker-compose.yml`
- **DashScope** API key（仅 `--anonymize=full` 或 `--for-content` 触发时需要，配在 backend `.env`）

## 隐私护栏

| 项 | 实现 |
|---|---|
| 输出位置 | `~/qy-exports/`（用户主目录，**永不进 git**） |
| 文件权限 | umask 077 + chmod 600 after write |
| 自媒体 audit | `--for-content` 触发 → `_manifest.json` 永久记 `for_content_purpose=true` + `triggered_at` |
| LLM 调用 | DashScope qwen3.5-flash 做 NER 替换；只发对话片段不发 user_id；失败自动降级 light |
| 用户级 gitignore | 用户级 `~/.config/git/ignore` 加 `qy-exports/`（**不是 repo .gitignore**） |

## 设计文档

- Design spec：[`30-QingYa/docs/superpowers/specs/2026-05-27-operator-plugin-design.md`](../../../../../30-QingYa/docs/superpowers/specs/2026-05-27-operator-plugin-design.md)
- Implementation plan：`30-QingYa/docs/superpowers/plans/2026-05-27-qy-operator-plugin.md`
- Linear epic：QY-67（共享底座 QY-68 / dump 命令 QY-69 / plugin 骨架 QY-70）

## 演进策略

```
plugins/qy-operator/skills/
├── dump-conversations/         ← MVP（v1.0.0）
├── stats-report/               ← 后续
├── user-profile/               ← 后续
└── content-analyze/            ← 后续
```

加新 Skill = 新建子目录，不动现有。共享底座（`_query.py` / `_anonymize.py` / `_serialize.py`）已在 backend `app/cli/operator/` 实现，后续 Skill 直接复用相同 pipeline 即可。

## License

Internal use only —— 晴芽 (QingYa) 项目。
