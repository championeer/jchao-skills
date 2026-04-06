---
name: course-processor
description: |
  处理临床课程原始素材（录音WAV+PPT照片）为结构化知识笔记。
  触发词："处理课程"、"转录课程"、"process course"、"处理第X课"
---

## When to Use

- 用户说"处理课程"、"处理第X课"、"转录课程"、"process course"
- 用户提供了新的课程录音或PPT照片需要处理
- 用户要求批量处理多节课程

## When NOT to Use

- 用户只需要转录单个音频文件（用 `/asr`）
- 用户需要从已有笔记中提炼产品知识（那是后续的知识集成步骤）

## Purpose

自动化处理临床课程原始素材的三步流水线：
1. **PPT 提取**：从照片中提取 PPT 文字内容
2. **录音转录**：使用 DashScope Fun-ASR 将 WAV 录音转为文字
3. **结构化合并**：将 PPT 结构 + 转录细节合并为完整课程笔记

<HARD-GATE>
- 开始处理前，必须确认环境就绪（ffmpeg、dashscope、API Key）
- ASR 转录必须使用 scripts/dashscope-asr.py 脚本（含重试和断点续传）
- 每步完成后检查输出文件存在且非空，再进入下一步
- 已存在的输出文件默认跳过，除非用户明确要求重新处理
</HARD-GATE>

## 项目路径约定

```
素材目录: 产品/CBT-Knowledge/临床课程/原始素材/儿童医院课程/{课次}/
转录输出: 产品/CBT-Knowledge/临床课程/转录稿/第{课次}课-转录稿.md
PPT输出:  产品/CBT-Knowledge/临床课程/结构化笔记/第{课次}课-PPT提取.md
合并输出: 产品/CBT-Knowledge/临床课程/结构化笔记/第{课次}课-完整笔记.md
```

## Interaction Flow

### Step 0: 环境检查

```bash
FFMPEG_OK=$(which ffmpeg 2>/dev/null && echo yes || echo no)
DASHSCOPE_OK=$(python3 -c "import dashscope; print('yes')" 2>/dev/null || echo no)
API_KEY_OK=$([ -n "$DASHSCOPE_API_KEY" ] && echo yes || echo no)
```

| 问题 | 处理 |
|------|------|
| ffmpeg 缺失 | 阻断。提示 `brew install ffmpeg` |
| dashscope 缺失 | 阻断。提示 `pip3 install dashscope` |
| API Key 缺失 | 阻断。提示 `export DASHSCOPE_API_KEY="your-key"` |

### Step 1: 确定处理范围

解析用户参数：
- `/course-processor 02` → 处理第02课
- `/course-processor all` → 处理全部未完成的课程
- `/course-processor 02 03 05` → 处理指定多节课

扫描素材目录：

```bash
# 列出所有课次
ls <素材目录>/
```

对每个待处理的课次，检测：
- WAV 文件数量
- JPEG 文件数量
- 已完成的输出文件（跳过已处理的步骤）

向用户汇总后确认再开始：

```
待处理课程：
  第02课: 16段录音, 9张PPT [转录稿:无, PPT提取:无, 完整笔记:无]
  第03课: 6段录音, 0张PPT  [转录稿:无, 完整笔记:无]

确认开始处理？
```

### Step 2: PPT 提取

仅对有 JPEG 照片的课次执行。

启动 Agent（subagent_type: general-purpose）读取全部照片并提取文字：

**Subagent prompt 模板：**

```
你的任务是读取第{课次}课的全部PPT照片，提取每张的完整文字内容，并按顺序整理。

照片路径：{素材目录}/{课次}/
文件列表：{JPEG文件列表}

工作步骤：
1. 逐张读取所有照片（可并行）
2. 提取每张PPT上的所有文字（标题、正文、图表、注释）
3. 保持原始结构（标题层级、列表、表格）
4. 按照片顺序整理

输出格式：
- Markdown 格式
- 每张PPT用 ## 标题分隔，标注来源文件名
- 完整保留文字，模糊处标注 [模糊/不清晰]
- 这是面向抑郁症青少年家长的专业课程PPT

写入：{PPT输出路径}
```

完成后验证输出文件存在且行数 > 10。

### Step 3: 录音转录

运行 ASR 脚本（使用 Bash 工具，设 timeout 600000，run_in_background: true）：

```bash
export DASHSCOPE_API_KEY="$DASHSCOPE_API_KEY"
python3 <SKILL_DIR>/scripts/dashscope-asr.py \
  "{素材目录}/{课次}" \
  "{转录输出路径}" \
  --course "{课次}" \
  --cache-dir "/tmp/course-asr-cache/{课次}"
```

脚本特性：
- 每段转录完立即缓存 JSON（断点续传）
- 3次重试 + 指数退避
- 已有缓存的段自动跳过

等待后台任务完成，读取输出确认。

### Step 4: 结构化合并

启动 Agent（subagent_type: general-purpose）合并 PPT + 转录稿：

**有 PPT 的课次 — Subagent prompt 模板：**

```
将第{课次}课的PPT提取和录音转录稿合并为一份结构化课程笔记。

输入：
1. PPT提取：{PPT输出路径}
2. 转录稿：{转录输出路径}

工作要求：
1. 以PPT为骨架，提供的框架作为笔记主要结构
2. 用转录稿补充：医生详细解释、临床案例、话术上下文、核心观点
3. 用转录稿校对PPT中的OCR错误
4. 去除非课程内容（路上录音、闲聊等）
5. 关键观点保留医生原话，用引号标注
6. 标注来源段号（如 [转录:第4段]、[PPT 14]）

输出结构：
- 课程概述
- 按主题分章节（PPT结构 + 转录补充）
- 临床案例集
- 核心金句
- 产品应用提示（哪些内容可用于晴芽小程序的哪个模块）

写入：{合并输出路径}
```

**无 PPT 的课次 — Subagent prompt 模板：**

```
从第{课次}课的录音转录稿中提取结构化课程笔记。本课无PPT照片。

输入：转录稿：{转录输出路径}

工作要求：
1. 从转录内容中识别课程主题和结构
2. 提取核心知识点、案例、话术
3. 去除非课程内容
4. 关键观点保留医生原话
5. 组织为清晰的章节结构

输出结构同上。写入：{合并输出路径}
```

### Step 5: 报告

处理完成后汇总：

```
第{课次}课处理完成：

  PPT提取:   {路径} ({行数}行)
  转录稿:    {路径} ({字数}字)
  完整笔记:  {路径} ({行数}行)

下一步：
  - 处理其他课次: /course-processor {下一课次}
  - 产品知识集成: 从完整笔记中提取知识更新到小程序 Skill
```

## 批量模式

当参数为 `all` 时，按课次顺序逐一处理。每完成一课后汇报进度：

```
[2/5] 第02课处理完成 (转录28,000字, 笔记580行)
[3/5] 第03课处理中...
```

已有完整笔记的课次自动跳过。

## Composability

- **被调用者**: 用户直接调用
- **调用**: 无（自包含）
- **相关 Skill**: `/asr`（单文件转录，本 Skill 不依赖它）

## Examples

> "处理第02课"

1. 环境检查 → OK
2. 扫描第02课: 16段WAV, 9张JPEG
3. PPT提取 → 第02课-PPT提取.md
4. ASR转录 → 第02课-转录稿.md
5. 结构化合并 → 第02课-完整笔记.md
6. 报告

> "处理所有课程"

1. 环境检查 → OK
2. 扫描: 第01课(已完成), 第02-05课(待处理)
3. 逐一处理第02→03→04→05课
4. 最终汇总报告
