# Context & Quota Governance — Executable Plan (Phase 0 + Phase 1)

- Status: external review input (Claude), written 2026-07-10. Executable instructions for Codex; verify facts against the live repo before acting on them.
- This file does not reset branch, task ID, validation, or product status. `TASK_LEDGER.md` stays authoritative for numbering.
- Consumption convention (T-150/T-151): Phase 1 adds this filename to `.gitignore`/`.rgignore`; archive to `docs/09_frozen/external_agent_reports/` at Phase 1 closeout.

> **用户速览：** Phase 0 在当前超长会话里执行——给 19 个无归属改动一个去处（checkpoint 提交或确认丢弃），然后终止该会话。Phase 1 在**新会话**里作为独立编号任务执行——把 session-per-task、验证分层、证据外置、树洁净四组规则写进 workflow 文档并留 decision log。两个 Phase 分别把本文件路径粘给 Codex 即可。

## Authorization (granted by the user by handing this file to Codex)

1. Phase 0: one checkpoint commit (and push on the current branch) of the currently modified Swift/test files, **without** task-completion validation — this is a checkpoint, not a task closeout. All other standing Git rules stay in force (no pull/rebase/merge/reset/force-push; stop if push fails, per T-186).
2. Phase 0: `git restore` of specific files **only after** the user explicitly confirms the discard list in chat. Never discard without that confirmation.
3. Phase 1: a standalone workflow-rule task editing `AGENTS.md`, `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`, `docs/05_workflow/CONTEXT_AND_RECOVERY.md`, `docs/05_workflow/GITHUB_RULES.md`, `docs/05_workflow/TOOLING_POLICY.md` (cross-check only), `.gitignore`, `.rgignore`, plus the required decision-log/ledger/worklog/current-state entries.
4. Nothing else: no app/backend/product changes, no script changes, no Markdown compression, no CLAUDE.md changes (already consistent), no subagents.

Stop and ask the user if any step falls outside this list or conflicts with live repo state.

## Diagnosis (verified 2026-07-10; reuse in the decision-log entry)

- Per-turn cost scales with current conversation size. The T-249..T-257 mega-session parked at a high token watermark makes every turn cost ~10–20x a fresh-session turn; the 65%/80% thresholds govern the window, not spend.
- ~19 modified files (+1282/−422) sit uncommitted with `CURRENT_STATE.md` saying "Current task: none" — unattributed WIP that every session re-derives and must protect.
- Already fine (do not touch): `ios-build.sh`/`ios-test.sh` print summary-only output with full logs to a temp file; active Markdown is minimal (AGENTS.md 829 words, workflow trio ≈3.4k words).
- Remaining per-slice cost drivers: full-suite test runs on ordinary slices, screenshot/simulator evidence re-ingested into context, repeated diff/file re-reads inside one long thread.

---

# Phase 0 — Close out the mega-session (run INSIDE the existing long conversation)

Goal: leave a clean, explained tree, then terminate that conversation. No new `T-###` starts in it.

**Step 0.1 — Inventory.** Run `git status --porcelain` and `git diff --stat`. Exclude untracked external reports (`UI_DESIGN_RULES_PROPOSAL.md`, `CONTEXT_QUOTA_GOVERNANCE_PLAN.md`, and the two ignored report names) from all classification and from any commit. Classify every modified file into exactly one bucket:
- (a) intentional pre-work for Q-104 (or another named package),
- (b) post-T-257 residue / abandoned experiment,
- (c) unknown.

**Step 0.2 — Report before acting.** Post the classification to the user as one short message: bucket per file, one-line reason, proposed disposition. Wait for confirmation only where bucket (b) or (c) proposes discarding; bucket (a) may proceed directly.

**Step 0.3 — Disposition.**
- Bucket (a): commit as `checkpoint(pre-Q-104): <one-line scope>` on the current branch and push. Do **not** start T-258/Q-104 in this session; the checkpoint is input for that task's fresh session.
- Bucket (b) confirmed discard: `git restore <files>`; confirmed keep: fold into the checkpoint commit with the scope note naming them.
- Bucket (c): keep, fold into the checkpoint commit, and list them explicitly in the checkpoint note as "unclassified".
- Do not use `git stash` for any of this.

**Step 0.4 — Record.** Add one checkpoint entry to `docs/00_memory/WORKLOG.md` using the existing checkpoint fields (task ID/status = "session checkpoint, no task", files, validation = intentionally none, decisions, risks, next context = "Q-104 must review checkpoint commit <sha>"). Update `docs/00_memory/CURRENT_STATE.md` branch/tree facts (replacement semantics): note the checkpoint sha and that the tree is clean. No ledger row — this is a checkpoint, not a task.

**Step 0.5 — Terminate.** Report done and stop. The user closes this conversation permanently; all subsequent work happens in fresh sessions.

---

# Phase 1 — Workflow-rule task (run in a FRESH session)

Setup: follow `SINGLE_AGENT_WORKFLOW.md` "Rule Change Tasks". Mode: Quick. Task ID: the ledger's next available ID under its current reservation notes (as of 2026-07-10, T-258 is reserved for Q-104 — follow the ledger, not this report). Scope: exactly the edits below.

## Edit 1 — `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`

**1a.** In "Core Rules", replace the bullet `Complete one primary task per run.` with:

```markdown
- Complete one primary task per run, and one `T-###` task per session: start each task in a fresh session, and end the session after its closeout. Do not start another task, package, or follow-up fix in the same session.
```

**1b.** In "Task Flow", replace step 13 `Stop.` with:

```markdown
13. Stop and end the session; the next task starts in a fresh session.
```

**1c.** In the "Modes" table, replace the Standard row's Validation cell with:

```markdown
`git diff --check`, focused tests for the touched feature domain when they exist, plus one `./scripts/ios-build.sh`; simulator launch for visible UI/app behavior
```

and add directly under the table:

```markdown
Full `./scripts/ios-test.sh` is reserved for package/integration gate tasks (for example Q-104-style cross-screen gates), Deep-mode tasks, changes to shared Store/repository/DesignSystem code used by multiple features, and pre-release validation. Ordinary single-surface UI slices do not run the full suite by default.
```

**1d.** Add a new section after "Automatic Git Closeout":

```markdown
## Session Budget Rules

Per-turn cost scales with the current conversation size, so session length is a budget rule, not only a context-window concern.

- One `T-###` per session. After closeout, commit/push, and hygiene, end the session.
- A session may continue the same interrupted task, never a second task.
- If an in-flight task approaches the 65% boundary, prefer: write a checkpoint, make a checkpoint commit, end the session, and resume the same task in a fresh session via the Recovery steps in `CONTEXT_AND_RECOVERY.md`. In-place `/compact` is the fallback, not the default.
- Session end requires a clean tree: the task commit exists, or remaining changes are committed as a checkpoint commit (`GITHUB_RULES.md` format). Never leave unattributed modified files across a session boundary; never use `git stash` as a session-boundary mechanism.
- At session start, `git status --short` must be explainable from `CURRENT_STATE.md`/`WORKLOG.md` facts. Unattributed modifications are a stop condition: report and ask before editing.

## Evidence and Logs

- Screenshots, recordings, and simulator captures are evidence for humans: save them under `artifacts/evidence/<task-id>/`, reference the paths in the worklog entry, and do not re-read image files into the conversation.
- In-context verification uses text: build/test script summaries, TestOps selector output, Debug Console output, and targeted diff reads.
- Build/test scripts already write full logs to a temp file and print summaries. Open the full log only when the summary is insufficient, and only filtered (`grep`, or `sed` a line range) — never whole.
- Batch visual QA at package gates instead of capturing screenshots on every slice.
```

**1e.** Replace the "Compaction" section body with:

```markdown
Session end at the task boundary is the default context reset; manual `/compact` is the fallback for a single oversized in-flight task and follows the 353,000-token 65%/80% thresholds in `CONTEXT_AND_RECOVERY.md`. Markdown word telemetry never triggers it. Before compaction or a checkpoint-based session end, write a checkpoint with task ID/status, files changed, validation, key decisions, risks, and next context.
```

## Edit 2 — `docs/05_workflow/CONTEXT_AND_RECOVERY.md`

Replace the "Compaction" section's threshold list (keep the intro sentence about the 353,000-token reference and the closing sentences about platform compaction and checkpoint fields) with:

```markdown
The default context reset is ending the session at the task boundary (see `SINGLE_AGENT_WORKFLOW.md`, Session Budget Rules). The thresholds below govern a single task that grows too large:

- Below 65% (about 229,000 tokens): continue the current task normally.
- From 65% to below 80%: finish the current task only if it is close to done; otherwise write a checkpoint, make a checkpoint commit, end the session, and resume the same task in a fresh session.
- At or above 80% (about 282,000 tokens): write a checkpoint immediately, then end the session; compact in place only when ending mid-operation is unsafe.
- Keep the final 20% (about 70,600 tokens) for recovery, validation, and unexpected output.
```

## Edit 3 — `docs/05_workflow/GITHUB_RULES.md`

Add to the commit-format rules, matching the file's existing style:

```markdown
- Checkpoint commits capture incomplete, unvalidated work at a session boundary. Format: `checkpoint(<T-### or package id>): <one-line scope>`. A checkpoint commit must be listed in a WORKLOG checkpoint entry, and the owning task must review it at its next session start before further edits.
```

## Edit 4 — `AGENTS.md`

Add one line where the core/workflow rules are listed (placement at Codex's discretion, keep it one line):

```markdown
- One `T-###` task per session; end the session after closeout (see `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`, Session Budget Rules).
```

## Edit 5 — `docs/05_workflow/TOOLING_POLICY.md` (cross-check only)

Read its `## Validation` section. If it duplicates per-mode validation facts that Edit 1c changes, update those lines to match (single source of truth); if it only defers to `SINGLE_AGENT_WORKFLOW.md`, change nothing.

## Edit 6 — Ignore files

- `.gitignore`: under the external-report block, add `UI_DESIGN_RULES_PROPOSAL.md` and `CONTEXT_QUOTA_GOVERNANCE_PLAN.md`. Add a new line `artifacts/evidence/` next to the existing `artifacts/testops/` entry.
- `.rgignore`: add the two report filenames to the external-report block (the existing `artifacts/**` line already covers evidence).

## Edit 7 — `docs/07_decisions/DECISION_LOG.md`

One entry in the file's existing format, content:

```text
Session-per-task context budget (this task, 2026-07-10). One T-### per session; session ends
at closeout; 65%/80% compaction thresholds demoted to fallback for a single oversized task.
Standard slices validate with focused tests + one build; full ios-test.sh reserved for
package/integration gates, Deep tasks, shared-layer changes, and pre-release. Visual evidence
saved under artifacts/evidence/<task-id>/ and referenced by path, never re-ingested; full build
logs read only filtered. Clean-tree session boundaries via checkpoint(<id>) commits; stash
banned at boundaries. Rationale: per-turn cost scales with conversation size — the T-249..T-257
mega-session plus ~19 unattributed modified files drove context/quota growth, while build
scripts were already summary-mode and active Markdown already minimal, so doc compression had
no remaining leverage. Affected: AGENTS.md, SINGLE_AGENT_WORKFLOW.md, CONTEXT_AND_RECOVERY.md,
GITHUB_RULES.md, TOOLING_POLICY.md (cross-check), .gitignore, .rgignore.
```

## Phase 1 closeout

1. Validation: `git diff --check` and `node scripts/context-hygiene-check.mjs`; rotate once via `node scripts/context-rotate.mjs --apply` if a window exceeds its trigger. No iOS build/simulator for this docs-only task.
2. Ledger row + worklog entry per Completion Gate; `CURRENT_STATE.md` replacement updates (active workflow state: session-per-task effective; next-task facts unchanged for Q-104).
3. Archive this file to `docs/09_frozen/external_agent_reports/` (leave `UI_DESIGN_RULES_PROPOSAL.md` at root — it is consumed by a separate, still-pending task).
4. Task-prefixed commit; push; report; **end the session**.

## Acceptance checklist

- [ ] Phase 0: every modified file classified, disposed, checkpoint committed/pushed (or confirmed discarded); WORKLOG checkpoint entry + CURRENT_STATE facts updated; mega-session terminated.
- [ ] Phase 1: Edits 1–7 applied verbatim in intent (wording may adapt to each file's local style, meaning must not change).
- [ ] `rg -n "Session Budget Rules|checkpoint\(" docs/05_workflow AGENTS.md` shows the new rules wired in all four documents.
- [ ] Hygiene passes; ledger/worklog/current-state/decision-log updated; this file ignored and archived; commit pushed; session ended.

## Out of scope (do not do)

- No changes to `scripts/*` (already summary-mode), no Markdown compression, no `CLAUDE.md` edits (already consistent: one build per standard slice), no app/backend/design code, no Supabase, no subagents, no PR/tag/branch operations.
