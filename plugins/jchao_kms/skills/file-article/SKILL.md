---
name: file-article
description: 将 Clippings 中的文章归档到知识库。触发词："归档"、"入库"、"file article"、"整理 clippings"、"/file-article"。支持单篇（指定文件名）和批量（无参数处理全部）两种模式。
---

# file-article — 知识库文章归档

将 Clippings/ 中的 .md 文章自动分类、归档到知识库正确位置。

## 知识库路径

```
KB_ROOT = /Users/qianli/0-WORKSPACE/50-Knowledge
```

以下所有路径均相对于 `KB_ROOT`。执行任何操作前，先确认该目录存在。

## 触发方式

| 用法 | 行为 |
|------|------|
| `/file-article 文件名.md` | 处理 Clippings/ 下指定文件 |
| `/file-article` (无参数) | 处理 Clippings/ 下所有未归档 .md |

## 前置条件

确认工作目录为知识库根目录（含 CLASSIFICATION.md、AGENTS.md、_index/）。

## 批量模式流程

### Step 1: 扫描 Clippings

```bash
ls Clippings/*.md
```

排除以下非文章文件：
- `CLAUDE.md`
- `CLASSIFICATION.md`
- `README.md`

### Step 2: 去重检测

提取所有文件的 YAML frontmatter `source` 字段，检测相同 URL。如有重复，保留内容更完整的版本（优先双语版），标记另一个为跳过。

### Step 3: 逐篇归档

对每篇文件执行**单篇归档流程**（见下方）。

### Step 4: 更新 README

```bash
python3 kb-index-gen.sh
```

### Step 5: 输出汇总

输出归档结果表格：

```markdown
| # | 原文件 | 归档路径 | 状态 |
|---|--------|---------|------|
| 1 | xxx.md | 01-AI-Agents/Architecture/xxx/ | 完成 |
| 2 | yyy.md | -- | 跳过（重复） |
```

## 单篇归档流程

### 1. 读取文件

读取 `Clippings/<文件名>` 的完整内容，解析 YAML frontmatter：

```yaml
---
title: "..."
source: "..."
author:
  - "[[Author Name]]"
published: 2026-01-01
created: 2026-01-01
description: "..."
tags:
  - "clippings"
---
```

### 2. 分类

读取 `CLASSIFICATION.md` 的决策树，按顺序判断：

```
1. 构建/配置/运营 AI Agent？ → 01-AI-Agents（选子分类）
2. 给 Agent 加技能/插件/接平台？ → 02-AI-Skills-and-Plugins
3. Claude Code 工具本身？ → 03-Claude-Code
4. API 中转/部署/Token 优化？ → 04-AI-Infrastructure
5. 应用场景为主的 AI 实操？ → 05-AI-Applications
6. LLM 理论/研究/架构？ → 06-LLM-Foundations
7. 通用软件工程（非 AI）？ → 07-Software-Engineering
8. 思维模型/方法论？ → 10-Thinking-Models
9-15. 其他分类...
```

子分类速查（有子分类的分类）：

| 分类 | 子分类 |
|------|--------|
| 01-AI-Agents | Architecture, Memory, Multi-Agent, Training, Workflows |
| 02-AI-Skills-and-Plugins | Skills, Plugins, Integrations |
| 03-Claude-Code | Tutorials, Environment, Scraping |
| 04-AI-Infrastructure | API-Proxy, Optimization |
| 05-AI-Applications | Content-Creation, Research, Finance-Tools |
| 20-Investment | Fundamentals, Analysis, Macro, Commentary |

其余分类（06, 07, 10-13, 21, 22, 30）无子分类，文章目录直接在分类下。

### 3. 命名

根据标题和内容生成中文短名（4-15 字），概括文章核心内容。

### 4. 创建目录和文件

```bash
mkdir -p <分类>/[<子分类>/]<中文短名>/
```

**index.md** — 原始文件内容完整复制（含 YAML frontmatter），不做任何修改。

**metadata.json** — 从 frontmatter 提取：

```json
{
  "title": "<frontmatter.title>",
  "type": "article",
  "source": "<frontmatter.source>",
  "author": "<frontmatter.author，去除 [[ ]] 标记>",
  "clipped_date": "<frontmatter.created，格式 YYYY-MM-DD>",
  "tags": ["从内容提取 2-3 个主题标签"],
  "original_filename": "<原始文件名.md>"
}
```

### 5. 英文翻译

**判断**：检查正文内容（忽略 frontmatter）是否主体为英文。

**如果是英文**：启动一个 subagent（使用 haiku 模型）进行翻译：
- 读取 index.md
- 保留 YAML frontmatter 不变
- 将正文翻译为中文，保持 markdown 格式、标题层级、代码块、链接不变
- 写入同目录下的 `index-zh.md`

subagent prompt 模板：

```
你是专业翻译。将以下 markdown 文章从英文翻译为中文。

规则：
- 保留 YAML frontmatter（--- 之间的内容）完全不变
- 翻译正文为流畅的中文
- 保持 markdown 格式：标题层级、粗体、列表、代码块、链接不变
- 代码块内容不翻译
- 专有名词首次出现保留英文原文，如：强化学习（Reinforcement Learning）

文件路径：<path>/index.md
输出路径：<path>/index-zh.md
```

### 6. 删除原始 Clipping

```bash
rm "Clippings/<原文件名>"
```

### 7. 更新 MASTER_INDEX

追加条目到 `_index/MASTER_INDEX.md` 对应分类段落：

```markdown
- [中文短名](../<分类>/[<子分类>/]<中文短名>/index.md) — 一句话摘要（15-30字） `#标签1` `#标签2`
```

摘要规则：
- 15-30 字，说明文章核心 what + why
- 不复述标题
- 概念标签 2-3 个，用反引号包裹

同时更新该子分类标题中的文章计数，如 `### Architecture (7)` → `### Architecture (8)`。

## 注意事项

- **不修改已归档文章**：只处理 Clippings/ 中的文件
- **metadata.json author 字段**：去除 `[[` 和 `]]` 标记，如 `[[@karpathy]]` → `karpathy`
- **空字段处理**：frontmatter 中缺失的字段在 metadata.json 中用空字符串 `""`
- **重复检测**：基于 `source` URL 判断，同一 URL 只保留一份
- **翻译仅限英文**：中文或双语文章不触发翻译
