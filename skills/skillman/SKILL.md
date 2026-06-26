---
name: skillman
description: 管理个人 skill 库 ~/.skill-library 的全生命周期——发现/选型、接入项目（软链）、审计与失效软链排查、归档清理、摄入网上找到的 skill。当用户要"找个 skill / 装个 skill 到某项目 / 看某项目装了哪些 skill / 排查断链 / 归档下线 skill / 把这个 git skill 收进库"时使用。触发词：skillman、管理skill、找skill、装skill、接入skill、skill审计、skill断链、归档skill、摄入skill、skill库状态。注意：管的是 ~/.skill-library 个人库，不是 skill-library-manager 负责的 MedClaw 医疗库。
metadata:
  author: JChao
  mode: Production
---

# skillman —— 个人 skill 库管家

管辖 `~/.skill-library`（个人 Hybrid 库）三层：`repos/` 第三方 git 仓 · `skills/` 全局曝光 · 任意项目 `.claude/skills` 接入。封装 `bin/skill-link.sh`，借鉴 `_inventory/inventory.py` 与 skill-library-manager 的模式。新建 skill 本身交给 `yao-meta-skill`；本 skill 负责造好之后的 **入库 / 接入 / 审计 / 退役**。

## Router Rules

- 一切操作走引擎脚本 `scripts/skillman.sh <命令>`，不要手搓 `ln`/`mv`/`rm`。
- 归档 = 移动不删除；接入后必自验软链（脚本已内建）。
- 动手造新 skill 前先 `find` 查近邻（near-neighbor），够用就别造。

## 命令

| 命令 | 作用 | 例 |
|---|---|---|
| `status` | 全库概览（仓/全局/断链/归档数） | `skillman.sh status` |
| `find <kw>` | 搜名称+描述，给 near-neighbor 提示 | `skillman.sh find pdf` |
| `link <repo>/<skill> [项目]` | 第三方仓 skill 接入项目（封装 skill-link.sh，自验） | `skillman.sh link mattpocock-skills/tdd ~/0-WORKSPACE/31-文件管理白板` |
| `link self/<skill> [项目\|--global]` | **自建源**（`self/`=JChao_Skills 库）接入项目，或 `--global` 全局曝光到 `~/.claude/skills` | `skillman.sh link self/wushixu --global` |
| `audit [项目]` | 给项目→列接入并逐项验链；不给→全库扫断链 | `skillman.sh audit ~/0-WORKSPACE/31-文件管理白板` |
| `archive <名称> [--force]` | 归档 repo/全局 skill，或解除 `~/.claude/skills` 软链的全局曝光（移到 `_archive-<日期>`/删指针，本体不删） | `skillman.sh archive wushixu` |
| `ingest <git-url> [名称]` | `git clone` 进 repos/，完成后提示可 link | `skillman.sh ingest https://github.com/x/y.git` |

`link` 两轴正交：**源**（`<repo>/<skill>` 第三方仓 ｜ `self/<skill>` 自建库）×**目标**（默认项目 `.claude/skills` ｜ `--global` 到 `~/.claude/skills`），四种组合皆可。自建源根可用 `JCHAO_SKILLS_DIR` 覆盖（默认 `JChao_Skills/skills`）。`--global` 链回头用 `archive <skill>` 即可解除曝光（删指针、本体不动）。

定位脚本（本 skill 通常以软链接入项目，故先解析真身目录）：

```bash
S="$(cd "$(dirname "$(readlink -f ~/.claude/skills/skillman 2>/dev/null || readlink -f ./.claude/skills/skillman)")" && pwd)/scripts"
bash "$S/skillman.sh" status
# 或直接绝对路径：
bash ~/0-WORKSPACE/60-Tools/JChao_Skills/skills/skillman/scripts/skillman.sh status
```

## 不适用 / 边界

- **不碰 MedClaw 库**（`/Volumes/Extreme-Pro/MedClaw_SkillLibrary`）——那是 `skill-library-manager` 的地盘，结构与触发都独立。
- **不伪造** `~/.agents/.skill-lock.json` 的 hash 条目；摄入来源以 git remote + `_inventory/ingested.log` 为准。
- **不自动删除**任何 skill：全局软链只"解除曝光"（删指针，本体不动），真实仓/目录只"移动到归档"。
- `archive` 的依赖扫描只覆盖 `~/.skill-library/skills`、`~/.agents/skills`、`~/.claude/skills` 三处；**项目级 `.claude/skills` 的依赖扫不到**，归档前请先对相关项目 `audit`。
- 新建 skill 不在本 skill 职责内 → 用 `yao-meta-skill`。

## 参考

- 库结构 / lock 文件 / 分类键 / 归档约定：[references/library-architecture.md](references/library-architecture.md)
- 接口契约：[agents/interface.yaml](agents/interface.yaml)
