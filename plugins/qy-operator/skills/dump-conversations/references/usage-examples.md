# dump-conversations 使用示例

按 spec §6.2 的 4 个高频运营场景，每个给出**实际命令 + 输出样貌**。

---

## 场景 1：单用户 30 天完整对话（自己复盘）

**何时用**：某个用户最近反馈 / 客服跟进 / 想看自己跟这个用户对话的整体情况。

```bash
/qy-dump --user=oABC123 --since=2026-04-27
# 等价于：light 脱敏 + md 格式（都是 default）
```

**输出目录**：

```
~/qy-exports/2026-05-27-1430-user-oABC12/
├── conversations.md       # 人类可读（jinja2 渲染）
├── conversations.json     # 结构化 single source of truth
└── _manifest.json         # scope + anonymize 元数据
```

**`conversations.md` 长这样**：

```markdown
# 用户 u_oABC12 对话导出

**导出范围**：2026-04-27 → 2026-05-27（30 天）
**脱敏档位**：light
**会话数**：12 | **消息数**：234 | **高风险**：2

---

## Session 1: 2026-05-20 19:00 — 19:42（42 分钟）

**Skill**：xiaoqing-action-card / **Scene**：school-reentry
**情绪**：anxious / **风险**：P1

### 对话
**用户**：我家娃明天又要去学校了，我特别紧张...
**晴芽**：你的紧张是真实的。明天早晨可以试试...

### 产出 Action Card
- 类型：action-card / 情绪：anxious / 风险：P1
- 内容：...
```

---

## 场景 2：本周高风险事件 dump（合规 / 安全审计）

**何时用**：每周固定时间盘点本周 P1+ 高风险事件、检查 LLM 路由是否合理、安全审计。

```bash
/qy-dump --since=2026-05-20 --risk-min=P1 --include-request-stats
# 不限 user，跨用户拉所有 risk_level >= P1 的 action cards
# --include-request-stats 附加 LLM 调用统计（路由情况 / 模型版本 / 失败率）
```

**输出特点**：

- `conversations.json` 含每条 `action_card` 的 `risk_level` + 完整 `card_content`
- `conversations.md` 按 session 时间倒序排，标题就是 `Session 1: ... 风险：P1`
- 多一个聚合视图：哪些 user / 哪个 skill / 哪种 emotion 集中产生高风险（`users[]` 顶层有 `high_risk_count`）

**典型命中规模**：8-30 sessions / 周，文件总大小 < 1 MB。

---

## 场景 3：自媒体素材采集（**强锁 full 脱敏 + audit 留痕**）

**何时用**：用对话内容写公众号 / 视频号 / 小红书。**必须用 `--for-content`** 而不是手写 `--anonymize=full`！

```bash
/qy-dump --since=2026-05-20 --keyword=住院 --for-content
# --for-content 强锁 anonymize=full + format=md
# 即使你写了 --anonymize=none --format=json 也会被覆盖
```

**为什么必须 `--for-content` 而不是 `--anonymize=full`**：

| 区别 | `--anonymize=full` | `--for-content` |
|---|---|---|
| 脱敏档位 | full | full（强锁） |
| 格式 | 你指定的 | md（强锁） |
| audit 留痕 | **无** | `_manifest.json.for_content_purpose=true` + `triggered_at` |
| 用途声明 | 没声明 | 永久声明是自媒体场景 |

`for_content_purpose=true` 是**永久 audit 痕迹**，将来回溯「这条内容里用过哪些素材」必须靠这个字段。

**输出特点**：

- 家人姓名 / 医院名 / 学校名 / 地址全部被 LLM 替换为 `<家人A>` `<某医院>` 等
- 同一 dump 内多次出现的「家人 A」永远是同一个人（缓存到 `_anonymize_cache.json`）
- 跨次 dump 不复用缓存（每次重建，防止把同一家人在不同篇文章里写串）

**典型工作流**：

```bash
# Step 1: dry-run 看命中
/qy-dump --since=2026-05-20 --keyword=住院 --dry-run
# Dry run: 命中 47 rows (users=3, sessions=8, messages=31, action_cards=5)

# Step 2: 确认范围合理后 for-content 正式跑
/qy-dump --since=2026-05-20 --keyword=住院 --for-content
# ✓ 导出完成: /Users/qianli/qy-exports/2026-05-28-0930-kw/
# (注意：scope_hint 不会泄漏 keyword 原文，只标 "kw"，防文件名泄漏)
```

---

## 场景 4：二次分析喂 Jupyter（json 格式 + 无脱敏）

**何时用**：要做数据分析（情绪分布 / Skill 使用率 / 时段分布），需要可程序消费的 json + 原始 user_id 关联。

```bash
/qy-dump --since=2026-05-20 --format=json --anonymize=none \
         --output=~/qy-analysis/2026-W21/
# --anonymize=none 仍保留 user_ref（UUID 前缀），不返回 raw openid
# --output 改到分析目录而非默认 ~/qy-exports/
```

**输出**：

```
~/qy-analysis/2026-W21/
├── conversations.json     # 完整 schema v1.0 数据（spec §8）
└── _manifest.json
```

**典型 Jupyter 消费**：

```python
import json
import pandas as pd

with open(Path.home() / "qy-analysis" / "2026-W21" / "conversations.json") as f:
    data = json.load(f)

# DataFrame 化
sessions_df = pd.DataFrame(data["sessions"])
sessions_df["created_at"] = pd.to_datetime(sessions_df["created_at"])

# 情绪分布
sessions_df["dominant_emotion"].value_counts()
```

**注意**：即使 `--anonymize=none`，输出里 **没有** raw openid（spec §8.6）。如果分析必须有 raw openid，需要写 SQL 直查 postgres（不是 dump 命令的职责）。

---

## 跨场景通用：dry-run 习惯

任何带过滤的 dump，**优先 dry-run**：

```bash
/qy-dump <你的实际参数> --dry-run
# Dry run: 命中 N rows (users=X, sessions=Y, messages=Z, action_cards=W)
```

发现命中过多（> 5000 rows）或过少（< 5 rows）时，调整参数再正式跑，避免：
- 命中过多：dump 文件巨大 + 跑 LLM full 脱敏慢且贵
- 命中过少：scope 写错了浪费时间

---

## 调试 / 排错速查

| 现象 | 处理 |
|---|---|
| `❌ DB 连接失败` (exit 2) | `cd ~/0-WORKSPACE/30-QingYa/产品/miniapp/deploy && sudo docker compose up -d postgres` |
| `❌ 非法 --anonymize 值` (exit 1) | 改用 `none` / `light` / `full` 三个值之一 |
| `❌ 参数校验失败: risk_min must be in...` (exit 1) | `--risk-min` 必须是 `P0` / `P1` / `P2` / `P3` |
| stderr `⚠️ LLM 调用失败，降级 light` | DashScope 不可用，输出实际是 light 而不是 full。**自媒体场景禁止使用此次产出** |
| `⚠️ 空结果（命中 0 rows）` | scope 太严，放宽 since/until 或去掉过滤条件 |
| 输出目录已存在 | 上一次同 scope_hint 的 dump 还在，加 `--output=/path/new` 显式指定 |
