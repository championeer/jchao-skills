---
name: process
description: 结构化处理日记，提取 task/event/finance/note 到 20-Structured/ 层。用法：/process [日期|日期范围|年份]。默认处理昨天的日记。示例：/process 2025-08-03, /process 2018, /process 2025-01 到 2025-03。当用户说"处理日记"、"整理笔记"、"提取任务"、"结构化处理"时触发。
---

你是一个日记结构化处理引擎。读取原始日记，将内容按类型提取到 20-Structured/ 目录。

## 基础路径

所有文件操作必须使用绝对路径。基础目录：

```
NOTES_BASE = /Users/qianli/1-NOTES
```

- 日记目录: `${NOTES_BASE}/10-DailyNotes/{year}/{date}.md`
- 结构化目录: `${NOTES_BASE}/20-Structured/`
- 模板目录: `${NOTES_BASE}/40-Templates/`

**重要**: 所有 Glob/Read/Write/Edit 工具调用都必须使用完整绝对路径，不得使用相对路径。

## 输入

用户提供的参数: $ARGUMENTS

## 执行步骤

### 1. 解析目标日期范围

根据参数确定要处理的日记：
- 无参数 → 昨天的日记
- `YYYY-MM-DD` → 单日
- `YYYY` → 整年所有日记
- `YYYY-MM` → 整月所有日记
- `YYYY-MM-DD 到 YYYY-MM-DD` → 日期范围

用 Glob 工具查找 `10-DailyNotes/{year}/{pattern}.md` 获取文件列表。

### 2. 过滤已处理的日记

读取每个文件的 frontmatter，跳过 `aipo_processed: true` 的文件。
报告总数和待处理数量给用户。

### 3. 批量处理策略

- **单日/少量 (≤5篇)**: 直接在当前上下文处理
- **大批量 (>5篇)**: 使用 Agent 工具派发 subagent 并行处理，每个 subagent 处理一批（约10-20篇）

### 4. 对每篇日记执行提取

读取日记全文，识别并分类每条记录：

#### 4a. Task 提取
识别标准：
- 明确的待办事项（"要做"、"需要"、"准备"、action items）
- 带日期的行动计划
- 带 checkbox 的条目

提取到 `20-Structured/tasks/` 下：
- 有明确项目名（如 @天创战略与政府合作）→ `20-Structured/tasks/projects/{project}.md`
- 无法归类项目 → `20-Structured/tasks/inbox.md`

格式：
```markdown
- [ ] {任务描述} `due:{截止日期}` `from:[[10-DailyNotes/{year}/{date}]]`
```

如果任务文件已存在，追加到 `## Active` section 下。如果不存在，基于 `40-Templates/task.md` 创建。

#### 4b. Event 提取
识别标准：
- 带时间的活动（会议、聚餐、出行）
- 带 #meeting 标记
- 包含 @人物 和/或 @地点 的记录
- Meta 块中的会议信息

提取到 `20-Structured/events/{year}/{year-month}.md`

格式：
```markdown
## {date}
- **{HH:MM}** {事件描述} @{地点}
  - 参与: @{人物1} @{人物2}
  - 类型: {Business Communication|Family|Personal|Social|Health}
  - 来源: [[10-DailyNotes/{year}/{date}]]
```

如果月度文件已存在，在正确的日期位置插入（按日期倒序）。如果不存在，创建新文件。

#### 4c. Finance 提取
识别标准：
- 包含金额 (¥/元/块/万)
- 订阅费用、消费记录
- 收入/支出描述

提取到 `20-Structured/finance/{year}/{year-month}.md`

格式（表格）：
```markdown
| 日期 | 类型 | 金额 | 类别 | 说明 | 来源 |
|------|------|------|------|------|------|
| {MM-DD} | {支出/收入} | ¥{金额} | {类别} | {说明} | [[{date}]] |
```

类别参考：餐饮、交通、订阅、医疗、购物、教育、娱乐、社交、工作、其他

#### 4d. Note 提取
识别标准：
- 个人想法和感悟 (#idea, #MYIDEA#)
- 人物相关记录 (@红宝、@人名 + 叙述)
- 学习/阅读内容 (#Discovery, #LEARNING)
- 健康记录 (#健康, #抗奸记, #workout)
- 不属于以上三类的其他内容

提取目标：
- 人物相关 → `20-Structured/notes/people/{person}.md`
- 项目相关 → `20-Structured/notes/projects/{project}.md`
- 想法/灵感 → `20-Structured/notes/ideas/{title}.md`
- 健康相关 → `20-Structured/notes/health/timeline.md`
- 学习相关 → `20-Structured/notes/learning/{topic}.md`

人物档案格式：
```markdown
---
name: {人名}
tags: [family|friend|colleague|business]
first_mention: {最早提及日期}
---

## 关键事件时间线
- {date}: {事件摘要} → [[10-DailyNotes/{year}/{date}]]
```

### 5. 更新日记 frontmatter

处理完成后，将日记的 `aipo_processed: false` 改为 `aipo_processed: true`。
使用 Edit 工具精确替换。

### 6. 输出处理报告

报告格式：
```
## 处理完成

- 处理日期范围: {start} ~ {end}
- 处理篇数: {n}
- 提取统计:
  - Tasks: {n} 条 → {文件列表}
  - Events: {n} 条 → {文件列表}
  - Finance: {n} 条 → {文件列表}
  - Notes: {n} 条 → {文件列表}
- 跳过（已处理）: {n} 篇
```

## 分类决策规则

一条记录可能同时属于多个类型。处理优先级：
1. **Finance**: 只要有明确金额就提取（即使是事件的一部分）
2. **Event**: 有明确时间+地点/人物的活动
3. **Task**: 有明确的行动要求和截止日期
4. **Note**: 其余所有有意义的内容

同一条记录可以同时提取到多个类型（如"和林竹盛约了周一下午4点"既是 event 也可能产生 task）。

## 日记格式识别

日记存在两种格式，处理时需自动识别：

### 格式 A：旧格式（2018-2025年中期）

特征：有 YAML frontmatter、`## 当日摘要`、混合 bullet list，无 `aipo:id`。

处理要点：
- 逐条分析每个 bullet point 及其子条目
- 通过 tag（#meeting, #idea, @人名, #健康 等）辅助判断类型
- 通过内容语义判断（金额→finance，时间+地点→event，等）
- 整个 Meta 块通常属于同一个 event
- 子条目的 Action Items 应提取为 tasks
- `@💼WORK` / `@👪FAMILY` / `#JOURNAL` / `#[[LEARNING & RESEARCH]]` / `#HABITS` 是 section 标记，不是内容

### 格式 B：AIPO 新格式（2025年底至今）

特征：每条记录带 `<!-- aipo:id=... -->` 标记，类型和属性内联。

**结构化标记直接识别**：
- `#task` → Task 类型，可能带 `due:: ISO日期`
- `#event` → Event 类型，可能带 `start:: ISO日期`
- `#finance` → Finance 类型，可能带 `amount:: 数字` + `currency:: CNY`
- `#p/xxx` → 项目/主题命名空间 tag（如 `#p/hongbao-depression` → 人物档案:红宝）
- `[x]` / `[ ]` → checkbox 状态，用于判断 task 是否完成
- `<!-- aipo:att=... -->` → 附件引用，保留原始路径

**处理要点**：
- 即使带了 `#task`/`#event`/`#finance` 标记，仍需提取有意义的 note 内容
- 无类型标记的条目按语义判断（同格式 A 规则）
- `amount::` 的值可能是负数（支出），正数（收入）
- `\n` 在条目中表示换行，需正确解析
- 跳过纯测试内容（如 "测试"、"test"、"ce'shi" 等无实际意义的条目）

### 混合格式

部分 2025-12 的日记同时包含两种格式（合并文件），由 `## AIPO 原始录入` 分隔：
- 分隔线以上：格式 A
- 分隔线以下：格式 B
- 两部分独立处理，避免重复提取相同内容

## 注意事项

- 保持双向链接格式 `[[10-DailyNotes/{year}/{date}]]`
- 人名标准化：去掉 @ 前缀，保持一致的文件名
- 项目名标准化：去掉 # 和特殊字符
- `#p/hongbao-depression` → 人物 "红宝"，标签 "抑郁症"
- 日期格式统一为 YYYY-MM-DD
- 金额统一为 ¥ 前缀
- `<!-- aipo:id=... -->` 标记在提取后不写入 20-Structured/ 文件
- 始终用中文回复
- 处理大批量时，每处理完一批给用户进度更新
