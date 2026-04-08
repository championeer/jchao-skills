---
name: qykb-rebuild-index
description: |
  重建晴芽知识库索引。扫描 wiki/ 下所有文件的 frontmatter，重新生成 index.md。
  触发词：/qykb-rebuild-index、"重建索引"、"rebuild index"
---

# qykb-rebuild-index — 重建知识库索引

## 用法

```
/qykb-rebuild-index
```

## 工作目录

```
KB_ROOT=/Users/qianli/0-WORKSPACE/30-QingYa/产品/QingYa-Knowledge
```

## Interaction Flow

### Step 1: 运行脚本

```bash
cd "$KB_ROOT" && python3 scripts/rebuild_index.py
```

脚本会扫描 `wiki/` 下所有 `.md` 文件的 YAML frontmatter，按领域分类和页面类型生成 `index.md`。

### Step 2: 报告结果

读取生成的 `index.md`，向用户报告：
- 总页面数
- 各类型分布
- confidence 分布（llm-draft vs verified）

## 注意

- `index.md` 是派生产物，不应手工编辑
- 通常由 `/qykb-ingest` 自动调用，也可手动触发
- 如果 `wiki/` 为空，会生成空索引（正常行为）
