# CLAUDE_reference — 按需读取参考区 / On-Demand Reference

本目录位于项目**根目录**，由 Claude 维护，独立于 `docs/`（`docs/` 由其他 agent 创建/拥有）。
存放篇幅较长的参考材料——构建计划、路线图、以及 Claude 在需要时才查阅的上下文。
**这些文档不会每次会话全部加载，仅在与当前任务相关时按需读取。**

This directory lives at the **project root** and is maintained by Claude, kept separate
from `docs/` (which other agents own). It holds longer-form reference material that
Claude consults **on demand**, not every session.

## 约定 / Convention

- 本目录由 Claude 拥有；所有文件名都带 `CLAUDE` 前缀（例如本文件 `CLAUDE_INDEX.md`），
  以免其他 agent 误读或误改；不使用 `README.md`（该文件名由架构 agent 使用）。
- `CLAUDE.md` 每次会话都会载入上下文，必须保持精简：它只放一行指向本区域的**指针**，
  从不内联完整内容。
- 本区域文档**仅在与当前任务相关时读取**（例如规划某个任务的顺序、范围或验收时）。
- 本区域是 Claude 的参考存储，**不覆盖**权威文档：当前任务事实以 `docs/06_tasks/TASK_LEDGER.md` 为准，
  后端契约以 `docs/03_backend/` 为准，当前状态以 `docs/00_memory/CURRENT_STATE.md` 为准。
  如有冲突，编号的权威文档优先。

## 索引 / Index

- [CLAUDE_INCREMENTAL_BUILD_PLAN.md](CLAUDE_INCREMENTAL_BUILD_PLAN.md) — 用户提供的 T-002 分阶段构建
  路线图快照（2026-06-20 记录）。当前状态见 `docs/06_tasks/TASK_LEDGER.md`；历史详版见 `docs/09_frozen/task_records_2026-06-26/T-002_INCREMENTAL_BUILD_ROADMAP.md`。
