---
name: qykb-query
description: |
  查询晴芽知识库，综合多个 Wiki 页面回答问题。可选将优质回答归档为新页面。
  触发词：/qykb-query、"查知识库"、"KB里有没有"、"知识库里关于"
---

# qykb-query — 知识库查询

## 用法

```
/qykb-query <question> [--save]
```

- `--save`：将回答归档为新的 Wiki 页面

## 工作目录

```
KB_ROOT=/Users/qianli/0-WORKSPACE/30-QingYa/产品/QingYa-Knowledge
```

## Interaction Flow

### Step 1: 搜索相关页面

1. 读取 `$KB_ROOT/index.md` 了解全局结构
2. 从问题中提取关键词
3. 用 Grep 搜索 wiki/ 下匹配的页面（搜索 title、aliases、正文）
4. 按相关度排序，取 Top 5-10 个页面

### Step 2: 读取并综合

1. 读取相关页面全文
2. 综合回答用户问题
3. 每个知识点附来源引用（页面 ID + 原始来源）

### Step 3: 可选归档（--save）

如果用户指定 `--save` 或回答质量高值得沉淀：

1. 判断应创建概念页还是指南页
2. 按 CLAUDE.md 规范创建新页面（confidence: llm-draft）
3. 建立交叉引用
4. 运行 rebuild_index.py
5. git commit

### 输出格式

```
根据知识库中 {n} 个相关页面：

{综合回答}

来源：
- [概念名](wiki/concepts/concept-xxx.md)（来自 course/01）
- [指南名](wiki/guides/guide-xxx.md)（来自 book-xxx）
```
