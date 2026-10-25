# SwiftUI Flow Sandbox Workflow

## Scope

For requested isolated Preview flows and UX experiments, use this workflow instead of standard lifecycle and closeout gates. [Development Guide](DEVELOPMENT_GUIDE.md) safety and authorization rules remain applicable; host instructions and explicit user scope take precedence. Reuse existing Views, Stores and navigation.

When the user requests an independently editable UI prototype, reuse the existing UI snapshots in `FlowSandbox/Prototype/`, not live `Features/` Views. Copy only missing customer UI/components/styles, initially preserving their presentation and routing child destinations to prototype copies. Continue sharing the existing isolated session, fixtures and Stores. Edit prototype UI/styles only; shared business code and bundled assets remain read-only unless separately authorized. Do not automatically synchronize snapshots back to production or overwrite prototype edits from production. After an explicitly approved adoption, a host may use production views for acceptance (T-420 does so); that host is not an independently editable prototype. For subsequent UI experiments, route only the requested flow back to its existing prototype copies before editing them. Existing `FlowSandbox/Design/` experiments are preserved and use the same prototype components.

Reuse compatible sandbox support code first: Preview hosts, mock repositories, fixtures, session isolation and reset controls. For an existing flow, reuse its setup; for a new flow, add only missing data, dependencies and navigation, never rebuild from scratch by default. Extract shared helpers only when actual repetition warrants it, without weakening isolation or building a speculative workbench/framework.

For pure UI exploration, required fields and real-service validation must not block navigation by default. Fill missing display data with local fixtures, preserving user-entered values. Confine relaxed navigation to isolated sandbox injection; never change normal App validation or data, or trigger real submissions. When validation/error behavior is explicitly under test, retain the relevant checks or simulate their outcomes.

## Safety

- Inspect startup and the requested flow for real I/O and external side effects. Isolate those boundaries; reuse pure logic and already isolated dependencies without rebuilding their dependency chains.
- Use memory or unique disposable session storage, never live accounts/services, production caches, Keychain or shared defaults. Prevent real notification scheduling, telemetry and other external side effects. If isolation is uncertain, resolve it before running; `DEBUG` alone is not isolation.
- Keep experiments out of normal App execution. Preserve user edits, signing and project configuration; do not weaken production validation or replace normal services with mocks.

## Acceptance

- Run the requested core path in Live Preview. Add focused tests for new or changed persistence, isolation or asynchronous recovery logic; layout and fixture-value edits alone do not require new tests. Reuse valid evidence while relevant code, configuration and environment are unchanged.
- A current Canvas build supplies compilation evidence for its configuration. Pure sandbox work needs no additional Debug/Release build, full regression or repository preflight. UI design principles still apply, but do not import full accessibility/keyboard/device matrices for unchanged production UI.
- Use existing interaction tools and only necessary screenshots; stop unchanged retries. Keep Xcode writers serial. If Canvas is unavailable, an existing isolated Simulator entry may help; report exactly what was verified, without claiming unperformed Preview interaction or building a new harness to bypass tooling.

## Escalation

- Escalate actual production effects, not file location or adding a Preview-only `#if DEBUG` block. Minimal extraction/injection changes need focused evidence for affected production behavior. Changes to normal App startup or production-code compilation boundaries additionally need normal-startup verification and a Release compile check.
- Adopting experimental UX or changing shared business/security behavior uses standard validation for affected consumers only. Wider regression needs an affected-contract reason. Broader product, backend, dependency or capability changes require adopted scope; sandbox mode grants no extra authorization.

## Delivery

- Deliver local files with the Preview entry, verified behavior and remaining limits. No default task ID, plan, decision entry, acceptance report or automatic commit/push. Sandbox acceptance is not production readiness.
- Use existing Current State recovery only when unfinished work needs a durable checkpoint; preserve other tasks. Explicit Git delivery follows existing task-ID and scoped staging rules, without adding full regression solely for a commit.
