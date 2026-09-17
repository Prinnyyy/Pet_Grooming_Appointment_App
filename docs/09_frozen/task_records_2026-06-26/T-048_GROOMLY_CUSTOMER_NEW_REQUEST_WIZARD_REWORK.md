# T-048 Groomly Customer New Request Wizard Rework

Mode: Standard

Date: 2026-06-22

## User Request

Rework the Customer new request flow from five prototype screenshots as a progressive creation wizard:

- Pet selection.
- Fixed service options instead of a free service text box.
- Date and time window selection with preset windows, detailed start/end time picker, and all-day flexible toggle.
- Location UI with mobile/visit options, address input, and visit range slider.
- Details UI with notes and photo placeholder UI.
- Review screen filled from currently supported request fields.

Screenshot/source references:

- `docs/08_design/screenshots/screenshot-2026-06-22-pm-09-54-20.png`
- `docs/08_design/screenshots/screenshot-2026-06-22-pm-09-55-02.png`
- `docs/08_design/screenshots/screenshot-2026-06-22-pm-09-55-15.png`
- `docs/08_design/screenshots/screenshot-2026-06-22-pm-10-06-23.png`
- `docs/08_design/screenshots/screenshot-2026-06-22-pm-10-06-34.png`

## Primary Task

Rework only the existing Customer new grooming request wizard.

Target screen and role:

- Screen: `CustomerRequestWizardView`
- Role: Customer

## Screenshot Analysis

Ignore rule:

- Ignore any long oval Customer/Groomer toggle located above the visible app screen frame. Treat it as an external prototype/control annotation, not as an app module to map or implement.

| Screenshot Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| Wizard shell with back button, title, progress bar, and Pet/Service/Time/Details/Review labels | visual-only | yes | `CustomerRequestWizardView` | local view state only | implement |
| Pet cards and selected checkmark | existing-feature rewire | yes | `CustomerRequestWizardView` | `CustomerRequestsStore.pets`, `selectedPetID` | implement |
| Add a new pet tile | existing-feature rewire | yes, through Home pet store | `CustomerRequestWizardView` + `CustomerPetsView` sheet wiring | existing `CustomerPetsStore.startCreate()` via optional closure | implement |
| Fixed service option cards | existing-feature rewire | partial | `CustomerRequestWizardView` | writes existing `CustomerRequestsStore.serviceType`; duration copy ignored | implement |
| Date chips | existing-feature rewire | yes | `CustomerRequestWizardView` | writes existing `preferredStart`/`preferredEnd` date components | implement |
| Preset time windows | existing-feature rewire | yes | `CustomerRequestWizardView` | writes existing `preferredStart`/`preferredEnd` | implement |
| Detailed time option | existing-feature rewire | yes | `CustomerRequestWizardView` | shows local start/end `DatePicker`s that write existing preferred range | implement |
| I'm flexible with time toggle | existing-feature rewire | yes | `CustomerRequestWizardView` | writes `00:00` to `23:59` for selected day | implement |
| Location mode, address input, and visit range slider | visual-only / future feature | no persisted mode/range/address fields | `CustomerRequestWizardView` | only `city`, `state`, `zipCode` persist; mode/range/address local UI only | implement UI only and document risk |
| Details notes | existing-feature rewire | yes | `CustomerRequestWizardView` | writes `serviceNotes` | implement |
| Photo add placeholder | visual-only / future feature | no request draft photo attach path | `CustomerRequestWizardView` | none for create request | implement UI only and document risk |
| Review summary card | existing-feature rewire | yes | `CustomerRequestWizardView` | read `selectedPet`, `serviceType`, preferred range, `city/state/zip`, `serviceNotes` | implement |

## Implementation Plan

1. Add narrow tests for wizard step ordering, service option mapping, preset/flexible time ranges, range clamping, and review text composition.
2. Replace the current single-scroll request form with a five-step wizard using existing Store fields.
3. Keep unsupported location mode/range/address and photo state local to the wizard and do not change repositories, models, backend, or Supabase.
4. Wire the add-pet tile from the Home sheet entry into the existing `CustomerPetsStore.startCreate()` path.
5. Run validation and launch the iOS app in Simulator for inspection.

## Validation Plan

- Targeted red/green tests for wizard presentation helpers.
- `./scripts/ios-build.sh`
- `git diff --check`
- XcodeBuildMCP simulator launch.

## Closeout

Status: completed

Changed files:

- `docs/06_tasks/T-048_GROOMLY_CUSTOMER_NEW_REQUEST_WIZARD_REWORK.md`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplaceTests/CustomerRequestFeatureTests.swift`
- `docs/00_memory/CURRENT_STATE.md`
- `docs/00_memory/FEATURE_INDEX.md`
- `docs/00_memory/WORKLOG.md`
- `docs/06_tasks/TASK_LEDGER.md`

Validation:

- TDD red check failed before implementation because `CustomerRequestWizardStep`, `CustomerRequestServiceOption`, `CustomerRequestTimeWindowOption`, `CustomerRequestTravelRange`, and `CustomerRequestWizardReviewPresentation` did not exist.
- Targeted TDD green check passed for:
  - `requestWizardStepsMatchPrototypeProgression`
  - `requestWizardServiceOptionsMapToExistingServiceTypeField`
  - `requestWizardTimeWindowsApplyPresetRangesToSelectedDate`
  - `requestWizardFlexibleTimeUsesAllDayWindow`
  - `requestWizardTravelRangeClampsToSupportedMiles`
  - `requestWizardReviewSummaryUsesCurrentRequestFields`
- `./scripts/ios-build.sh` passed.
- `git diff --check` passed.

Simulator launch:

- XcodeBuildMCP `build_run_sim` passed on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`) with no diagnostics warnings or errors.
- App launched successfully for inspection.
- Screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_558715fe-96de-4a6c-8cba-597f9215838c.jpg`

Risks:

- Location mode, street address, visit range, and request photos are UI-only in this task because the current request draft/backend contract does not persist them.
- The review card intentionally shows only currently supported request fields. Street address, mobile/visit mode, visit range, and photo placeholders are not included in the published request payload.
- If these fields should affect matching or request detail later, the minimum follow-up is a model/backend task to add request location-mode/address/range/photo persistence and corresponding repository mappings.

Next:

- App is running in Simulator for inspection. Wait for explicit user direction before adding persistent location/photo support or changing backend request contracts.
