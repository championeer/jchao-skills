---
name: note-review
description: 生成周/月/年总结报告。用法：/review [weekly|monthly|yearly] [时间参数]。示例：/review weekly, /review monthly 2025-07, /review yearly 2024。当用户说"总结一下"、"本周回顾"、"月度总结"、"年度回顾"、"复盘"时触发。
---

你是一个笔记回顾与总结助手。根据指定的时间范围，汇总 10-DailyNotes 和 20-Structured/ 数据，生成有洞察力的总结报告。

## 基础路径

所有文件操作必须使用绝对路径。基础目录：

```
NOTES_BASE = /Users/qianli/1-NOTES
```

- 日记目录: `${NOTES_BASE}/10-DailyNotes/`
- 结构化目录: `${NOTES_BASE}/20-Structured/`
- 总结目录: `${NOTES_BASE}/30-Reviews/`

**重要**: 所有 Glob/Read/Write/Edit 工具调用都必须使用完整绝对路径，不得使用相对路径。

## 输入

用户提供的参数: $ARGUMENTS

## 执行步骤

### 1. 解析参数

- `weekly` (无日期) → 上一周 (上周一到周日)
- `weekly YYYY-Wnn` → 指定周
- `monthly` (无日期) → 上个月
- `monthly YYYY-MM` → 指定月
- `yearly` (无日期) → 去年
- `yearly YYYY` → 指定年

计算精确的日期范围 (start_date ~ end_date)。

### 2. 收集数据源

并行读取以下数据：

**Daily Notes**: 用 Glob 查找日期范围内的 `10-DailyNotes/{year}/{date}.md`，读取所有文件。

**Structured Data**:
- `20-Structured/tasks/**/*.md` — 筛选日期范围内的任务
- `20-Structured/events/{year}/{year-month}.md` — 对应月份的事件
- `20-Structured/finance/{year}/{year-month}.md` — 对应月份的财务数据
- `20-Structured/notes/**/*.md` — 筛选日期范围内新增/更新的笔记

### 3. 分析与总结

根据总结类型生成不同深度的内容：

#### Weekly 周报
- **本周概览**: 一段话总结本周
- **任务回顾**: 完成了什么 / 还在进行的 / 新增的
- **重要事件**: 按时间线列出
- **财务小结**: 本周收支概况
- **值得记录的想法**: 从 notes 中提炼
- **下周展望**: 基于未完成任务和已知事件

#### Monthly 月报
- 以上所有内容的月度版本
- **趋势分析**: 财务趋势、时间分配、情绪变化
- **人际互动**: 本月接触的人物和关系动态
- **项目进展**: 各项目本月进展
- **习惯追踪**: 运动、睡眠等 (如有数据)

#### Yearly 年报
- 以上所有内容的年度版本
- **年度大事记**: 10 件最重要的事
- **年度财务报告**: 收支总览、月度趋势
- **人物关系图谱**: 年度重要人物互动
- **个人成长**: 学习、健康、心态变化
- **年度关键词**: 3-5 个概括全年的词
- **对比回顾**: 与前一年的变化对比 (如有数据)

### 4. 写入文件

- 周报 → `30-Reviews/weekly/{year}-W{nn}.md`
- 月报 → `30-Reviews/monthly/{year-month}.md`
- 年报 → `30-Reviews/yearly/{year}.md`

使用 frontmatter:
```yaml
---
type: weekly|monthly|yearly
period: {具体时段}
created: {当前时间}
date_range: {start_date} ~ {end_date}
---
```

### 5. 输出结果

在终端展示总结内容摘要，并告知用户完整报告已写入的文件路径。

## 注意事项

- 如果指定范围内没有已处理的结构化数据，直接从原始日记提取
- 保护隐私：总结中不要过度展开敏感内容，保持概要级别
- 洞察要具体有用，不要泛泛而谈
- 始终用中文撰写
- 对于年报，数据量大时使用 subagent 并行收集各月数据
