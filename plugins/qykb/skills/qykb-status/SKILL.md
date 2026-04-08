---
name: qykb-status
description: |
  显示晴芽知识库当前状态概览。统计页面数、类型分布、置信度分布、最近操作。
  触发词：/qykb-status、"知识库状态"、"KB状态"、"qykb status"
---

# qykb-status — 知识库状态概览

## 用法

```
/qykb-status
```

## 工作目录

```
KB_ROOT=/Users/qianli/0-WORKSPACE/30-QingYa/产品/QingYa-Knowledge
```

## Interaction Flow

### Step 1: 收集统计

1. 读取 `$KB_ROOT/index.md` 获取页面统计（如不存在，先运行 rebuild_index.py）
2. 统计 `wiki/` 下各子目录文件数：
   ```bash
   find "$KB_ROOT/wiki" -name "*.md" | wc -l
   ```
3. 统计 `content-seeds/` 下文件数
4. 用 grep 统计 confidence 分布：
   ```bash
   grep -r "^confidence:" "$KB_ROOT/wiki/" | sort | uniq -c
   ```

### Step 2: 读取最近操作

读取 `$KB_ROOT/log.md` 最后 5 条记录。

### Step 3: 检查待处理素材

扫描 `$KB_ROOT/raw/` 下来源摘要页，找出 `ingest_status: partial` 或 `ingest_status: pending` 的来源。

### Step 4: 输出报告

格式：

```
晴芽知识库状态
==============
Wiki 页面：{total} 个
  概念 {n} | 指南 {n} | 案例 {n} | 话术 {n}
置信度：llm-draft {n} | verified {n}
内容种子：{n} 个

最近操作：
  [日期] 操作 | 来源
  ...

待处理：
  {source} — {status}
  ...
```
