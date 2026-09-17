# Archived Worklog Entry: T-157 APNs Credential Note

Source: `docs/00_memory/WORKLOG.md`

Archived on 2026-07-07 during T-168 to keep the active worklog within the context hygiene 10-entry recovery window.

Entry is preserved verbatim.

```text
Date: 2026-07-07
Task: T-157 - APNs credential availability note.
Files changed: memory docs only.
Checks: `git diff --check`; `node scripts/context-hygiene-check.mjs`.
Remote: No remote writes.
Result: Recorded that the user currently has a free Apple Developer account, so APNs Auth Key / Push Notifications capability is not available yet. T-157 Edge Function deployment remains blocked until Apple Developer Program upgrade provides APNs Key ID, Team ID, topic confirmation, and `.p8` private key.
Risks: In-app notifications and the T-157 database/iOS foundation remain usable; actual remote APNs delivery is deferred.
```
