---
name: dump-conversations
description: |
  晴芽对话数据导出器。覆盖 4 高频运营场景：单用户复盘、时间窗批量、高风险事件、关键词+Skill+Card 筛选。
  3 格式（md/json/csv）+ 3 档脱敏（none/light/full，full 走 DashScope qwen3.5-flash NER 替换）+ 原子写入 + chmod 600。
  触发方式：/qy-dump、/qy-operator:dump-conversations、"导出对话"、"dump 用户 X 的对话"、"导出本周高风险"、"导一份本周高风险对话"、"dump 上周关键词对话作为内容素材"。
  Triggers: 手动 /qy-dump 调用、运营复盘场景、自媒体素材采集（--for-content）、二次分析（--format=json 喂 Jupyter）。
---

# dump-conversations：晴芽对话数据多维度导出

你是晴芽运营人员的**对话数据导出助手**。任务：把后端 postgres 里的对话数据（sessions / messages / action_cards / request_stats / user_charts）按用户指定的 scope 导出到 `~/qy-exports/`，支持 3 种格式 + 3 档脱敏。

**核心定位**：不是备份（备份走 QY-66 `backup/*.sh`），不是用户面 export（用户自助导出是小程序前端功能），而是**运营人员持久化导出**——产出文件给后续 Skill chain（stats / profile / content-analyze）或 Jupyter / 自媒体直接消费。

---

## 一句话定义

`dump-conversations` 是把"晴芽 postgres 数据库的对话数据"翻译成"运营场景可消费文件"的导出器。

**输入**：scope 参数（用户 / 时间窗 / 风险 / 关键词 / Skill / Card 类型组合）
**输出**：`~/qy-exports/YYYY-MM-DD-HHMM-<scope>/` 含 `conversations.md` / `conversations.json` / `conversations.csv` / `_manifest.json`

---

## 什么时候用

### 4 个高频场景

| 场景 | 命令示例 | 输出 |
|---|---|---|
| **单用户复盘** | `/qy-dump --user=oABC --since=2026-04-27` | 默认 light 脱敏 + md，自己读 |
| **本周高风险** | `/qy-dump --since=2026-05-20 --risk-min=P1 --include-request-stats` | 含 LLM 调用统计，risk-P1+ |
| **自媒体素材** | `/qy-dump --since=2026-05-20 --keyword=住院 --for-content` | **强锁** full 脱敏 + md + audit 留痕 |
| **二次分析** | `/qy-dump --since=2026-05-20 --format=json --anonymize=none --output=~/qy-analysis/2026-W21/` | json 喂 Jupyter，full 数据 |

更多示例见 `references/usage-examples.md`。

---

## CLI 参数清单（15 项）

完整在 backend `app/cli/operator/dump.py`，参数表如下：

| 参数 | 类型 | default | 说明 |
|---|---|---|---|
| `--user UUID` | str | None | 单用户 user_id（UUID 或前 6 位前缀匹配） |
| `--user-csv FILE` | path | None | 批量用户文件（每行一个 UUID） |
| `--since DATE` | ISO8601 | 30 天前 | 时间窗起点 |
| `--until DATE` | ISO8601 | now | 时间窗终点 |
| `--risk-min` | P0\|P1\|P2\|P3 | None | 最低 `action_cards.risk_level` |
| `--skill SKILL_NAME` | str（可多次） | None | 过滤 `sessions.skill_name` |
| `--card-type TYPE` | str（可多次） | None | 过滤 `action_cards.output_type` |
| `--keyword TEXT` | str | None | `messages.content` LIKE |
| `--format` | md\|json\|csv\|all | **md** | 输出格式 |
| `--anonymize` | none\|light\|full | **light** | 脱敏档位 |
| `--include-chart` | flag | False | 附 F3 `user_charts.chart_data`（需解密） |
| `--include-request-stats` | flag | False | 附 `request_stats` 表记录 |
| `--output DIR` | path | `~/qy-exports/YYYY-MM-DD-HHMM-<scope>/` | 输出根目录 |
| `--dry-run` | flag | False | 只 show 命中行数，不写文件 |
| `--for-content` | flag | False | 自媒体场景：**强锁** `--anonymize=full` + `--format=md` + audit 留痕 |

**Exit codes**：
- `0`：成功 / dry-run / empty result
- `1`：typer 参数错误（非法 `--risk-min` 等）
- `2`：DB 连接失败（OperationalError，会提示启 postgres）

---

## 脱敏分级（spec §7）

| 字段 | none | light（**default**） | full |
|---|---|---|---|
| `user_id` (UUID) | 原值 | `u_a3f2c1`（前 6 位前缀） | `<user_001>` 索引匿名 |
| 家人姓名 | 原文 | 原文 | LLM 替换 `<家人A>` |
| 医院 / 学校 / 地址 | 原文 | 原文 | LLM 替换 `<某医院>`/`<某学校>`/`<某地>` |
| 手机号 / 微信号 | 原文 | regex 替换 `<手机号>`/`<微信号>` | 同 light |
| `created_at` / `risk_level` / `parent_emotion` | 原值 | 原值 | 原值 |

**关键安全约束**：
- LLM 替换走 **DashScope qwen3.5-flash**，**只发对话片段不发 user_id**（防审计串联）
- 替换映射缓存到 `<output_dir>/_anonymize_cache.json`（单次导出复用，跨次重建）
- LLM 失败 fallback：自动降级 light + stderr warning（不阻塞导出）

**自媒体场景必看**：用 `--for-content` 而不是 `--anonymize=full`——前者**额外** audit 留痕（`_manifest.json` 记 `for_content_purpose=true`），后者只是脱敏档位。

---

## 工作流（接到用户请求后这么做）

### 第 1 步：探测环境

调用 `scripts/find-backend.sh` 拿 backend 路径，调用 `scripts/ensure-pg.sh` 确认 postgres 在跑：

```bash
BACKEND_DIR=$("${CLAUDE_PLUGIN_ROOT}/scripts/find-backend.sh")
"${CLAUDE_PLUGIN_ROOT}/scripts/ensure-pg.sh" || exit 1
```

如果 postgres 没跑，按 `ensure-pg.sh` 的 stderr 提示让用户启动：

```bash
cd ~/0-WORKSPACE/30-QingYa/产品/miniapp/deploy && sudo docker compose up -d postgres
```

### 第 2 步：dry-run 预估行数

任何带 `--since` / `--keyword` / `--risk-min` 等过滤条件的 dump，**先跑一次 `--dry-run`** 给用户看命中规模：

```bash
cd "${BACKEND_DIR}" && uv run python -m app.cli.operator dump \
  --since=2026-05-20 --risk-min=P1 --dry-run
# Dry run: 命中 312 rows (users=8, sessions=24, messages=189, action_cards=91)
```

如果命中超过 5000 rows / 100 sessions，提示用户：「数据量较大，确认要导出？可加 `--user=xxx` 缩小范围。」

### 第 3 步：正式跑 dump

```bash
cd "${BACKEND_DIR}" && uv run python -m app.cli.operator dump <用户的实际参数>
```

成功输出：`✓ 导出完成: /Users/qianli/qy-exports/2026-05-28-1430-user-oABC12/`

### 第 4 步：报告产出

回到 Claude Code 给用户：
- 实际命中行数（dry-run 结果）
- 输出目录路径
- 含哪些文件（md / json / csv 中的几种 + `_manifest.json`）
- 脱敏档位 + for-content 标记（如果是自媒体场景）

---

## 失败兜底

| 场景 | 处理 |
|---|---|
| `find-backend.sh` exit != 0 | stderr 含候选路径，让用户告诉你 backend 实际位置 |
| `ensure-pg.sh` exit != 0 | 按 stderr 提示让用户 `cd deploy && sudo docker compose up -d postgres` 然后重试 |
| typer exit 1（参数错） | 解析 stderr 给用户人类可读建议（如「`--risk-min` 必须是 P0/P1/P2/P3 之一」） |
| typer exit 2（DB 错） | 提示用户检查 `backend/.env` 的 `DATABASE_URL` |
| LLM 替换失败（full） | typer 已 fallback 到 light + stderr warning，**告诉用户**该 dump 是 light 不是 full（如果是 `--for-content`，要明确警告：自媒体不能直接用！） |
| 空结果（命中 0 rows） | typer 已 exit 0 + 不写文件，告诉用户 scope 过严，建议放宽时间窗或去掉某过滤 |

---

## 隐私护栏（与运营人员沟通时一定要复述的红线）

1. **`~/qy-exports/` 永不进 git**：用户级 `~/.config/git/ignore` 加 `qy-exports/`（不是 repo 内的 .gitignore）
2. **`--for-content` 是 audit 标志**：自媒体场景必须用这个 flag 而不是手写 `--anonymize=full`，`_manifest.json` 会永久留痕
3. **不会泄漏 raw user_id**：哪怕 `--anonymize=none`，`user_ref` 也至少是 UUID 前缀（spec §8.6）
4. **chmod 600**：文件写完后自动 `chmod 600`，仅当前用户可读
5. **F3 chart_data 需解密**：`--include-chart` 时，解密 key 从 backend `.env` 走，plugin 本身不接触 key

---

## 参考文档

- 设计 spec：`30-QingYa/docs/superpowers/specs/2026-05-27-operator-plugin-design.md`（**权威源**，含 JSON schema v1.0 契约）
- 实施 plan：`30-QingYa/docs/superpowers/plans/2026-05-27-qy-operator-plugin.md`
- backend dump 实现：`miniapp/backend/app/cli/operator/dump.py`
- 共享底座：`miniapp/backend/app/cli/operator/_query.py` / `_anonymize.py` / `_serialize.py` / `_output.py`
- 使用示例：`references/usage-examples.md`（4 高频场景 + 输出样貌）

---

## 后续 Skill 演进预留

本 Skill 的 JSON 输出（`conversations.json`）按 spec §8 的 schema v1.0 契约，是 single source of truth。后续 3 个 Skill 直接 consume JSON：

```
dump-conversations   →  conversations.json (schema v1.0)
                            ↓
                  stats-report / user-profile / content-analyze
```

加新 Skill 不动 dump，只在 `plugins/qy-operator/skills/` 加新子目录。
