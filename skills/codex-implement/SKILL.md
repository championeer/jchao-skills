---
name: codex-implement
description: codex 单路派发器——把已写好的 brief 交 codex GPT-5.6（high）经 codex:rescue 实现，是 /implement-ticket 执行链的兜底分支（builder 两轮同错停手 / 范围外阻塞且非 brief 问题 / Claude 配额触顶时回落）；用户点名"派 codex"也可直接用。不做切面判定与 brief 写作（那在 /implement-ticket）。触发词：派 codex、codex 实现、续修 codex、回落 codex。
---

# codex-implement — codex 单路派发

前提：brief 已按 `/Users/qianli/0-WORKSPACE/60-Tools/Claude-Harness/templates/implementation-brief.md` 写好并落盘（切面判定与 brief 写作在 `/implement-ticket` §0–§1）。链序与回落触发条件见 `/Users/qianli/0-WORKSPACE/60-Tools/Claude-Harness/model-tiering-protocol.md` §3。

## 1. 派 codex

派 `codex:rescue` 子代理（fork 上下文）接 brief：prompt = brief 全文 ＋ 执行纪律段显式附上（原文取 `/Users/qianli/0-WORKSPACE/60-Tools/Claude-Harness/bin/grok-implement.sh` 内 `[Harness 执行纪律]` 段——Deviations 落盘/禁改测试/四段回传格式）。作为回落分支派出时，把 builder 的诊断（已排除什么 / 最可能根因）与半成品状态一并附上。子代理在后台跑，等待期间只做与该分支无关的独立工作。

- 先决：codex 可用性看 `codex:setup` 的 `ready`（true=已装+已登录）。
- 续修轮：用 SendMessage 找回**同一个** rescue 子代理续对话（保留 codex 侧上下文），不要新开一路重做。

## 2. 收结果

- 成功输出应含四段回传（改动清单 / 验证 / Deviations / 遗留）。四段缺失或答非所问 → 视同失败。
- 子代理超时/半途死亡：先 `git status` 审计树上半成品定去留，**有半成品不盲目重派**——重做会与半成品打架；优先 SendMessage 续跑收尾。

## 3. codex 不可用或失败

链上已无更低一级：向用户**逐字引用**原因（禁笼统转述成"codex 不可用"），并建议升格档（编排者 `/effort xhigh s`，实现派 `builder-high`），由用户下令；不自行硬扛。

## 4. 验收（不外包）

你亲跑 `bash verify.sh full`，再按异族矩阵走 review（`codex-review-protocol.md` §8：codex 实现 → 内置 `/code-review`，实现者 ≠ 审查者家族）。codex 自报"完成"只作线索。**verify full 通过＋review 边界处置完，这张 ticket 才算完成。**
