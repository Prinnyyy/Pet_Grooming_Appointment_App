<!-- task-artifact
task: T-438
status: completed
type: plan
-->

# T-438 Skeleton parity and Schedule continuity

Audit production skeleton/content pairs against the current adopted UI, beginning with Groomer Home count tiles; fix clear structural, surface, typography and Dynamic Type drift without redesigning loaded pages. Unknown variable content cannot predict its eventual length/count; preserve shared sizing rules rather than clipping real content to a placeholder.

Schedule: reproduce calendar metadata clearing, competing initial/foreground reads, scoped reload placeholders and date-load bars resetting to zero. Keep known same-scope content during background refresh, keep first-load/changed-scope placeholders, preserve errors, session guards, range validation and authoritative booking actions. Reuse the existing foreground gate and scoped reads; no disk cache or backend change.

Use focused regression/layout tests and a relevant integrated Simulator run, build and standard static checks; visual inspection belongs to the user. Reuse valid evidence and keep the previous task's independently reproduced navigation timing issue out of this task. Main assistant only. Preserve existing user governance/signing/prototype files. After acceptance update this record and design rules, then scoped completion commit/push on current main.

## Findings and results

Home's obsolete two-line label and separately measured counter block made its skeleton about 155pt against a roughly 110pt loaded tile at the default size. Its ledge surface already existed; an early surface diagnosis was corrected. The date strip was about 9–10pt shorter. Failing tests reproduced these differences and calendar clearing / duplicate same-scope reads before implementation (`/tmp/beckon-t438-red.xcresult`).

| Audited family | Result |
|---|---|
| Groomer Home | Tile reuses the real component's sizing and surfaces, holding hidden real text under placeholder overlays. Counter scaling keeps its line box. Hero chips/button use real flow and button sizing. Coming-up rows mirror accessibility reflow. |
| Schedule | Date strip reuses real tiles, columns and lip spacing. Now-card typography/header/button sizing and appointment-row message slot/accessibility arrangement match the real owners. |
| Groomer Requests / shared detail | Request-row skeleton mirrors responsive summary/chevron layout; groomer request detail uses its own three-stop path. Shared detail identity stacks at accessibility sizes. |
| Account shortcuts | Known title/description text measures the placeholder instead of arbitrary line counts. Customer static copy and groomer summaries are passed from the real owners. |
| Pet cards, Grooming cards/path, account identity/settings/danger actions, chat list | Inspected current frames, typography, avatars, row count/padding and surface owners. Existing shared fixed/scaled frames and layouts retained; unknown variable content remains an estimate, never a promise of whole-page pixel equality. |
| Shared text placeholder | Hidden measuring text is restricted to one line, preventing narrow columns from accidentally growing a one-line bar. |

A diagnostic isolated system redaction itself changing a Home tile's wrap at xxxLarge (plain 137.3pt, redacted 111.3pt, independently of count). Native whole-tile redaction was replaced with hidden original sizing content plus overlay placeholders. No fixed clipping heights were added; static button skeletons also reserve the same press room as their loaded buttons. Focused acceptance passed 5 XCTest cases and 25 Swift tests before the final account shortcut addition; final relevant integration/build/static evidence follows at closeout.

Schedule retains calendar/hours during pending and transient-failed metadata reads, with a separate verification state; explicit metadata access loss and malformed authoritative snapshots clear them. Removed the competing initial page load, using the existing foreground gate. Same-interval concurrent reads coalesce; automatic recent reads reuse the existing five-second policy, while explicit refresh and stale write invalidation bypass freshness reuse. Session/operation/range/pagination checks remain; cancelled range reads restore the prior state. One small read-presentation value controls same-week snapshot retention, first/changed-scope placeholders and verification feedback. Known empty is retained, known date bars do not reset to zero, and unknown days are not announced as empty.

Validation is bounded to affected Stores/layouts and representative production runtime integration. The previous task's unrelated native-route timing failure is not an acceptance claim here. A mistaken help invocation of the argument-less test wrapper was interrupted during compilation, before any tests ran; it is not passing evidence and the wrapper was not changed. Relevant integration (`/tmp/beckon-t438-integration.xcresult`) passed 96 cases and found three failures: shortcut press-room geometry, the old transient-failure clearing expectation, and malformed snapshot revocation. Preserved the malformed-data protection, changed only the transient-network expectation to retained/unverified, and matched button press room from existing tokens. Recovery (`/tmp/beckon-t438-recovery.xcresult`) passed 53/53, reusing unaffected passing integration evidence. Combined **99 unique cases passed**, with the renamed transient-failure test counted once (`/tmp/beckon-t438-validation-summary.json`). The runtime integration rendered 72 groomer module/state/size samples, plus four booking schedule states; this is rendering smoke and measured layout evidence, not visual-equivalence proof.

Full preflight passed (`/tmp/beckon-t438-preflight.log`); final iOS source contracts 27/27 and UI audit passed with no added exemptions (109 findings, 24 baseline entries). Generic Simulator build passed (`/tmp/beckon-t438-build.log`); final full documentation hygiene and scoped diff review passed at closeout. No live accounts, remote data, new dependency, persistence layer, screenshot tour or prototype changes.
