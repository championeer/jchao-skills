# ~/.skill-library 架构参考（skillman 运行时依据）

> 本文档描述 skillman 管辖的个人 skill 库的真实结构。2026-06-26 据实盘点。

## 顶层结构

```
~/.skill-library/
├── repos/                 # 第三方 skill 的整仓 git clone（每个都是独立 git 仓）
│   ├── baoyu-skills/  baoyu-design/  frontend-slides/  guizang-ppt-skill/
│   ├── mattpocock-skills/  ponytail/  yao-meta-skill/
├── skills/                # 全局曝光层：dir 或 symlink，含 SKILL.md 即被各处可用
├── bin/skill-link.sh      # 接入工具：repo 或自建(self/)的 skill 软链进某项目 .claude/skills，或 --global 到 ~/.claude/skills
├── _inventory/            # 盘点产物：inventory.py（分类脚本）+ *-targets.txt + ingested.log
├── _archive-<日期>/       # 归档区（下架不删，按日期分目录）
├── library.json           # 极简元数据（version/createdAt）
└── tmp/
```

## skill 在 repo 内的三种摆放（skill-link.sh 自动探测）

1. 一级：`repos/<repo>/skills/<skill>/SKILL.md`（如 baoyu-skills）
2. 二级分类：`repos/<repo>/skills/<分类>/<skill>/SKILL.md`（如 mattpocock-skills 的 engineering/、productivity/）
3. 单 skill 仓：`repos/<repo>/SKILL.md`（仓根即 skill，如 yao-meta-skill）

→ 接入 spec 一律写 `<仓名>/<skill名>`，skill-link.sh 会按上述顺序探测。

**自建源 `self/<skill>`**：本体在 `JChao_Skills/skills/<skill>`（可 `JCHAO_SKILLS_DIR` 覆盖），不在库内、不走上述三种探测。接入项目同理；加 `--global` 则软链到 `~/.claude/skills`（Claude Code 全局发现点，对齐 `handoff` 先例）。撤销全局曝光：`archive <skill>`（删 `~/.claude/skills` 指针，本体不动）。

## Hybrid 三层管理模型

| 层 | 位置 | 说明 |
|---|---|---|
| 库（全量） | `~/.skill-library/repos` + `skills` | 整仓收纳 + 极少全局曝光 |
| 项目接入 | `<项目>/.claude/skills/<skill>` → 软链回库 | 按需 `link`，用完可解链 |
| 自建分发 | `0-WORKSPACE/60-Tools/JChao_Skills/skills/<skill>` | 自建 skill 本体，再软链到各工作目录 |

gstack 是例外：`~/.claude/skills/gstack` 是整仓软链（承重，勿删），其下 skill 名各异、无 source/target，靠整仓清单识别。

## Provenance（来源溯源）

`~/.agents/.skill-lock.json`（v3）记录每个 skill 的来源：

```jsonc
"<skill名>": {
  "source": "owner/repo", "sourceType": "github",
  "sourceUrl": "https://github.com/owner/repo.git",
  "skillPath": "skills/<skill>/SKILL.md",
  "skillFolderHash": "<sha1>", "installedAt": "...", "updatedAt": "..."
}
```

由 `npx skills`-类工具维护。**skillman 只读不写**这个文件（hash 由该工具计算，伪造无意义）。skillman 自己的摄入流水记在 `_inventory/ingested.log`（`时间\t名称\turl`）。

## 分类键（来自 inventory.py，审计时参考）

- **KEEP-self**（自建）：`jchao` `JChao_Skills` `0-WORKSPACE` `qykb` `qy-operator` `dql-` `course-processor` `epub-translator` `worklog` `handoff` 等
- **KEEP-7repo**（保留第三方仓）：`baoyu-skills` `baoyu-design` `mattpocock-skills` `yao-meta-skill` `ponytail` `gstack` 等
- **KEEP-grayzone**（官方/基础设施/MCP，不默认归档）：`anthropic` `document-skills` `example-skills` `planning-with-files` `context7` `linear` `stripe` `supabase` `playwright` 等
- **ARCHIVE-3rdparty**：未命中以上 → 候选归档（需人工裁决，不自动动）

## 边界：与 MedClaw 库的区分

`skill-library-manager` 管的是 `/Volumes/Extreme-Pro/MedClaw_SkillLibrary/`（移动硬盘上的医疗科研库，814+ skills，按 00_~07_ 分类目录组织，有 FULL_CATALOG.json）。**那是另一个库、另一套脚本、另一套触发词，skillman 完全不碰。** 两者唯一相似的是"归档不删 / 搜索 / 重建目录"等管理模式可互相借鉴。
