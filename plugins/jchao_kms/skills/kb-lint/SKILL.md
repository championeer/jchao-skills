---
name: kb-lint
description: 对知识库进行健康检查，发现数据问题、概念缺口和优化机会。触发词："/kb-lint"、"检查知识库"、"知识库健康检查"、"lint"。
---

# kb-lint — 知识库健康检查

对知识库进行系统性健康检查，找出数据不一致、缺失、孤立文章和概念缺口。

## 知识库路径

```
KB_ROOT = /Users/qianli/0-WORKSPACE/50-Knowledge
```

以下所有路径均相对于 `KB_ROOT`。执行任何操作前，先确认该目录存在。

## 触发方式

| 用法 | 行为 |
|------|------|
| `/kb-lint` | 运行完整健康检查 |
| `/kb-lint --quick` | 仅检查元数据完整性（快速模式） |
| `/kb-lint --fix` | 检查并自动修复可修复的问题 |

## 完整检查流程

### Check 1: 元数据完整性

扫描所有已归档文章（含 index.md 的目录），检查：

- [ ] `metadata.json` 存在
- [ ] `metadata.json` 包含所有必需字段（title, type, source, author, clipped_date, tags, original_filename）
- [ ] `title` 非空
- [ ] `type` 为 article/book/note 之一
- [ ] `clipped_date` 格式为 YYYY-MM-DD 或空字符串
- [ ] `tags` 为数组

**自动修复**（`--fix` 模式）：
- 缺失 metadata.json → 从 index.md 的 YAML frontmatter 生成
- 字段缺失 → 补充空默认值

### Check 2: 索引一致性

对比 `_index/MASTER_INDEX.md` 与实际文件：

- [ ] 每篇已归档文章在 MASTER_INDEX 中有对应条目
- [ ] MASTER_INDEX 中的链接路径指向真实存在的文件
- [ ] 子分类标题中的文章计数与实际一致（如 `### Architecture (9)` 实际有 9 篇）
- [ ] MASTER_INDEX 与 kb-index-gen.sh 生成的 README.md 文章总数一致

**自动修复**（`--fix` 模式）：
- 缺失条目 → 读取文章生成摘要并追加
- 失效链接 → 标记为需人工处理
- 计数不一致 → 更新计数

### Check 3: 分类合理性

抽样检查文章是否放在正确分类下：

- 随机抽取 10 篇文章
- 读取内容摘要，按 CLASSIFICATION.md 决策树重新判断分类
- 如果判断结果与当前分类不符，标记为"可能误分类"

不自动修复——误分类涉及目录移动，需人工确认。

### Check 4: 重复检测

扫描所有 metadata.json 的 `source` 字段：

- [ ] 无重复 URL（同一来源只应有一篇文章）
- [ ] 检测标题高度相似的文章（可能是同一内容的不同版本）

### Check 5: 概念覆盖分析

读取 `_index/CONCEPT_MAP.md`，检查：

- [ ] CONCEPT_MAP 中列出的核心文章仍然存在
- [ ] 知识间隙列表是否有更新（新归档文章可能填补了之前的间隙）
- [ ] 是否有新的概念集群形成（某个子分类文章数从 2 篇增长到 5+ 篇）

**自动修复**（`--fix` 模式）：
- 重新生成 CONCEPT_MAP.md（用 subagent 通读 MASTER_INDEX）

### Check 6: Clippings 积压

检查 `Clippings/` 目录：

- [ ] 统计未归档文章数量
- [ ] 如果积压 > 5 篇，建议运行 `/file-article`

## 输出格式

```markdown
# 知识库健康报告

> 检查时间: YYYY-MM-DD HH:MM
> 文章总数: N

## 健康评分: X/100

| 检查项 | 状态 | 问题数 |
|--------|------|--------|
| 元数据完整性 | ✅/⚠️/❌ | N |
| 索引一致性 | ✅/⚠️/❌ | N |
| 分类合理性 | ✅/⚠️/❌ | N |
| 重复检测 | ✅/⚠️/❌ | N |
| 概念覆盖 | ✅/⚠️/❌ | N |
| Clippings 积压 | ✅/⚠️/❌ | N |

## 问题详情

### ⚠️ 元数据问题 (N)
- `01-AI-Agents/xxx/metadata.json`: 缺少 clipped_date 字段
- ...

### ❌ 索引不一致 (N)
- MASTER_INDEX 缺少: `03-Claude-Code/Tutorials/xxx/`
- 失效链接: `_index/MASTER_INDEX.md` 第 42 行指向不存在的文件
- ...

### ⚠️ 可能误分类 (N)
- `10-Thinking-Models/xxx/` → 内容更适合 01-AI-Agents/Architecture
- ...

### Clippings 积压
- 未归档文章: N 篇
- 建议: 运行 `/file-article` 批量归档

## 建议操作

1. [优先级高] 修复 N 个元数据缺失（运行 `/kb-lint --fix`）
2. [优先级高] 补充 MASTER_INDEX 缺失的 N 个条目
3. [优先级中] 确认 N 篇可能误分类的文章
4. [优先级低] 归档 Clippings 积压
```

## 评分规则

| 检查项 | 权重 | 满分条件 |
|--------|------|---------|
| 元数据完整性 | 30 | 所有文章有完整 metadata.json |
| 索引一致性 | 25 | MASTER_INDEX 与实际文件完全匹配 |
| 分类合理性 | 15 | 抽样无误分类 |
| 重复检测 | 10 | 无重复 |
| 概念覆盖 | 10 | CONCEPT_MAP 无过期引用 |
| Clippings 积压 | 10 | 积压 ≤ 3 篇 |

## 注意事项

- **只读操作**（除非 `--fix`）：默认模式不修改任何文件
- **`--fix` 安全边界**：自动修复仅限元数据补全和索引更新，不移动/删除文章
- **抽样检查**：分类合理性检查每次抽样 10 篇，不全量扫描（节省 token）
- **可定期运行**：建议每周执行一次，或在批量归档后执行
