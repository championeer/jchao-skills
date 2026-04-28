---
name: xhs-review
description: |
  晴芽小红书 autoresearch 外循环复盘器。把发布后的真实反馈（小红书数据 + Charlie 观察 + 平台判定）转化为规则迭代——主要更新 visual-system / scoring-rubric / account-profile，让下一篇内容跑得比上一篇好。
  触发方式：/xhs-review、「跑复盘」「review 一下小红书」「复盘篇 X」「该校准 rubric 了」
  Triggers: weekly Sunday 22:00 schedule / accumulated 3+ posts / real-time feedback (data anomaly, platform action, Charlie observation).
---

# xhs-review：小红书 autoresearch 外循环复盘器

你是晴芽小红书账号的**外循环复盘器**。你的任务不是写新内容，而是**把已发布内容的真实反馈转化为规则迭代**——让下一篇的内循环（`xhs-create`）跑得更准。

**外循环的核心价值：1 次真实反馈驱动的规则更新 >> N 轮内循环评分迭代。**

实战证据：
- v0.1 → v0.2（Charlie 用 GPT-Image-2 实测发现 v0.1 字体/logo 偏差）
- v0.2 → v0.3（篇 A 发布被小红书判定 AI，触发 5 层识别风险闸门）

---

## 一句话定义

`xhs-review` 是把"小红书已经发生的真实事情"翻译成"`xhs-create` 下一次该怎么做"的翻译器。

输入：发布后的数据 + 反馈 + 平台动作
输出：`visual-system.md` / `scoring-rubric.md` / `account-profile.md` 的版本升级 + `calibration-v0.1.md` baseline 追加

---

## 核心参考文档（必读）

每次运行前读这 4 份（在 `../shared/`）：

| 文件 | 作用 | 读取时机 |
|---|---|---|
| `account-profile.md` | 人设基线（升级要慎重） | 每次开始 |
| `scoring-rubric.md` | 评分规则（最常被升级） | 每次开始 |
| `visual-system.md` | 视觉规范（被实物 + 平台反馈频繁触发） | 每次开始 |
| `calibration-v0.1.md` | 历史校准 baseline + 元教训（核心参考） | 每次开始 |

**永远先读 calibration**——它是过往外循环执行的"实战手册"。

---

## 什么时候用

### 触发条件（任一即触发）

| 触发类型 | 具体场景 | 实战例子 |
|---|---|---|
| **定时**（schedule） | 每周日 22:00 自动跑 | 未来 Phase 3 接入 |
| **累计篇数** | 累计发布 3/5/10 篇里程碑 | 篇 A+B+C 后第一次系统性复盘 |
| **真实反馈** | Charlie 主动反馈 / 数据异常 / 平台动作 | 篇 A 发布后 Charlie 反馈 2 问题（v0.3 触发） |
| **数据节点** | 单篇 24h / 7d 数据回流 | 跑 `opencli xiaohongshu creator-note-detail <id>` 之后 |

### 不适用场景（转给别的 skill）

- 写新内容 → `xhs-create`
- 修改单篇文字 → 直接 Edit 草稿
- 单点视觉调整 → 直接改 visual-system.md（不用 review 流程）
- 安全合规审 → safety-guard.md（一次审一次）

---

## 5-Phase 流程（基于 v0.2→v0.3 实战编码）

```
[Trigger]→[Collect]→[Diagnose]→[Iterate]→[Document]
   ↑          ↑          ↑          ↑          ↑
触发条件   数据收集   根因诊断   规则修订   沉淀留痕
```

---

## Phase 1 — [Trigger] 确认触发原因

### 1.1 列出本次触发上下文

每次启动先明确 3 件事：

1. **触发类型**：定时 / 累计篇数 / 真实反馈 / 数据节点
2. **覆盖范围**：复盘全部已发布篇 / 单篇深度 / 某主题集合
3. **预期产出类型**：rubric 升级 / visual 升级 / account-profile 升级 / 新闸门 / 新维度 / 仅诊断报告

### 1.2 起 review session 临时报告

新建 `内容/小红书/规律沉淀-YYYY-MM-DD-<触发关键词>.md`，结构化记录本次 review。完成后整理进 `规律沉淀.md` 主文档。

---

## Phase 2 — [Collect] 数据 + 反馈收集

### 2.1 opencli 拉数据（如已发布）

```bash
# 单篇详情（含观看来源、观众画像、趋势）
opencli xiaohongshu creator-note-detail <note-id> -f json

# 创作者总览（涨粉/累计数据）
opencli xiaohongshu creator-stats --days 7 -f json

# 笔记列表对比
opencli xiaohongshu creator-notes -f json
```

数据字段重点关注：
- 阅读 / 点赞 / 收藏 / 评论 / **关注**（涨粉）
- 观看来源（推荐 / 搜索 / 主页 / 关注）
- 观众画像（年龄 / 性别 / 城市）
- **是否被限流 / AI 判定 / 违规警告**

### 2.2 Charlie 主观反馈

询问或归档 Charlie 提到的问题（实战 v0.2→v0.3 触发原因）：
- "配图字看不清" → 视觉问题
- "被判定 AI" → 平台规则问题
- "评论里有人说..." → 共鸣方向
- "我感觉 X 选题没共鸣" → 选题方向

### 2.3 平台动作信号

- 笔记是否被推荐（feed 流是否能搜到）
- 是否触发"创作者中心"提示
- 是否被推送给关注者
- 限流的形态（明显限流 / 隐性低权重）

### 2.4 写入临时报告

```markdown
## Collect 阶段 (YYYY-MM-DD)

### 数据快照
- 篇 X (id: xxx)：阅读 X / 点赞 X / 收藏 X / 评论 X / 关注 +X
- 关注率：X% (vs 预期 Y%)

### Charlie 反馈
- 问题 1：...
- 问题 2：...

### 平台动作
- 是否限流：...
- AI 判定：...
```

---

## Phase 3 — [Diagnose] 根因诊断

### 3.1 实际 vs 预期对照（最重要）

每篇都要做这个表，找差距：

| 指标 | 预期（calibration §8.5） | 实际 | 偏差 % | 信号方向 |
|---|---|---|---|---|
| 关注率 | 2.5% | 1.0% | -60% | 🔴 严重 |
| 收藏率 | 6% | 5% | -17% | 🟡 接近 |
| 涨粉数 | 50 | 15 | -70% | 🔴 严重 |

偏差 > 50% → 必有规范盲区。

### 3.2 找盲区（结构化诊断）

按"v0.3 实战学到的多层信号分析"框架，逐层问：

1. **图像层**：封面 / 配图是否触发了某种平台识别？
2. **文本层**：结构化程度 / 术语密度 / AI 痕迹？
3. **视觉可读性层**：feed 流缩略图能看清吗？
4. **账号层**：账号热度 / 历史一致性？
5. **行为层**：发布时间 / 互动频率 / 标签策略？
6. **共鸣层**：选题是否真的戳中目标家长？
7. **真实性层**：哪部分是虚构 / 文学化 / 非真实事件？

### 3.3 反常识发现（外循环最大价值）

特别关注**预测 vs 实际反向**的样本：
- 预测高分但实际表现差 → rubric 高估了某维度
- 预测低分但实际涨粉好 → rubric 低估了某维度

这是 rubric 权重调整的核心数据。

### 3.4 输出诊断报告

```markdown
## Diagnose 阶段

### 数据偏差
- 关注率 -60%，原因推测：① ... ② ...

### 识别的盲区
- 盲区 1：rubric / visual-system 当前没覆盖 X 维度
- 盲区 2：...

### 反常识信号
- 篇 X 评分低但实际表现好，原因：...

### 待迭代规则清单（带优先级）
- [P0] visual-system §X 改 Y
- [P1] scoring-rubric §X 加 Z 维度
- [P2] account-profile §X 调整人设描述
```

---

## Phase 4 — [Iterate] 规则修订

### 4.1 决定升级哪些文件

按 §3.4 的"待迭代规则清单"，每条对应一个文件 + 章节定位。

**修订原则**（按 v0.3 实战经验）：
- 一次外循环可以同时升级多个文件（v0.3 同时改了 visual-system + scoring-rubric + calibration）
- 但**不要修人设基线 account-profile.md**（除非真有人设级偏差）—— 人设是稳定锚
- 主要战场：scoring-rubric（评分规则） + visual-system（视觉规范）

### 4.2 版本管理规则

- 大改（新增维度/闸门/章节）→ 主版本 +0.1（v0.2 → v0.3）
- 小改（参数微调/案例追加）→ 留在当前版本，§变更记录留痕
- 极小改（笔误/链接修正）→ 直接改不留痕

### 4.3 修订必须包含的元素

每次升级在文件 §变更记录写：
- 日期 + 新版本号
- 改了什么（具体到章节）
- **触发原因**（哪条反馈/数据/盲区）
- 数据/反馈来源（哪条 Charlie 反馈、哪个篇的数据）

### 4.4 同步影响其他文件

修了 scoring-rubric → 检查 xhs-create/SKILL.md Phase 4 是否需要改
修了 visual-system → 检查 xhs-create/SKILL.md Phase 6 是否需要改
修了 account-profile → 极少发生，发生则全 skill 重审

---

## Phase 5 — [Document] 沉淀留痕

### 5.1 必做 4 件事

| # | 动作 | 位置 |
|---|---|---|
| 1 | 追加 baseline + 元教训 | `shared/calibration-v0.1.md` 新章节 |
| 2 | 业务日志记录 | `营销运营/日志.md` 加 `[复盘]` 标签 |
| 3 | 技术日志记录 | `30-QingYa/logs/content.md` 加 `[ops]` 标签 |
| 4 | 任务跟进 | `tasks/todo.md` 加新增的待执行动作 |

### 5.2 重要外循环额外加 1 件

如本次外循环涉及**结构性盲区发现**（如 v0.3 的 AI 识别风险），写一份 handoff 文档：
`30-QingYa/handoffs/YYMMDD-handoff-N.md`

模板参考 `handoffs/260424-handoff-9.md`（v0.2→v0.3 实战）。

### 5.3 输出整理到规律沉淀主档

把本次 review 的临时报告（`规律沉淀-YYYY-MM-DD-...md`）整理后追加到主档 `内容/小红书/规律沉淀.md`，按以下结构：

```markdown
## YYYY-MM-DD 第 N 次外循环复盘

**触发**：...
**覆盖**：...
**核心发现**：1-3 句话
**规则升级**：visual-system → vX.X / scoring-rubric → vX.X / ...
**详细记录**：链接到对应 calibration 章节
**下次重点**：...
```

---

## 常见问题与边界

### Q1：单篇数据回流了，要立即 review 吗？
→ **24h 数据**做轻 review（Phase 1-2 即可，不一定动规则）。**7d 数据**做完整 review（5-Phase 全跑）。

### Q2：每周日定时 review 没数据怎么办？
→ 跳过本次（写一行"无新发布，无数据，跳过"到 logs）。下周再跑。

### Q3：发现的盲区跨多个文件，怎么协调？
→ 一次外循环改多文件没问题（v0.3 改了 3 份）。用 §变更记录的"触发原因"字段串起来。

### Q4：升级 rubric 后历史篇要重新评分吗？
→ **不强制**。但可以做"回溯评估"作为 baseline 记录（v0.3 的篇 A 84 分回溯就是这种）。

### Q5：Charlie 反馈和数据冲突怎么办？
→ 数据为主，Charlie 反馈作为信号。但**Charlie 反馈往往揭示数据看不到的维度**（如 v0.3 的 feed 流可读性，数据只显示低 CTR，不告诉你"字看不清"）。

### Q6：规则越改越复杂怎么办？
→ 警惕"过拟合到单篇"。每个新维度/闸门都要问"未来其他篇会不会也用得上？"如果是孤例就不沉淀进规则，只在 calibration 留案例。

### Q7：xhs-review 自身要不要 review？
→ 是的。每跑 5-10 次 review 后，反思本 skill 的流程是否需要升级（5-Phase 是否合理？触发条件是否齐全？）。

---

## 与其他 skills 的关系

| Skill | 角色 | 与 xhs-review 的关系 |
|---|---|---|
| `xhs-create` | 内循环（per post） | xhs-review 的产出（规则迭代）→ 修改 xhs-create 用的规范 |
| `dbs-content` | 内容诊断 | xhs-review 不直接调用，但诊断框架可借鉴 |
| `dbs-benchmark` | 对标搜索 | review 时跑对标看竞品同期数据（可选） |
| `opencli xiaohongshu` | 数据拉取 | xhs-review 的核心工具 |

---

## 启动模板（运行本 skill 时的第一条输出）

```
🔄 xhs-review — 小红书 autoresearch 外循环复盘

正在读取（4 份核心参考文档）：
- shared/account-profile.md (人设基线)
- shared/scoring-rubric.md (当前 vX.X)
- shared/visual-system.md (当前 vX.X)
- shared/calibration-v0.1.md (历史 baseline + 元教训)

Phase 1 — Trigger：请告诉我本次复盘触发：
  [1] 定时（每周日 22:00）
  [2] 累计 3+ 篇里程碑
  [3] Charlie 真实反馈（口头/书面）
  [4] 单篇数据节点（24h / 7d 数据回流后）
  [5] 平台动作（限流/警告/AI 判定）
  [6] 其他（请说明）

覆盖范围（哪些篇 / 全部）：
预期产出（仅诊断 / rubric 升级 / visual 升级 / 多文件升级）：
```

---

## 历史外循环执行记录

### #1：2026-04-24 v0.1 → v0.2（实物驱动）
- **触发**：Charlie 用 GPT-Image-2 生成篇 A 封面，实物效果跟 v0.1 规范字体/logo 不一致
- **诊断**：v0.1 规范臆测了"方正喵呜体 + 彩色 logo"，实物用"硬笔手写 + 文字闲章"更贴调性
- **升级**：visual-system v0.1 → v0.2（字体概念化 / logo 双轨 / 暖色降级）
- **沉淀**：calibration §8 baseline + handoff-7

### #2：2026-04-24 v0.2 → v0.3（真实反馈驱动 · 里程碑）
- **触发**：篇 A 发布后 Charlie 反馈 2 真实问题（feed 字小 + 被判 AI）
- **诊断**：v0.2 两个结构性盲区（feed 流可读性 + AI 识别 5 层信号）
- **升级**：visual-system v0.2 → v0.3（5 点修订 + §13 手工 SOP） + scoring-rubric v0.2 → v0.3（新增 §2.3 AI 识别风险闸门）
- **沉淀**：calibration §8-9 + handoff-9

---

## 变更记录

| 日期 | 版本 | 变更 | 触发 |
|---|---|---|---|
| 2026-04-24 | v0.1 | 初稿 SKILL.md：5-Phase 流程 + 启动模板 + 历史 2 次外循环案例 | Charlie 提醒"xhs-review 还没创建"，借此把已实战 2 次的外循环逻辑流程化沉淀 |
