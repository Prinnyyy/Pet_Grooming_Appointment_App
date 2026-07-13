# UI Consistency Governance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement one package per fresh session. Repository rules disable subagent execution and require one primary `T-###` task per session.

**Goal:** Enforce Beckon UI consistency from code, then migrate Customer Home, Requests, Request creation, and Account onto the governed semantic system.

**Architecture:** Evolve the existing `DesignTokens` and Beckon primitives in place. A dependency-free Node scanner records current Feature debt and rejects new debt; shared SwiftUI components own repeatable presentation; each Customer surface becomes a zero-debt slice without changing Store, repository, navigation, or backend behavior.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, Node.js built-ins and `node:test`, existing Xcode synchronized groups, existing repository preflight scripts.

## Global Constraints

- Use the current branch and next task ID from `CURRENT_STATE.md` and `TASK_LEDGER.md`; Q package IDs below do not preassign future `T-###` IDs because periodic meta-review may consume one.
- Execute exactly one Q package per fresh session, including tests, docs closeout, commit, and push.
- Do not add SwiftLint, SwiftSyntax, packages, or other dependencies.
- Do not modify Stores, repositories, models, navigation flow, Supabase, or product behavior.
- Preserve Customer/Groomer role differences; do not replace Groomer grouped workspace layouts with Customer cards.
- Preserve Dynamic Type, VoiceOver, Reduce Motion, safe areas, long text, localization, native controls, and 44-point touch targets.
- Use screenshots only for final clipping/rendering checks. Audit output, component usage, tests, and code review determine consistency.
- The user-deferred Groomer Q-104 accessibility gate remains deferred.
- Every implementation package updates its Q row in `ROADMAP_EXECUTION_QUEUE.md`, closes its `T-###` row in `TASK_LEDGER.md`, adds one newest `WORKLOG.md` entry, and updates `CURRENT_STATE.md` only with facts needed by the next run.

## File Map

### New Governance Files

- **scripts/ui-consistency-audit-core.mjs**: Swift lexical masking, rule evaluation, fingerprints, and baseline comparison.
- **scripts/ui-consistency-audit.mjs**: CLI for `check`, `strict`, `baseline initialize`, and `baseline prune`.
- **scripts/ui-consistency-baseline.json**: versioned legacy Feature findings only.
- **tests/scripts/ui-consistency-audit.test.mjs**: lexer, rule, baseline, exception, CLI, and false-positive tests.
- **docs/04_ios/UI_CODE_GOVERNANCE.md**: short active rule, severity, command, baseline, and exception reference.

### DesignSystem Files

- `ios/Beckon/Beckon/DesignSystem/DesignTokens.swift`: semantic typography, layout, metrics, status text colors, and canonical elevation.
- `ios/Beckon/Beckon/DesignSystem/BeckonActionPrimitives.swift`: shared visually-unavailable primary style and semantic action metrics.
- **ios/Beckon/Beckon/DesignSystem/BeckonLayoutPrimitives.swift**: page insets, sections, and grouped surface.
- **ios/Beckon/Beckon/DesignSystem/BeckonSelectionPrimitives.swift**: selectable card and settings-row label.
- `ios/Beckon/Beckon/DesignSystem/BeckonFormPrimitives.swift`: field metrics and semantic field group.
- **ios/Beckon/Beckon/DesignSystem/BeckonComponentCatalog.swift**: DEBUG-only preview catalog; never routed into production navigation.
- `ios/Beckon/BeckonTests/DesignTokenAccessibilityTests.swift`: contrast coverage.
- **ios/Beckon/BeckonTests/DesignSystemContractTests.swift**: stable numeric and component-state contracts.

### Customer Slice Files

- `Features/Customer/Pets/CustomerPetsView.swift`: Customer Home after pet-form extraction.
- **ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetFormView.swift**: behavior-preserving move of existing pet editor code.
- `Features/Customer/Requests/CustomerRequestsView.swift`: Requests page container.
- `Features/Customer/Requests/CustomerRequestsDashboardView.swift`: Requests header, cards, timeline, and actions.
- `Features/Customer/Requests/CustomerRequestWizardView.swift`: Wizard hierarchy, selection cards, fields, and action bar.
- **ios/Beckon/Beckon/Features/Customer/Profile/CustomerAccountView.swift**: extracted Account root and Account-only components.
- `Features/Customer/Profile/CustomerProfileSettingsView.swift`: profile editor only after Account extraction.
- Existing Customer Pet, Request, and Profile Swift tests remain behavior regression owners.

---

### Task 1 / Q-113: UI Source Audit And Debt Ratchet

**Files:**
- Create: **scripts/ui-consistency-audit-core.mjs**
- Create: **scripts/ui-consistency-audit.mjs**
- Create: **scripts/ui-consistency-baseline.json**
- Create: **tests/scripts/ui-consistency-audit.test.mjs**
- Create: **docs/04_ios/UI_CODE_GOVERNANCE.md**
- Modify: `scripts/preflight.sh`
- Modify: `tests/scripts/preflight.test.mjs`
- Modify: `docs/01_product/DESIGN_SYSTEM.md`

**Interfaces:**
- Produces: `auditSwiftSource({ filePath, source }) -> Finding[]`.
- Produces: `compareWithBaseline(findings, baseline, strictPaths) -> { newErrors, staleEntries, strictFindings }`.
- Produces CLI command **node scripts/ui-consistency-audit.mjs check**.
- Produces CLI command **node scripts/ui-consistency-audit.mjs strict path-a.swift path-b.swift**.
- Produces CLI commands **node scripts/ui-consistency-audit.mjs baseline initialize --reason Q-113**, **baseline prune --reason Q-116**, and a guarded **baseline relocate** for unchanged code moved between files.

- [ ] **Step 1: Write lexer and rule tests first**

Create fixture-driven tests with these exact cases:

```js
import assert from "node:assert/strict";
import test from "node:test";
import {
  auditSwiftSource,
  compareWithBaseline,
  maskSwiftNonCode,
} from "../../scripts/ui-consistency-audit-core.mjs";

test("lexer masks comments and strings while preserving positions", () => {
  const source = [
    "Text(\".font(.system(size: 99))\")",
    "// .padding(91)",
    "Text(title).font(.system(size: 28, weight: .bold))",
  ].join("\n");
  const masked = maskSwiftNonCode(source);
  assert.equal(masked.split("\n").length, 3);
  assert.doesNotMatch(masked, /size: 99|padding\(91/);
  assert.match(masked, /system\(size:\s*28/);
});

test("audit classifies deterministic and review findings", () => {
  const findings = auditSwiftSource({
    filePath: "ios/Beckon/Beckon/Features/ExampleView.swift",
    source: "Text(title).font(.system(size: 28)).padding(13).offset(x: -2)",
  });
  assert.deepEqual(findings.map((finding) => finding.ruleID), [
    "UI001", "UI004", "UI102",
  ]);
  assert.deepEqual(findings.map((finding) => finding.severity), [
    "error", "error", "warning",
  ]);
});

test("baseline rejects new errors and stale debt", () => {
  const existing = {
    version: 1,
    scope: "ios/Beckon/Beckon/Features",
    findings: [{
      ruleID: "UI001",
      path: "A.swift",
      fingerprint: "a",
      expressionHash: "same-expression",
      occurrence: 1,
    }],
  };
  const result = compareWithBaseline([
    { ruleID: "UI004", path: "B.swift", fingerprint: "b", occurrence: 1, severity: "error" },
  ], existing, []);
  assert.equal(result.newErrors.length, 1);
  assert.equal(result.staleEntries.length, 1);
});
```

- [ ] **Step 2: Run RED**

Run: **node --test tests/scripts/ui-consistency-audit.test.mjs**

Expected: FAIL because **scripts/ui-consistency-audit-core.mjs** does not exist.

- [ ] **Step 3: Implement the lexical core and rule registry**

Implement a character-state scanner that replaces non-newline characters inside line comments, nested block comments, normal strings, multiline strings, and character escapes with spaces. Preserve source length and newlines so indexes map back to exact locations. Rules operate on masked code and use balanced-parenthesis expansion to capture the whole modifier call.

Use these exact exported shapes:

```js
export const UI_RULES = Object.freeze([
  { id: "UI001", severity: "error", category: "typography", message: "Use Beckon semantic typography." },
  { id: "UI002", severity: "error", category: "typography", message: "Use Beckon semantic typography instead of a platform style in migrated or new Feature code." },
  { id: "UI003", severity: "error", category: "color", message: "Use DesignTokens semantic colors." },
  { id: "UI004", severity: "error", category: "spacing", message: "Use a semantic layout token or shared component." },
  { id: "UI005", severity: "error", category: "shape", message: "Use a DesignTokens shape role or shared surface." },
  { id: "UI006", severity: "error", category: "elevation", message: "Use beckonShadow with a canonical elevation role." },
  { id: "UI007", severity: "error", category: "local-style", message: "Move repeatable presentation styles into DesignSystem." },
  { id: "UI008", severity: "error", category: "text-fit", message: "Reflow text; scale factors below 0.85 are not allowed." },
  { id: "UI101", severity: "warning", category: "fixed-geometry", message: "Review fixed geometry for dynamic text risk." },
  { id: "UI102", severity: "warning", category: "layout-patch", message: "Review offset or negative spacing as a layout repair." },
  { id: "UI201", severity: "review", category: "duplicate-stack", message: "Review repeated visual modifier stacks for a semantic component." },
]);

export {
  auditSwiftSource,
  compareWithBaseline,
  fingerprintFinding,
  maskSwiftNonCode,
};
```

Accept only a single-site directive immediately before the finding:

```swift
// beckon-ui-audit: allow UI101 -- Fixed square media crop; text is outside this frame.
```

Reject wildcard rules, missing reasons, directives separated from the finding by code, and directives that no longer suppress a finding.

- [ ] **Step 4: Implement CLI and baseline lifecycle**

The CLI scans tracked/unignored `.swift` files under `ios/Beckon/Beckon/Features`. `check` fails on new error findings and stale baseline entries. `strict` fails on every error finding in the named paths, even when baselined. `baseline initialize` refuses to overwrite an existing baseline. `baseline prune` removes stale entries only and can never accept a new finding. `baseline relocate --from old.swift --to new.swift --reason Q-116` updates paths only when every relocated finding has an identical rule ID, path-independent `expressionHash`, and occurrence count at the destination; otherwise it exits `2` without writing.

Write JSON in this stable shape:

```json
{
  "version": 1,
  "scope": "ios/Beckon/Beckon/Features",
  "lastChange": { "reason": "Q-113" },
  "findings": [
    {
      "ruleID": "UI001",
      "path": "ios/Beckon/Beckon/Features/ExampleView.swift",
      "fingerprint": "sha256-value",
      "expressionHash": "path-independent-sha256-value",
      "occurrence": 1
    }
  ]
}
```

Human output format: `path:line:column: severity UI001 message [replacement]`. JSON output is selected with `--format json`. Exit `0` for clean/unchanged debt, `1` for findings, `2` for invalid CLI/config.

- [ ] **Step 5: Generate and review the one-time baseline**

Run: **node scripts/ui-consistency-audit.mjs baseline initialize --reason Q-113**

Then run: **node scripts/ui-consistency-audit.mjs check**

Expected: PASS with legacy counts by rule and no new/stale findings. Review the generated paths to ensure only `Features/**/*.swift` appear and no comment/string false positives remain.

- [ ] **Step 6: Wire preflight and its hermetic fixture**

Add after Beckon identity checks in `scripts/preflight.sh`:

```bash
echo "-- UI consistency --"
node scripts/ui-consistency-audit.mjs check
```

Update `tests/scripts/preflight.test.mjs` to copy both UI audit scripts and a minimal baseline into the fixture, create one clean **ios/Beckon/Beckon/Features/FixtureView.swift**, and assert `/UI consistency audit passed/`.

- [ ] **Step 7: Document governance and verify**

Document the rule table, commands, baseline invariants, exception syntax, and severity meaning in **docs/04_ios/UI_CODE_GOVERNANCE.md**; link it from `DESIGN_SYSTEM.md`.

Run:

```bash
node --test tests/scripts/ui-consistency-audit.test.mjs tests/scripts/preflight.test.mjs
node scripts/ui-consistency-audit.mjs check
./scripts/preflight.sh
git diff --check
```

Expected: all tests and checks pass.

- [ ] **Step 8: Close Q-113 and commit**

Commit: `test: add UI consistency audit ratchet`

---

### Task 2 / Q-114: Semantic Tokens And Contrast

**Files:**
- Modify: `ios/Beckon/Beckon/DesignSystem/DesignTokens.swift`
- Modify: `ios/Beckon/Beckon/DesignSystem/BeckonActionPrimitives.swift`
- Modify: `ios/Beckon/BeckonTests/DesignTokenAccessibilityTests.swift`
- Create: **ios/Beckon/BeckonTests/DesignSystemContractTests.swift**
- Modify: `docs/01_product/DESIGN_SYSTEM.md`

**Interfaces:**
- Produces `DesignTokens.Typography.pageTitle`, `sectionTitle`, `cardTitle`, `body`, `supporting`, `fieldLabel`, `status`, and `action`.
- Produces `DesignTokens.Layout` and `DesignTokens.Metrics` values used by Q-115 through Q-119.
- Produces `Colors.successText`, `warningText`, and `errorText`.

- [ ] **Step 1: Add failing contract and contrast tests**

```swift
@Test func semanticLayoutMetricsUseTheApprovedGrid() {
    #expect(DesignTokens.Layout.pageHorizontalInset == 20)
    #expect(DesignTokens.Layout.sectionSpacing == 24)
    #expect(DesignTokens.Layout.surfaceInset == 16)
    #expect(DesignTokens.Layout.rowVerticalInset == 12)
    #expect(DesignTokens.Metrics.minimumTouchTarget == 44)
    #expect(DesignTokens.Metrics.fieldHeight == 52)
    #expect(DesignTokens.Metrics.actionHeight == 52)
    #expect(DesignTokens.Metrics.settingsIconSlot == 36)
}

@Test func statusTextColorsMeetAAOnSurface() {
    for color in [
        DesignTokens.ColorHex.successText,
        DesignTokens.ColorHex.warningText,
        DesignTokens.ColorHex.errorText,
    ] {
        #expect(Self.contrastRatio(color, DesignTokens.ColorHex.surface) >= 4.5)
    }
}
```

- [ ] **Step 2: Run RED**

Run: `./scripts/ios-test.sh`

Expected: compile failure for missing semantic token members.

- [ ] **Step 3: Add the minimal semantic token surface**

Use these exact values:

```swift
static let successText: UInt = 0x37744E
static let warningText: UInt = 0x8F6800
static let errorText: UInt = 0xB4474C
static let notificationUnread: UInt = 0xFF3B30

enum Layout {
    static let pageHorizontalInset: CGFloat = 20
    static let pageTopInset: CGFloat = 24
    static let pageBottomInset: CGFloat = 48
    static let sectionSpacing: CGFloat = 24
    static let sectionContentSpacing: CGFloat = 12
    static let surfaceInset: CGFloat = 16
    static let rowHorizontalInset: CGFloat = 16
    static let rowVerticalInset: CGFloat = 12
    static let fieldSpacing: CGFloat = 12
    static let actionAreaInset: CGFloat = 12
}

enum Metrics {
    static let minimumTouchTarget: CGFloat = 44
    static let fieldHeight: CGFloat = 52
    static let actionHeight: CGFloat = 52
    static let settingsIconSlot: CGFloat = 36
}

enum Typography {
    static let pageTitle = Font.largeTitle.weight(.bold)
    static let sectionTitle = Font.title2.weight(.bold)
    static let cardTitle = Font.title3.weight(.bold)
    static let body = Font.body
    static let supporting = Font.subheadline
    static let fieldLabel = Font.subheadline.weight(.semibold)
    static let status = Font.caption.weight(.semibold)
    static let action = Font.headline.weight(.semibold)
    // Keep largeTitle/title/headline/caption as compatibility names until audit usage reaches zero.
}
```

Replace duplicate shadow structs with `smallCard = softCard` and `carouselCard = softCard`; retain the names only as compatibility aliases. Update status-chip foregrounds to use `successText`, `warningText`, and `errorText` where text sits on a surface/status tint.

- [ ] **Step 4: Verify shared contracts**

Run:

```bash
./scripts/ios-test.sh
./scripts/ios-build.sh
node scripts/ui-consistency-audit.mjs check
git diff --check
```

Expected: full tests/build pass and no new Feature debt.

- [ ] **Step 5: Close Q-114 and commit**

Commit: `feat: add semantic UI tokens`

---

### Task 3 / Q-115: Shared Semantic Components And Catalog

**Files:**
- Create: **ios/Beckon/Beckon/DesignSystem/BeckonLayoutPrimitives.swift**
- Create: **ios/Beckon/Beckon/DesignSystem/BeckonSelectionPrimitives.swift**
- Create: **ios/Beckon/Beckon/DesignSystem/BeckonComponentCatalog.swift**
- Modify: `ios/Beckon/Beckon/DesignSystem/BeckonActionPrimitives.swift`
- Modify: `ios/Beckon/Beckon/DesignSystem/BeckonFormPrimitives.swift`
- Modify: `ios/Beckon/Beckon/DesignSystem/BeckonFeedbackPrimitives.swift`
- Modify: **ios/Beckon/BeckonTests/DesignSystemContractTests.swift**

**Interfaces:**
- Produces `BeckonRoleAccent`, `beckonPageInsets(bottom:)`, `BeckonSection`, `BeckonGroupedSurface`, `BeckonSelectionCard`, `BeckonSettingsRowLabel`, and `BeckonFieldGroup`.
- Extends `BeckonPrimaryButtonStyle` with `isVisuallyEnabled` while preserving existing initializers.
- Produces `BeckonPrimaryActionAvailability` for deterministic enabled/visual-state tests.
- Existing `BeckonCard`, feedback, and form APIs remain source-compatible.

- [ ] **Step 1: Add failing source-contract tests**

Add scanner fixture tests requiring these symbols to be recognized as approved replacements. Add Swift contract tests for the visual-enabled state:

```swift
@Test func primaryActionVisualAvailabilityCombinesWithEnvironmentAvailability() {
    let available = BeckonPrimaryActionAvailability(
        isEnvironmentEnabled: true,
        isVisuallyEnabled: false
    )
    #expect(available.rendersEnabled == false)
    #expect(available.acceptsTap == true)
}
```

- [ ] **Step 2: Run RED**

Run: `./scripts/ios-test.sh`

Expected: compile failure for missing component contracts.

- [ ] **Step 3: Implement focused component APIs**

Use separate components rather than a universal surface:

```swift
enum BeckonRoleAccent {
    case customer
    case groomer
    case neutral

    var color: Color {
        switch self {
        case .customer: DesignTokens.Colors.customerPrimary
        case .groomer: DesignTokens.Colors.groomerAccent
        case .neutral: DesignTokens.Colors.border
        }
    }

    var darkColor: Color {
        switch self {
        case .customer: DesignTokens.Colors.customerPrimaryDark
        case .groomer: DesignTokens.Colors.groomerAccentDark
        case .neutral: DesignTokens.Colors.textPrimary
        }
    }
}

struct BeckonPrimaryActionAvailability: Equatable {
    let isEnvironmentEnabled: Bool
    let isVisuallyEnabled: Bool

    var rendersEnabled: Bool {
        isEnvironmentEnabled && isVisuallyEnabled
    }

    var acceptsTap: Bool {
        isEnvironmentEnabled
    }
}

struct BeckonSection<Content: View, Trailing: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    let trailing: Trailing

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionContentSpacing) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(title)
                        .font(DesignTokens.Typography.sectionTitle)
                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(DesignTokens.Typography.supporting)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                trailing
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BeckonGroupedSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(DesignTokens.Colors.surface)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: DesignTokens.CornerRadius.card,
                    style: .continuous
                )
                .stroke(DesignTokens.Colors.borderSoft, lineWidth: 1)
            }
    }
}

struct BeckonSelectionCard<Content: View>: View {
    let isSelected: Bool
    let isInvalid: Bool
    let accent: BeckonRoleAccent
    let action: () -> Void
    let content: Content

    init(
        isSelected: Bool,
        isInvalid: Bool = false,
        accent: BeckonRoleAccent,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.isInvalid = isInvalid
        self.accent = accent
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.Layout.surfaceInset)
                .background(
                    isSelected
                        ? accent.color.opacity(0.22)
                        : DesignTokens.Colors.surface
                )
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.card,
                        style: .continuous
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: DesignTokens.CornerRadius.card,
                        style: .continuous
                    )
                    .stroke(
                        isInvalid
                            ? DesignTokens.Colors.error
                            : (isSelected ? accent.darkColor : DesignTokens.Colors.border),
                        lineWidth: isSelected || isInvalid ? 2 : 1
                    )
                }
                .contentShape(Rectangle())
                .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        }
        .buttonStyle(.plain)
    }
}

struct BeckonSettingsRowLabel: View {
    let title: String
    let summary: String?
    let systemImage: String
    let accent: BeckonRoleAccent
    let trailingSystemImage: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: systemImage)
                .font(DesignTokens.Typography.cardTitle)
                .foregroundStyle(accent.darkColor)
                .frame(width: DesignTokens.Metrics.settingsIconSlot)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.action)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                if let summary {
                    Text(summary)
                        .font(DesignTokens.Typography.supporting)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: trailingSystemImage)
                .font(DesignTokens.Typography.status)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, DesignTokens.Layout.rowHorizontalInset)
        .padding(.vertical, DesignTokens.Layout.rowVerticalInset)
        .frame(minHeight: DesignTokens.Metrics.minimumTouchTarget)
        .contentShape(Rectangle())
    }
}

struct BeckonFieldGroup<Content: View>: View {
    let label: String
    let supportingText: String?
    let errorText: String?
    let content: Content

    init(
        _ label: String,
        supportingText: String? = nil,
        errorText: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.supportingText = supportingText
        self.errorText = errorText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(label)
                .font(DesignTokens.Typography.fieldLabel)
                .foregroundStyle(DesignTokens.Colors.textPrimary)
            content
            if let errorText {
                Text(errorText)
                    .font(DesignTokens.Typography.status)
                    .foregroundStyle(DesignTokens.Colors.errorText)
            } else if let supportingText {
                Text(supportingText)
                    .font(DesignTokens.Typography.supporting)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
    }
}
```

Add `BeckonSection` convenience initializers for `Trailing == EmptyView`. Callers wrap `BeckonSettingsRowLabel` in `NavigationLink` or `Link` so native destination and URL semantics remain owned by the feature.

`BeckonSectionHeader` becomes a compatibility wrapper around `BeckonSection` header presentation. Do not split the rest of the 1,429-line feedback file in this package.

Add `isVisuallyEnabled: Bool = true` to `BeckonPrimaryButtonStyle`; derive rendering from environment enabled AND visual enabled, but leave tap acceptance to the Button's actual `.disabled` state.

Preserve the existing source-compatible defaults with this initializer:

```swift
init(
    accent: Accent = .customer,
    isFullWidth: Bool = true,
    isVisuallyEnabled: Bool = true
)
```

- [ ] **Step 4: Add a DEBUG-only catalog**

Create previews for default/disabled primary and secondary actions, raised/grouped/selected/error surfaces, settings rows, field groups, status chips, loading, empty, and error states. Use static copy and no repositories or navigation route.

- [ ] **Step 5: Verify shared components**

Run:

```bash
./scripts/ios-test.sh
./scripts/ios-build.sh
node scripts/ui-consistency-audit.mjs check
git diff --check
```

Open the component catalog preview and verify default text plus Accessibility 3 without clipping.

- [ ] **Step 6: Close Q-115 and commit**

Commit: `feat: add semantic UI components`

---

### Task 4 / Q-116: Customer Home Migration

**Files:**
- Modify: `ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetsView.swift`
- Create: **ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetFormView.swift**

**Consumes:** Q-113 strict audit; Q-114 semantic tokens; Q-115 section, card, action, and page-inset APIs.

- [ ] **Step 1: Establish RED with strict audit**

Run: **node scripts/ui-consistency-audit.mjs strict ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetsView.swift**

Expected: FAIL on fixed icon fonts, direct platform typography, sub-0.85 scaling, raw hero radius, fixed text-containing card geometry, negative spacing, and offsets.

- [ ] **Step 2: Extract the pet editor without behavior changes**

Move `CustomerPetFormView` and every form-only helper from its current declaration through `CustomerPetsStatusView` into **ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetFormView.swift**. Keep model/input helpers with the code that uses them. Change access from `private` only where the root Home sheet must construct the moved type. Do not change Store calls, bindings, accessibility identifiers, image handling, or copy. Before normal `check`, run **baseline relocate --from ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetsView.swift --to ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetFormView.swift --reason Q-116**; the command must prove every moved legacy expression is unchanged.

Run: `./scripts/ios-build.sh`

Expected: BUILD SUCCEEDED before visual migration.

- [ ] **Step 3: Migrate Home hierarchy**

- Replace screen padding with `beckonPageInsets(bottom: DesignTokens.Layout.pageBottomInset * 2)`.
- Replace Pets, Active Request, and Next Booking wrapper stacks with `BeckonSection`.
- Use `pageTitle`, `supporting`, `cardTitle`, `body`, `status`, and `action` roles.
- Replace the hero's raw `32` radius with the canonical card radius; do not add a one-use hero radius token.
- Keep decorative paw placement feature-local but replace negative spacing/offset stacking with an overlay aligned to the hero bounds and add the structured UI102 exception explaining decorative geometry.
- Use `textPrimary` for all hero text/icons on mint and replace the white-on-mint hero action with the shared primary-action contrast contract.
- Make pet cards media-width constrained but text-height flexible; remove sub-0.85 scaling and expose full pet metadata through reflow or accessibility value.
- Preserve empty descriptions as inline text, not cards.

- [ ] **Step 4: Prune baseline and prove clean scope**

Run:

```bash
node scripts/ui-consistency-audit.mjs baseline prune --reason Q-116
node scripts/ui-consistency-audit.mjs strict ios/Beckon/Beckon/Features/Customer/Pets/CustomerPetsView.swift
./scripts/ios-build.sh
```

Expected: strict audit and build pass; pet-form legacy findings remain baselined only in the new pet-form file.

- [ ] **Step 5: Simulator accessibility verification**

Use the iOS debugger agent to launch Customer Home at default text and Accessibility 3. Verify greeting reflow, hero action, horizontal pet cards, Active Request, Next Booking, notification hit target, and no overlap. Reset content size after evidence capture.

- [ ] **Step 6: Close Q-116 and commit**

Commit: `feat: migrate Customer Home to semantic UI`

---

### Task 5 / Q-117: Customer Requests Migration

**Files:**
- Modify: `ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestsView.swift`
- Modify: `ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestsDashboardView.swift`
- Modify: `ios/Beckon/Beckon/Features/Bookings/BookingsView.swift` to replace `CustomerTabTitle` with `BeckonPageTitle`.
- Modify: **ios/Beckon/Beckon/DesignSystem/BeckonLayoutPrimitives.swift** to add `BeckonPageTitle`.

**Consumes:** Q-113 through Q-115.

- [ ] **Step 1: Run strict RED on Requests files**

Expected findings include the fixed 28-point rounded headline, direct footnote/platform fonts, sub-0.85 scaling, negative carousel page inset, fixed action height, and local card-shadow duplication.

- [ ] **Step 2: Make the page title semantic**

Move the shared tab-title presentation out of `BookingsView.swift` into **ios/Beckon/Beckon/DesignSystem/BeckonLayoutPrimitives.swift** as `BeckonPageTitle`. Update Bookings and Requests callers without changing their page copy or accessibility identifiers.

- [ ] **Step 3: Migrate request surfaces**

- Use semantic page insets and page/section title roles.
- Keep horizontal carousel paging behavior and add one UI102 exception to the existing content-margin compensation: `Horizontal paging intentionally cancels page inset so each card aligns to the viewport.`
- Use the canonical raised card once; remove the second `.beckonShadow(carouselCard)` from request cards.
- Replace fixed request headline and footnote styling with `cardTitle` and `supporting`.
- Remove low scale factors; allow subtitle/calendar content to wrap, and use `ViewThatFits` to stack chip/header content at accessibility sizes.
- Keep timeline marker and connector dimensions feature-local with exact UI101 geometry comments.
- Preserve cancellation, booking handoff, republish, focused scrolling, pagination, Store calls, and selectors.

- [ ] **Step 4: Verify and prune**

Run strict audit for both Requests files, prune the baseline with `--reason Q-117`, then run `./scripts/ios-test.sh` and `./scripts/ios-build.sh` because this package touches shared Bookings title code.

- [ ] **Step 5: Simulator verification**

Verify empty, active request, booking handoff, cancelled requests, and Accessibility 3 card reflow. Confirm carousel selection and cancellation still work.

- [ ] **Step 6: Close Q-117 and commit**

Commit: `feat: migrate Customer Requests to semantic UI`

---

### Task 6 / Q-118: Customer Request Wizard Migration

**Files:**
- Modify: `ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestWizardView.swift`
- Modify: `ios/Beckon/BeckonTests/CustomerRequestFeatureTests+WizardPresentation.swift`

**Consumes:** Q-113 through Q-115.

- [ ] **Step 1: Run strict RED**

Expected: local `CustomerRequestWizardPrimaryButtonStyle`, nine sub-0.85 scale factors, local shadows, direct platform fonts, fixed text-containing selection geometry, and raw action widths.

- [ ] **Step 2: Add accessibility-size presentation contracts**

Extend `CustomerRequestWizardProgressLayout` with an explicit accessibility-size mode:

```swift
struct CustomerRequestWizardProgressLayout: Equatable {
    let backButtonWidth: CGFloat
    let horizontalSpacing: CGFloat
    let usesStackedHeader: Bool
    let usesSingleColumnChoices: Bool
}
```

Add tests proving Accessibility 3 uses a stacked header and single-column service/time choices while default sizes preserve the current progression and data mapping.

- [ ] **Step 3: Replace local visual implementations**

- Delete `CustomerRequestWizardPrimaryButtonStyle`; use `BeckonPrimaryButtonStyle(isVisuallyEnabled: canContinue && !isSubmitting)` and preserve taps used to surface validation while disabling only submission-in-progress.
- Use shared icon action presentation for the header Back control.
- Use `BeckonSelectionCard` for pet, service, and location-mode choices; selected mint surfaces retain dark semantic foregrounds.
- Use `BeckonFieldGroup` and existing `.beckonFormField` for labels/errors.
- Replace time-window local shadow with shared invalid selection presentation.
- Use `ViewThatFits` or dynamic grid columns based on `dynamicTypeSize` instead of low scale factors.
- Keep photo tile/media geometry and progress-bar height feature-local with UI101 reasons.
- Preserve address editor, sheet dismissal ownership, step validation, Profile autofill, republish, publication, feedback, and all selectors.

- [ ] **Step 4: Verify behavior and clean debt**

Run:

```bash
node scripts/ui-consistency-audit.mjs strict ios/Beckon/Beckon/Features/Customer/Requests/CustomerRequestWizardView.swift
node scripts/ui-consistency-audit.mjs baseline prune --reason Q-118
./scripts/ios-test.sh
./scripts/ios-build.sh
```

Expected: strict audit, full tests, and build pass.

- [ ] **Step 5: Simulator flow verification**

At default text and Accessibility 3, traverse all five steps with a seeded pet and confirmed address. Verify Back/Continue/Publish, validation errors, date/time choices, location mode, photo tiles, Review rows, keyboard/focus, and no clipped controls.

- [ ] **Step 6: Close Q-118 and commit**

Commit: `feat: migrate Request Wizard to semantic UI`

---

### Task 7 / Q-119: Customer Account Migration

**Files:**
- Create: **ios/Beckon/Beckon/Features/Customer/Profile/CustomerAccountView.swift**
- Modify: `ios/Beckon/Beckon/Features/Customer/Profile/CustomerProfileSettingsView.swift`
- Modify: `ios/Beckon/Beckon/Features/Auth/AuthenticatedAccountView.swift`

**Consumes:** Q-113 through Q-115 and Q-117's `BeckonPageTitle`.

- [ ] **Step 1: Run strict RED on the current Account/Profile file**

Expected: fixed 22-point icons, raw two-point text spacing, raw divider inset, duplicated settings row/link presentation, and non-semantic Account section headings.

- [ ] **Step 2: Extract Account ownership**

Move `CustomerAccountView`, profile identity header, Account groups, Account navigation links, and support surface to **ios/Beckon/Beckon/Features/Customer/Profile/CustomerAccountView.swift**. Leave profile editor, avatar editing/encoding, address editor, profile fields, and profile status in `CustomerProfileSettingsView.swift`. Preserve existing access levels needed by `AuthenticatedEntryView` and the Account-to-Profile navigation link.

- [ ] **Step 3: Replace duplicated Account rows**

- Use `BeckonPageTitle`, `BeckonSection`, and `BeckonGroupedSurface`.
- Wrap `BeckonSettingsRowLabel` in native `NavigationLink` and `Link` callers.
- Use semantic settings icon slot, row insets, title/supporting styles, and divider inset derived from row inset + icon slot + row gap.
- Replace `AccountReleaseLinksSection` in `AuthenticatedAccountView.swift` with the same shared row label, without changing URLs or identifiers.
- Keep `AccountDangerActions` behavior intact; migrate its text/icon metrics only when required by strict audit.
- Preserve profile loading, avatar cache, settings save, Debug Console gating, sign-out/delete confirmations, Privacy Policy, and Support.

- [ ] **Step 4: Verify and prune**

Run strict audit on **ios/Beckon/Beckon/Features/Customer/Profile/CustomerAccountView.swift**, prune the baseline with `--reason Q-119`, run full iOS tests because shared authenticated Account code changes, then run the iOS build.

- [ ] **Step 5: Simulator verification**

Verify default text and Accessibility 3 for identity header, Profile Settings row, Privacy/Support links, DEBUG row when available, destructive actions, profile editor navigation, VoiceOver row labels, and full-row taps.

- [ ] **Step 6: Close Q-119 and commit**

Commit: `feat: migrate Customer Account to semantic UI`

---

### Task 8 / Q-120: First-Slice Integration Gate

**Files:**
- Modify: **scripts/ui-consistency-baseline.json**
- Modify: **docs/04_ios/UI_CODE_GOVERNANCE.md**
- Modify: `docs/01_product/DESIGN_SYSTEM.md`
- Modify: `docs/01_product/SCREEN_INVENTORY.md`
- Modify: `docs/06_tasks/ROADMAP.md`
- Modify: `docs/06_tasks/ROADMAP_EXECUTION_QUEUE.md`
- Modify: `docs/00_memory/FEATURE_INDEX.md`
- Create: **docs/04_ios/UI_CONSISTENCY_DEBT.md**

**Consumes:** Q-113 through Q-119.

- [ ] **Step 1: Run the complete audit matrix**

Run normal audit, then strict audit for Customer Home, Requests, Wizard, and Account files. Export JSON and summarize counts by rule and Feature area. Fail if any migrated file retains an unapproved error or if the baseline has stale entries.

- [ ] **Step 2: Run complete regression validation**

```bash
node --test tests/scripts/ui-consistency-audit.test.mjs tests/scripts/preflight.test.mjs
./scripts/ios-test.sh
./scripts/ios-build.sh
./scripts/preflight.sh
node scripts/context-hygiene-check.mjs
git diff --check
```

Expected: all checks pass.

- [ ] **Step 3: Perform final accessibility/rendering matrix**

At default text and Accessibility 3, verify the four Customer surfaces on one compact and one large Simulator viewport. Check safe areas, long text, keyboard/focus, VoiceOver order/headings/actions, Reduce Motion for touched animations, empty/error/loading/disabled/selected states, and no overlaps. Store evidence under `artifacts/evidence/Q-120/` and reference paths only.

- [ ] **Step 4: Publish remaining debt without creating a second rule source**

**docs/04_ios/UI_CONSISTENCY_DEBT.md** contains generated counts, highest-risk files, valid exception inventory, and recommended next migration order. It links to **docs/04_ios/UI_CODE_GOVERNANCE.md** for rules and never repeats rule definitions. Mark Customer Home, Requests, Wizard, and Account as migrated; explicitly retain Groomer Q-104 deferral.

- [ ] **Step 5: Close R-041 first slice and commit**

Update Roadmap, queue, Feature Index, Screen Inventory, Design System status, task memory, and context hygiene. Commit: `test: complete UI consistency first-slice gate`.

## Self-Review Checklist

- [x] Every design-spec section maps to Q-113 through Q-120.
- [x] No package adds a dependency or changes backend/product behavior.
- [x] Scanner distinguishes certain errors, warnings, and review findings and has exact exceptions.
- [x] Existing debt is baselined, new debt fails, and stale debt must be pruned.
- [x] Customer and Groomer layout differences remain intact.
- [x] Home and Account file splits prevent unrelated Pet/Profile editor migration.
- [x] Wizard preserves validation taps despite visually unavailable Continue state.
- [x] Every migrated surface has strict audit, build, and Accessibility 3 evidence.
- [x] Q-120 runs full tests/build/preflight and publishes remaining debt.
