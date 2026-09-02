---
name: implement-ticket
description: 执行链派发器——自包含 ticket（spec＋验收标准完整＋verify.sh 兜底）的实现派 Fable 命名子代理 builder（effort medium），失败按写死的三种条件回落 codex（经 /codex-implement），编排者亲自验收；疑难票由用户下令升格为 builder-high。开工实现任何标「实现路径: 执行链」（旧票「外族链」同义）或带完整 spec/验收标准的 ticket 前先经此 skill 判路由；触发词：走执行链、派 builder、实现这张票、升格实现、续修 builder。
---

# implement-ticket — 执行链派发

把一张自包含 ticket 交给执行链实现（`builder` Fable medium 主力 → codex 兜底）；你是编排者，只写 brief、派发、收结果、亲自验收。链序沿革与 policy 见 `/Users/qianli/0-WORKSPACE/60-Tools/Claude-Harness/model-tiering-protocol.md` §3。

## 0. 切面判定（先判后派）

进链条件三者齐备：**spec 完整＋验收标准明确＋项目根有 verify.sh 兜底**。
- 不齐 → 不进链：平凡小修直接做，模糊多步留在主循环（或 scout / mechanic 子代理），向用户说明一句判定理由。
- **机械 vs 有余量**：判断题已全部冻结、只剩照单执行的票派 `mechanic`（Sonnet low），不进本链；结构决策冻结但实现细节仍要拿主意的票才派 `builder`。
- **负面判据**：预计要在 review 循环里反复做裁决的票（边改边定案、辖域争议多）留在编排者手里——执行者是执行者，不是决策者。
- 齐 → 走下面步骤。

## 1. 写 brief（这是设计阶段的收尾，不是文书工作）

按模板 `/Users/qianli/0-WORKSPACE/60-Tools/Claude-Harness/templates/implementation-brief.md` 填一份，落盘 `<项目>/tasks/briefs/<ticket>.md`（目录不存在则建）。验收标准逐条可机器验证；模板「结构决策先行」段列的判断题必须全部冻结——**没冻结就不派**。brief 质量决定整条链成败。

## 2. 派 builder（默认档）

派 `builder` 子代理接 brief：prompt = brief 全文 ＋ 执行纪律段显式附上（原文取 `/Users/qianli/0-WORKSPACE/60-Tools/Claude-Harness/bin/grok-implement.sh` 内 `[Harness 执行纪律]` 段——Deviations 落盘/禁改测试/四段回传格式）。子代理在后台跑；等待期间只做与该分支无关的独立工作（同一工作树上的编辑、stash、verify、commit 等它回来）。

- 续修轮：用 SendMessage 找回**同一个** builder 子代理续对话（保留其上下文），不要新开一路重做。
- **升格档（用户授权的原子切换）**：用户说"升格"后编排者一次做完三步：主会话若在顾问模式（Sonnet 主循环）先 `/model fable`；`/effort xhigh s`（或 `max`）；实现改派 `builder-high`（Fable high），其余步骤不变。编排者只能建议升格、不能决定——建议条件：默认档一票内已回落 codex 一次仍不过，或设计期已判定为返工半径大的架构决策。

## 3. 收结果

- 成功输出应含四段回传（改动清单 / 验证 / Deviations / 遗留）。四段缺失或答非所问 → SendMessage 补要一次；仍不合格 → 按 §4 ④ 回落。
- builder 报"范围外阻塞 / 冻结项站不住"：先裁决 brief。真需要扩范围或改冻结项 → 修 brief 后重派 builder（任何执行者都不许自行扩范围，换执行者不等于授权扩范围）；brief 无误、阻塞是 builder 误判 → 按 §4 ② 回落。
- 子代理超时/半途死亡：先 `git status` 审计树上半成品定去留，**有半成品不盲目重派**——重做会与半成品打架；优先 SendMessage 续跑收尾。

## 4. 回落 codex（只在四种条件下）

写死四种触发，其余情况不回落：
1. builder 自报停手——同一失败连续两轮修不动，随附诊断（其定义内置的停手判据）。
2. 范围阻塞经裁决属 builder 误判（brief 无误），带裁决说明回落。
3. Claude 配额触顶或限流。
4. 执行者不可恢复——SendMessage 续跑失败，或四段回传补要一次后仍不合格；先 `git status` 审计半成品定去留，再带半成品状态回落。

回落前置检查：该票设计期若走过 codex-review-protocol §7 且 codex 是其中一路，先派 `Agent(model:'opus')` 拿完整问题陈述与 ADR 独立复核 brief 的「结构决策先行」段（不给 codex 原话），有异议先裁决；或建议用户升格 `builder-high` 不回落。

回落动作：调 `/codex-implement`（codex GPT-5.6 high 经 `codex:rescue` 接同一份 brief；把 builder 的诊断与半成品状态一并交给它）。codex 也不可用 → 报告用户并建议升格档，不自行硬扛。每次回落向用户**逐字引用**原因，禁笼统转述。

## 5. 验收（不外包——本 skill 的完成判据）

无论谁实现：你亲跑 `bash verify.sh full`，再按异族矩阵走 review（`codex-review-protocol.md` §8）：builder / builder-high 实现 → codex review；回落由 codex 实现 → 内置 `/code-review`。执行者自报"完成"只作线索。**verify full 通过＋review 边界处置完，这张 ticket 才算完成。**
