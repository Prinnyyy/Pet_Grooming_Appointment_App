<!-- task-artifact
task: T-466
status: complete
type: plan
-->

# T-466 · Adopt Groomer Grooming

Status: complete. Technical acceptance passed; user visual acceptance remains user-owned. User approved production adoption on 2026-11-05. Source of truth: the current Groomer FlowSandbox design and adopted rules in `docs/01_product/DETAIL_FORM_COMPONENT_RULES.md`. Existing prototypes remain independently editable. Preserve pre-existing edits and signing. No subagents.

## Scope and acceptance

- Grooming replaces Requests as the groomer workspace: Matches (All/Studio/Home visits), Offers (Waiting/Accepted/Closed), Bookings (Active/Closed). Manual major-tab switch resets the destination subtab. Accepted offers remain request detail with View booking; booking actions do not leak onto accepted offer cards. Withdrawn offers leave Offers. Preserve pending data during refresh, cursor paging, account isolation and persisted read state.
- Adopt Request/Offer details, pet profile, current C3-A form, confirmation modals, original progress animation, semantic bubbles/panels/list notes, footer styles and navigation/keyboard behavior. Keep current geometry, typography and motion. No fixture IDs, fake names, fake success, memory-only chat or preview validation bypass in production.
- Adopt Booking detail, shared appointment/time/price rows, time proposal/accept/reject/withdraw, success toast, conflict checking, Activity and Review presentation. Time proposal lower bound is the current instant; unchanged times cannot submit; server checks the entire interval and concurrent operations. Price is read-only.
- Service begins at scheduled time without a participant action. Either participant may finish after start, with no confirmation from the other; elapsed end alone never marks complete. Remove interruption/unfulfilled/outcome-confirmation paths from new actions; retain historical records safely. Customer can review once finished.
- Prebooking contact: invitation grants the groomer first-message rights, valid offer grants the customer first-message rights. An expired/revoked basis cannot start a new conversation; established text conversations remain available subject to existing safety/access restrictions. Existing booking chat and message retry identity remain.
- Independent offers stay under the same request; locked booking acceptance invalidates overlapping unaccepted offers with an explicit reason. Do not introduce offer-version chains or replacement requests/bookings.
- Activity records booked time, each time-change operation with its actor and timestamp, completion, review and cancellation. Only the proposal entry repeats old/new service intervals. Server history must survive reload/restart; no invented action timestamps.

## Work packages

1. **Production presentation boundaries**: map sandbox components to production owners; promote adopted presentation and motion helpers with no DEBUG/fixture dependency; keep historical design studies out of production. Adapt existing stores and routes, no all-pages eager fetch copied from sandbox.
2. **Authoritative contracts**: inspect latest applied definitions; append migrations for lifecycle, offer overlap closure, contact grants and activity history. Retain RLS, actor checks, version locks, idempotent receipts and notification semantics. Prepare negative and concurrency cases. Remote deploy only after reviewed concrete scope and explicit authorization.
3. **Client adoption**: real workspace/cache/paging/read state; detail/form/modals; chat and photo permissions; both participants' lifecycle and review compatibility; existing Home/Schedule/notifications/deep links use adopted details.
4. **Validation and delivery**: focused tests for changed behavior, single-writer Debug/Release compilation, integrated regression at integration point, simulator behavioral checks; user owns visual acceptance. No store-signing/distribution scope. Migration dry-run/deploy verification separately recorded. Preflight and relevant documentation updates before completion; no partial-completion claims.

## Current findings / checkpoints

- Sandbox workspace drains all pages and carries session-only read markers. Production must keep existing bounded pagination/cache behavior.
- Sandbox request chat is a memory-only repository with fixture name fallbacks; cannot be promoted as a backend implementation.
- Core GroomerBookingStage and fulfillment actions still contain manual start/close-out/confirmation. Merely adopting the sandbox card cannot implement the approved service lifecycle.
- Sandbox time-change Activity is captured by the fake repository; production proposal DTO lacks operation timestamps/history. A real history contract is needed.
- Pre-adoption baseline archive: `artifacts/evidence/T-466/pre-adoption-source.tgz` (local/ignored).

## Local integration checkpoint

- Production Grooming workspace/details, shared presentation, bounded filtered paging, request contact and lifecycle compatibility are implemented. Prototype remains independent; no sandbox fake repository is referenced by production presentation.
- Debug compilation and relevant integrated regression completed. Corrected stale fixture/route expectations; fixed initial chat bottom positioning and tab-root visibility ownership. Store tests (111), corrected contract tests (37), workspace tests (3), viewport/tab-return tests (4), owning-tab UI flow (1) pass. Full run's 40 opt-in UI skips remain explicit. Coordinate swipe automation did not pass; semantic Back route passed and must not be described as end-to-end swipe acceptance.
- Current preflight passed (`artifacts/evidence/T-466/preflight-final-local.log`). Release build evidence: `artifacts/evidence/T-466/build-release.log`; final result recorded in Current State.
- Six migrations were explicitly authorized and deployed after rollback runtime verification. The delivery record below supersedes the earlier pending-deployment checkpoint.

## Deployment and acceptance

- Six migrations `20261106064746` through `20261106064753` applied; linked history aligned and repeat dry-run reports up to date (`migration-list-after.txt`, `deploy-repeat-dry-run.txt` under `artifacts/evidence/T-466/`). Applied SQL is immutable.
- Transactional fixture passes proposal outside preferred window, adjacency, overlap invalidation, independent reoffer/withdrawal, consent and revocation, outsider rejection, reschedule conflict/no-op/history, either participant completion, intent replay and review (`rollback-validation-6.log`). Found and fixed an ambiguous acceptance-column reference before deployment. Synthetic review timestamp is aligned only inside the rollback fixture because one SQL command shares one statement timestamp; no production timing bypass was introduced.
- Real JWT HTTP race uses a database barrier proving two simultaneous blocked acceptance transactions; exactly one overlapping booking is created. Concurrent replay returns the same booking. Withdrawal blocks an unstarted conversation; a new offer receives a new ID; established text chat remains available. Disposable actors and their requests/bookings/conversations/locations all return to zero (`http-acceptance.json`, `http-race-barrier.log`, `http-cleanup.json`). Existing account settings/orders were not mutated.
- Post-deploy security: every public table has RLS; conflict storage has RLS and no client/anonymous access; clients cannot forge message kind; all five new public RPCs reject anonymous execution. Three authenticated SECURITY DEFINER read RPC advisories are intentional participant-scoped projections, reviewed with actor/ownership guards and negative tests; no anonymous grant. Existing leaked-password-protection warning is unchanged (`security-after.json`, `table-security-after.json`, `advisors-after.json`).
- A real test-account simulator login and production Grooming Matches/Offers/Bookings/subtab reset flow passed (`client-connected-smoke.log`). Stable accessibility containment/identifiers added without changing visuals. User owns visual acceptance. The prior coordinate-swipe test is not counted as a pass; native tab-return unit/runtime coverage and semantic Back routing are separate evidence.

## Delivery

- Final Release build passed (`build-release-final.log`), production-connected simulator scope check passed, and the workspace paging/session/exact-lookup tests pass using existing test doubles independent of uncommitted sandbox paging changes (`workspace-delivery.log`). Final preflight passed (`preflight-delivery.log`); document hygiene and staged diff checked.
- Scope: production code and adopted design specification only. Uncommitted sandbox studies, sandbox-only DEBUG hooks, local signing, and unrelated governance edits are preserved locally. The source baseline archive remains local evidence. No App Store/device distribution changes.
- Visual appearance remains for the user's inspection; simulator/HTTP assertions do not claim visual approval. Security advisory review and opt-in/skipped test limitations above remain explicit.
