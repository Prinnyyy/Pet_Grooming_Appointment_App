# T-235 Remote Lifecycle and Matching Evidence

Date: 2026-07-09. Project: `lqmasbuqzvcvtawonjlb`. Branch: `codex/pet-fit-structure-cleanup`.

## Gates

- User authorization, `--execute`, `--cleanup`, and process-local `TESTOPS_REMOTE_WRITE_APPROVED=1` were present.
- `./scripts/testops-unit.sh` passed 28 tests after the redaction correction.
- Doctor detected 50 customer and 50 groomer profiles, URL, publishable key, and modern server credential; the remote-write env remained unset outside execute processes.
- Dry runs generated 5 lifecycle and 8 matching plans before writes.

## Remote Results

| Run | Result | Cleanup |
|---|---|---|
| `TESTOPS-Q37-SMOKE-R2-20260709T2155Z-*` | 5/5 lifecycle cases passed sign-in, pet load, request, target match, offer, acceptance, completion, review, and final-state assertions | Each case deleted its tagged request tree; final tagged request residue `0` |
| `TESTOPS-Q37-MATCH-R2-20260709T2157Z-*` | 8/8 matching cases passed; five target inclusions, same-day alternative-time reason, and three hard-filter exclusions matched expectations | Each case deleted its tagged request/matches; final tagged request residue `0` |

Lifecycle final state was consistently request `booked`, offer `accepted_by_customer`, booking `completed`, and one review. Matching counts were 14, 14, 34, 14, 24, 22, 14, and 10.

## Redaction Correction

The first smoke execution passed and cleaned up, but exposed full entity UUIDs in console JSON and raw JSON artifacts. Execution stopped before matching. T-235 added shared lifecycle/matching result redaction, artifact redaction, modern-secret doctor status, and regression tests. The unsafe first-run artifacts were deleted; its remote tag residue was `0`.

The R2 runs printed only 8-character support references. Scans of 10 lifecycle and 16 matching R2 artifacts found zero full UUIDs and zero credential patterns. Generated artifacts remain ignored local evidence and are not committed.
