---
name: qykb-export
description: |
  将知识库中已审核的页面导出到小程序 skill refs/。依赖多技能框架落地。
  触发词：/qykb-export、"导出refs"、"导出到小程序"
---

# qykb-export — 导出到小程序

> **前置依赖**：小程序多技能框架落地后才可使用。当前 miniapp 只有 action-card-v2，无 refs/ 加载逻辑。

## 用法

```
/qykb-export <skill-name> [--dry-run]
```

- `--dry-run`：预览输出，不写入文件

## 工作目录

```
KB_ROOT=/Users/qianli/0-WORKSPACE/30-QingYa/产品/QingYa-Knowledge
MINIAPP_SKILLS=/Users/qianli/0-WORKSPACE/30-QingYa/产品/miniapp/backend/app/skills/definitions
```

## Interaction Flow

### Step 1: 扫描目标页面

搜索 wiki/ 中 `ai_skill_target: <skill-name>` 的页面。

### Step 2: 校验导出资格

每个页面必须满足三条件：
1. `confidence: verified`
2. `reviewed_by` 非空
3. `reviewed_at` 在 180 天内

不满足的页面列出原因并跳过。

### Step 3: 转换格式

将 Wiki 页面转换为 skill refs 格式：
- 移除 frontmatter
- 移除来源备注和交叉引用链接
- 保留核心知识内容
- 根据技能需求调整结构

### Step 4: 输出

- `--dry-run`：在终端显示转换结果
- 正式运行：写入 `$MINIAPP_SKILLS/{skill-name}/refs/`

## 注意

此 Skill 在多技能框架落地前处于待开发状态。具体的输出格式需与 miniapp 侧的 skill loader 对齐后最终确定。
