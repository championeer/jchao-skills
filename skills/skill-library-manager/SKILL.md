---
name: skill-library-manager
description: 管理MedClaw Skill Library的增删查改操作。当用户要求搜索/添加/删除/更新/归档Skills，或查看库状态时使用此Skill。触发词：搜索skill、添加skill、删除skill、更新skill、skill库、技能库、skill status、rebuild catalog。
---

# MedClaw Skill Library Manager

管理位于 `/Volumes/Extreme-Pro/MedClaw_SkillLibrary/` 的技能库。

## 路径约定

```
# 库路径（数据）
LIB="/Volumes/Extreme-Pro/MedClaw_SkillLibrary"

# 脚本路径（随 skill 本体存放）
SKILL_DIR="$(cd "$(dirname "$(readlink -f ~/.claude/skills/skill-library-manager)")" && pwd)"
SCRIPTS="$SKILL_DIR/scripts"
```

所有脚本通过环境变量 `MEDCLAW_SKILL_LIBRARY` 指定库路径，默认值为 `/Volumes/Extreme-Pro/MedClaw_SkillLibrary`。

## 库结构速查

```
/Volumes/Extreme-Pro/MedClaw_SkillLibrary/
├── SKILL_INVENTORY.md        # 项目精选清单（医生科研相关）
├── FULL_CATALOG.md           # 全量目录（814+ skills，人类可读）
├── FULL_CATALOG.json         # 全量目录（结构化数据，供脚本用）
├── repos/                    # 源仓库（git clone）
├── skills/                   # 按分类组织的符号链接
│   ├── 00_库管理/
│   ├── 01_文献检索与分析/
│   ├── 02_论文写作与润色/
│   ├── 03_统计与数据分析/
│   ├── 04_临床医学工具/
│   ├── 05_通用研究工具/
│   ├── 06_文档处理/
│   └── 07_科研辅助/
└── archive/                  # 归档（下架但不删除）
```

脚本随 skill 本体存放：
```
~/.claude/skills/skill-library-manager/   # symlink
└── scripts/
    ├── search_skills.sh      # 搜索
    ├── update_all.sh         # 更新所有仓库
    ├── rebuild_catalog.sh    # 重建全量目录
    └── sync_to_cloud.sh      # 同步到 Cloudflare
```

---

## 操作手册

### 1. 搜索Skill

```bash
# 定位脚本目录
SCRIPTS="$(cd "$(dirname "$(readlink -f ~/.claude/skills/skill-library-manager)")" && pwd)/scripts"

# 关键词搜索（模糊匹配名称、描述、分类）
bash "$SCRIPTS/search_skills.sh" <关键词>

# 按分类筛选
bash "$SCRIPTS/search_skills.sh" --cat <分类名>

# 按仓库筛选
bash "$SCRIPTS/search_skills.sh" --repo <仓库名>

# 列出所有分类
bash "$SCRIPTS/search_skills.sh" --list-cats

# 列出所有仓库
bash "$SCRIPTS/search_skills.sh" --list-repos

# 统计概览
bash "$SCRIPTS/search_skills.sh" --stats
```

如果搜索脚本无法满足需求（如需要读取SKILL.md内容），直接用Grep工具搜索：
```
Grep pattern="<关键词>" path="/Volumes/Extreme-Pro/MedClaw_SkillLibrary/repos/"
```

### 2. 添加新Skill

严格按以下步骤执行，**不可跳步**：

**场景A：添加已有仓库中的Skill（仓库已在repos/下）**

1. 确认Skill存在：
   ```bash
   ls /Volumes/Extreme-Pro/MedClaw_SkillLibrary/repos/<仓库名>/skills/<skill名>/SKILL.md
   ```

2. 创建分类符号链接：
   ```bash
   ln -sf /Volumes/Extreme-Pro/MedClaw_SkillLibrary/repos/<仓库名>/skills/<skill名> \
          /Volumes/Extreme-Pro/MedClaw_SkillLibrary/skills/<分类目录>/<skill名>
   ```

3. 如果是项目相关Skill，更新 `SKILL_INVENTORY.md`：在对应分类表格中添加一行，包含名称、简介、来源、路径、安全性、MVP等级、状态。

4. 更新日志：在 `SKILL_INVENTORY.md` 底部的更新日志中添加记录。

**场景B：添加新仓库**

1. 克隆仓库：
   ```bash
   cd /Volumes/Extreme-Pro/MedClaw_SkillLibrary/repos/
   git clone <仓库地址>
   ```

2. 在 `SKILL_INVENTORY.md` 的源仓库清单中添加一行。

3. 重建全量目录：
   ```bash
   SCRIPTS="$(cd "$(dirname "$(readlink -f ~/.claude/skills/skill-library-manager)")" && pwd)/scripts"
   bash "$SCRIPTS/rebuild_catalog.sh"
   ```
   > **注意**：`rebuild_catalog.sh` 中需要为新仓库添加扫描逻辑（scan_skills_dir调用）。根据仓库的目录结构（skills/子目录 或 扁平结构），选择合适的扫描方式。

4. 按场景A的步骤2-4处理需要部署的具体Skill。

**场景C：从ClawHub/npm安装**

1. 先找到Skill对应的GitHub仓库源：
   ```bash
   # 例如 npx skills add shubhamsaboo/awesome-llm-apps@academic-researcher
   # 对应仓库：github.com/shubhamsaboo/awesome-llm-apps
   ```

2. 按场景B处理。不直接使用 `npx skills add`，统一走git clone以便版本管理。

### 3. 归档Skill（删除）

**绝对不能直接删除**，必须归档：

1. 移动到archive：
   ```bash
   mv /Volumes/Extreme-Pro/MedClaw_SkillLibrary/skills/<分类>/<skill名> \
      /Volumes/Extreme-Pro/MedClaw_SkillLibrary/archive/<skill名>_<日期>
   ```

2. 更新 `SKILL_INVENTORY.md`：
   - 在对应分类表格中将状态改为 `已归档`
   - 在归档记录表中添加一行（名称、日期、原因、原分类、archive路径）
   - 更新汇总统计

3. 重建全量目录（如果从repos中也移除了源仓库的话）：
   ```bash
   SCRIPTS="$(cd "$(dirname "$(readlink -f ~/.claude/skills/skill-library-manager)")" && pwd)/scripts"
   bash "$SCRIPTS/rebuild_catalog.sh"
   ```

### 4. 更新所有仓库

```bash
SCRIPTS="$(cd "$(dirname "$(readlink -f ~/.claude/skills/skill-library-manager)")" && pwd)/scripts"
bash "$SCRIPTS/update_all.sh"
```

更新后如果想刷新目录索引（捕获新增/删除的Skills）：
```bash
bash "$SCRIPTS/rebuild_catalog.sh"
```

### 5. 查看库状态

```bash
SCRIPTS="$(cd "$(dirname "$(readlink -f ~/.claude/skills/skill-library-manager)")" && pwd)/scripts"

# 快速统计
bash "$SCRIPTS/search_skills.sh" --stats

# 检查符号链接是否完好
find /Volumes/Extreme-Pro/MedClaw_SkillLibrary/skills/ -type l ! -exec test -e {} \; -print

# 检查各仓库是否有待拉取的更新
for repo in /Volumes/Extreme-Pro/MedClaw_SkillLibrary/repos/*/; do
  echo "=== $(basename $repo) ==="
  cd "$repo" && git fetch --dry-run 2>&1 | head -3
done
```

### 6. 新增分类

如果现有7个分类不够用：

1. 创建新目录：
   ```bash
   mkdir -p /Volumes/Extreme-Pro/MedClaw_SkillLibrary/skills/<编号>_<分类名>
   ```

2. 在 `SKILL_INVENTORY.md` 的库结构部分和对应位置添加新分类的表格。

---

## 安全性评估规则

对每个新增Skill执行安全检查：

| 检查项 | 方法 | 红线 |
|--------|------|------|
| 是否执行shell命令 | 查看SKILL.md中allowed-tools是否含Bash/exec | 含exec/shell需标记并审查 |
| 是否外发数据 | 查看是否调用外部API | 任何涉及PHI（患者数据）的外发=不通过 |
| 是否需要付费API | 查看依赖的API是否免费 | 需标注成本 |
| 许可证 | 查看LICENSE文件 | Proprietary需确认使用条款 |

安全标记：安全 / 需注意 / 需审查

---

## 注意事项

- `FULL_CATALOG.json` 是搜索脚本的数据源，修改后必须通过 `rebuild_catalog.sh` 重建，不要手动编辑
- `SKILL_INVENTORY.md` 是人工维护的项目精选清单，只收录与医生科研项目直接相关的Skills
- 符号链接指向 `repos/` 下的实际目录，`update_all.sh` 拉取新代码后符号链接自动指向最新内容
- 归档到 `archive/` 的Skill加上日期后缀防止同名冲突
- 所有脚本支持 `MEDCLAW_SKILL_LIBRARY` 环境变量覆盖默认库路径
