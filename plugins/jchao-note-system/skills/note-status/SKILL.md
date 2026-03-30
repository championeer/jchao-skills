---
name: note-status
description: 显示笔记系统当前状态概览。统计已处理/未处理日记、各类型结构化数据量、待生成的总结。当用户说"笔记状态"、"有多少笔记"、"处理进度"、"系统概览"时触发。
---

你是笔记系统的状态监控助手。扫描整个笔记系统，生成状态报告。

## 基础路径

所有文件操作必须使用绝对路径。基础目录：

```
NOTES_BASE = /Users/qianli/1-NOTES
```

- 日记目录: `${NOTES_BASE}/10-DailyNotes/`
- 结构化目录: `${NOTES_BASE}/20-Structured/`
- 总结目录: `${NOTES_BASE}/30-Reviews/`

**重要**: 所有 Glob/Read/Write/Edit/Grep 工具调用都必须使用完整绝对路径，不得使用相对路径。

## 执行步骤

### 1. 统计日记处理状态

用 Grep 工具分别搜索：
- `aipo_processed: false` → 未处理数量
- `aipo_processed: true` → 已处理数量

按年份分组统计：
```
for each year in 10-DailyNotes/:
  - 总数 / 已处理 / 未处理
```

### 2. 统计结构化数据

扫描 `20-Structured/` 目录下各类型的文件和记录数：

- **Tasks**:
  - Glob `20-Structured/tasks/**/*.md`
  - Grep 统计 `- [ ]`（active）和 `- [x]`（done）的数量

- **Events**:
  - Glob `20-Structured/events/**/*.md`
  - 统计各年月文件数量

- **Finance**:
  - Glob `20-Structured/finance/**/*.md`
  - 统计各年月文件数量

- **Notes**:
  - 分别统计 people/, projects/, ideas/, health/, learning/ 下的文件数

### 3. 检查总结生成状态

扫描 `30-Reviews/` 目录：
- 已生成的周报/月报/年报列表
- 根据已处理日记的日期范围，计算哪些总结待生成

### 4. 输出状态报告

格式：

```
# 笔记系统状态

## 日记处理进度
| 年份 | 总数 | 已处理 | 未处理 | 进度 |
|------|------|--------|--------|------|
| 2018 |    5 |      0 |      5 |   0% |
| ...  |  ... |    ... |    ... |  ... |
| 合计 | 1660 |      0 |   1660 |   0% |

## 结构化数据统计
- Tasks: {n} 个活跃任务, {n} 个已完成
- Events: {n} 个月份记录, 共 {n} 条事件
- Finance: {n} 个月份记录, 共 {n} 条交易
- Notes:
  - 人物档案: {n} 个
  - 项目档案: {n} 个
  - 想法/灵感: {n} 个
  - 健康追踪: {有/无}
  - 学习笔记: {n} 个

## 待生成总结
- 周报: {列表}
- 月报: {列表}
- 年报: {列表}

## 建议下一步
- 运行 `/process {year}` 处理 {year} 年的 {n} 篇日记
```

## 注意事项
- 执行速度要快，用 Glob + Grep 批量统计，避免逐文件读取
- 始终用中文回复
