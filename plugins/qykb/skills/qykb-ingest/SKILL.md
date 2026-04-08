---
name: qykb-ingest
description: |
  摄入新素材到晴芽知识库。支持临床课程笔记、EPUB 书籍、网页文章、学术论文。
  触发词：/qykb-ingest、"摄入"、"ingest"、"导入这本书"、"处理这篇文章到知识库"
---

# qykb-ingest — 知识库摄入

将原始素材转化为结构化 Wiki 页面，是知识库最核心的操作。

## 用法

```
/qykb-ingest <source-path-or-url> [--type book|web|course|research]
```

- 不指定 `--type` 时自动判断：`.epub` → book，`http` → web，课程笔记路径 → course
- 一次只摄入一个来源，逐条处理

## 工作目录

```
KB_ROOT=/Users/qianli/0-WORKSPACE/30-QingYa/产品/QingYa-Knowledge
```

## Interaction Flow

### Step 0: 确认来源

1. 解析参数，判断素材类型
2. 确认文件/URL 可访问
3. 如果是书籍，检查 `scripts/epub2md.py` 是否存在

### Step 1: 预处理

根据类型执行不同预处理：

**课程笔记（course）**：
- 直接读取 `$KB_ROOT/临床课程/结构化笔记/第{N}课-完整笔记.md`
- 无需转换

**书籍（book）**：
- 运行 `python3 $KB_ROOT/scripts/epub2md.py "<epub_path>" --output-dir "$KB_ROOT/raw/books/"`
- 产出：按章节拆分的 Markdown 文件

**网页（web）**：
- 使用 agent-fetch 或 baoyu-url-to-markdown skill 抓取
- 保存快照到 `$KB_ROOT/raw/web/`

**学术论文（research）**：
- 使用 PubMed MCP 获取元数据
- 全文（如可获取）保存到 `$KB_ROOT/raw/research/`

### Step 2: 创建来源摘要页

在 `$KB_ROOT/raw/{type}/` 下创建来源摘要页：

```yaml
---
type: source
id: {source-type}-{slug}
title: "..."
author: "..."
source_type: book|web|course|research
location: "原始文件路径或 URL"
language: zh|en
categories: [...]
ingest_date: {today}
ingest_status: complete
wiki_pages_generated: []  # 摄入过程中逐步填充
---
```

### Step 3: 提取知识，生成 Wiki 页面

逐章/逐段阅读素材，对每个有价值的知识点：

1. **判断**：是新概念、实操指南、临床案例、还是沟通话术？
2. **查重**：搜索 wiki/ 是否已有相关页面（grep 关键词 + 读 index.md）
3. **创建或更新**：
   - 新知识 → 创建新页面（`confidence: llm-draft`）
   - 已有页面 → 更新内容，追加来源引用到 `sources`
4. **交叉引用**：在 `related` 中添加关联页面，确保双向
5. **记录**：将生成/更新的页面 ID 追加到来源摘要的 `wiki_pages_generated`

页面模板参考 `$KB_ROOT/CLAUDE.md` 中的必填字段规范。

### Step 4: 生成内容种子

从素材中提取适合自媒体的选题，写入 `$KB_ROOT/content-seeds/`：
- 每个种子包含 hook、大纲、关键知识点、平台适配
- 命名：`seed-{platform}-{slug}.md`（platform: gzh/xhs/sph）

### Step 5: 重建索引 + 提交

```bash
cd "$KB_ROOT"
python3 scripts/rebuild_index.py
```

追加 log.md：
```
## [YYYY-MM-DD] ingest | {source-title}
- 来源：{path-or-url}
- 生成页面：{list of page IDs}
- 更新页面：{list of page IDs}
```

然后 git add + git commit：
```bash
git add -A
git commit -m "ingest: {source-title}"
```

## 质量要求

- 所有新页面标记 `confidence: llm-draft`
- 概念页必须有「晴芽应用」段落（这个知识如何服务于"冲突后10分钟"场景）
- 案例页必须完全匿名化
- 来源摘要页直接引用不超原文 5%

## 示例

```
用户：/qykb-ingest 临床课程/结构化笔记/第01课-完整笔记.md --type course
用户：/qykb-ingest /Volumes/Extreme-Pro/QingYa-Raw/books/CBT\ Toolbox...epub
用户：/qykb-ingest https://childmind.org/article/signs-of-depression-in-children
```
