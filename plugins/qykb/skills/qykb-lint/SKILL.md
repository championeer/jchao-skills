---
name: qykb-lint
description: |
  对晴芽知识库进行健康检查。检查前置元数据、交叉引用、匿名化、版权合规等。
  触发词：/qykb-lint、"检查知识库"、"lint KB"、"知识库健康检查"
---

# qykb-lint — 知识库健康检查

## 用法

```
/qykb-lint [--fix] [--category <category-id>]
```

- `--fix`：自动修复可机械修复的问题
- `--category`：只检查指定领域

## 工作目录

```
KB_ROOT=/Users/qianli/0-WORKSPACE/30-QingYa/产品/QingYa-Knowledge
```

## Interaction Flow

### Step 1: 扫描所有 Wiki 页面

遍历 `$KB_ROOT/wiki/` 下所有 `.md` 文件，解析 frontmatter。

### Step 2: 执行检查

按严重度分级（error / warning / info）：

**Error 级（必须修复）：**
1. **前置元数据不完整**：缺少 type, id, title, categories, confidence, created, updated, status 中任一字段
2. **页面 ID 重复**：多个文件使用同一 id
3. **导出门控违规**：confidence=verified 但 reviewed_by 为空或 reviewed_at 超 180 天
4. **案例未匿名化**：案例页正文包含疑似真实姓名（用 regex 扫描常见中文姓名模式）

**Warning 级（应修复）：**
5. **交叉引用断裂**：related 中引用了不存在的页面 ID
6. **单向引用**：A 引用 B，但 B 未引用 A
7. **孤立页面**：零入站引用的页面
8. **版权风险**：来源摘要页中连续引用超过 200 字的段落
9. **页面过长**：超过 10,000 字

**Info 级（建议改进）：**
10. **新鲜度**：updated 超过 90 天且 status 不是 archived
11. **指南来源不足**：指南页 sources 少于 2 个不同来源
12. **缺少晴芽应用段落**：概念页正文中未包含"晴芽应用"相关段落

### Step 3: 输出报告

```
晴芽知识库 Lint 报告
====================
扫描页面：{total}

Error ({n}):
  - [E001] concept-safe-base: 缺少 reviewed_at 字段
  ...

Warning ({n}):
  - [W005] guide-post-conflict: related 引用 concept-xyz 不存在
  ...

Info ({n}):
  - [I010] concept-attachment: updated 2026-01-01，超过 90 天未更新
  ...
```

### Step 4: 自动修复（--fix 模式）

可自动修复的项：
- 补全缺失的 `created`/`updated`（从 git log 推断）
- 修复单向引用（自动添加反向 related）
- 重建 index.md（调用 rebuild_index.py）

修复后逐项报告修复内容，最后 git commit。
