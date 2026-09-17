# Context Window Rotation Redesign

Task: T-245
Date: 2026-07-09

## Problem

The current rolling-window trigger and retained count are identical. A task that adds the thirteenth ledger row or ninth worklog entry rotates only one old item and leaves the file full, so the next task rotates again. Separate per-file and total word limits also create repeated compression pressure even when document structure is healthy.

## Decisions

Word counts remain visible telemetry only. No word count or percentage may warn, fail validation, stop closeout, trigger compression, or trigger archive rotation. The existing task-ledger row-length check remains a format check for one oversized entry; it never initiates bulk compression.

Rolling files use separate trigger and retained counts:

| Window | Trigger when count is | Retain after rotation | Guaranteed free entries |
|---|---:|---:|---:|
| Task ledger rows | greater than 18 | 12 | 6 |
| Worklog entries | greater than 14 | 8 | 6 |
| Active decisions | greater than 14 | 8 | 6 |

One rotation archives all oldest eligible items needed to reach the retained count. Task-ledger rotation may move only completed rows; blocked or current rows remain active. If eligible items are insufficient, the script reports the unresolved structural overflow once and exits without repeated trimming.

Decision rotation creates one active archive pointer per archive batch instead of one pointer per decision. Archive-batch pointers are themselves a bounded window: more than 12 pointers rotates the oldest pointers to a frozen index and retains 6.

FIXED and INDEX documents use ownership and replacement semantics. Obsolete facts are replaced or moved to history only when their meaning changes; they are never shortened merely to satisfy word telemetry.

## Session Context Policy

The model context reference is 353,000 tokens. Repository rules allocate it operationally rather than estimating Markdown words as tokens:

- below 65% (about 229,000 tokens): continue normally without manual compaction;
- 65% to below 80%: finish the current task and compact only before a new large or risky task;
- at or above 80% (about 282,000 tokens): write a checkpoint and compact at the task boundary;
- the final 20% (about 70,600 tokens) is recovery, validation, and unexpected-output reserve.

Automatic platform compaction cannot be controlled by repository rules. These thresholds govern only agent-requested compaction. Layered L0-L4 reads remain mandatory so active Markdown is not loaded wholesale.

## Implementation Surface

Update the context policy, hygiene check, rotation script, focused Node tests, agent/workflow rules, and T-245 decision/closeout records. Do not change Swift, Supabase, dependencies, product behavior, or remote services.

## Validation

Tests must prove that counts at the trigger do not rotate, trigger-plus-one rotates directly to the retained count, six subsequent task entries fit, blocked rows survive, decision pointers are batched, and reference word excess still passes. Final checks are the focused Node suites, `git diff --check`, and context hygiene.
