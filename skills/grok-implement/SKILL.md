---
name: grok-implement
description: 外族执行链派发器——自包含 ticket（spec＋验收标准完整）的实现交 grok-4.6，FALLBACK 逐级回落 codex→Opus，编排者亲自验收。开工实现任何标「实现路径:外族链」或带完整 spec/验收标准的 ticket 前先经此 skill 判路由；触发词：走外族链、派 grok、grok 实现、续修 grok。
---

# grok-implement — 外族执行链派发

把一张自包含 ticket 交给外族执行链实现（grok-4.6 主力 → codex 备选 → Opus 兜底）；你是编排者，只写 brief、收结果、亲自验收。链序沿革与 policy 见 `/Users/qianli/0-WORKSPACE/60-Tools/Claude-Harness/model-tiering-protocol.md` §3。

## 0. 切面判定（先判后派）

进链条件三者齐备：**spec 完整＋验收标准明确＋项目根有 verify.sh 兜底**。
- 不齐 → 不进链：平凡小修直接做，模糊多步留在 Claude 侧（主循环或 Sonnet 子代理），向用户说明一句判定理由。
- 齐 → 走下面步骤。

## 1. 写 brief

按模板 `/Users/qianli/0-WORKSPACE/60-Tools/Claude-Harness/templates/implementation-brief.md` 填一份，落盘 `<项目>/tasks/briefs/<ticket>.md`（目录不存在则建）。验收标准逐条可机器验证——brief 质量决定整条链成败。

## 2. 派 grok（第一梯队）

派一个子代理（`model: sonnet`，机械转发类）运行下面命令，Bash 须显式传 `timeout: 600000`（脚本内部 540s 超时先触发，保证干净 FALLBACK）：

```
bash /Users/qianli/0-WORKSPACE/60-Tools/Claude-Harness/bin/grok-implement.sh --brief <brief 绝对路径> --cwd <项目根>
```

子代理职责仅一句：把脚本 stdout（成功文本或 `FALLBACK: <原因>` 行）逐字回传，不总结、不修复。超时/模型/逃生阀等 env 调参见脚本头注释。

## 3. 收结果

- 成功输出应含四段回传（改动清单 / 验证 / Deviations / 遗留）＋尾行 `GROK_SESSION: <id>`。记下 id——同一 ticket 的返修轮加 `--resume <id>` 重派，保留 grok 侧上下文。
- 四段缺失或答非所问 → 视同失败，按 FALLBACK 处置。

## 4. FALLBACK 回落（逐级，不跳级）

1. `codex:rescue`（fork 上下文）接**同一份 brief**——执行纪律段显式附在 prompt 里（原文取 `bin/grok-implement.sh` 内 `[Harness 执行纪律]` 段）。
2. codex 也不可用 → `Agent(model:'opus')` 直接执行：brief 正文作 prompt，同样附纪律段。
3. 每次回落向用户逐字引用 FALLBACK 原因，禁笼统转述。

## 5. 验收（不外包——本 skill 的完成判据）

无论谁实现：你亲跑 `bash verify.sh full`，再按异族矩阵走 review（`codex-review-protocol.md` §8，实现者 ≠ 审查者家族）。外族自报"完成"只作线索。**verify full 通过＋review 边界处置完，这张 ticket 才算完成。**
