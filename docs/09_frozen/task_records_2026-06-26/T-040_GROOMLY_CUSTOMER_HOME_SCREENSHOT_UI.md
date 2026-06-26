Task ID: `T-040`

Mode: `Standard`

Date: `2026-06-22`

## User Request

Rework the customer Home page from the provided prototype screenshots. The two screenshots represent the same screen: the second shows horizontal pet scrolling and lower page modules after vertical scrolling.

Screenshot/source reference:

- `/Users/liafenyua/Desktop/未命名文件夹/截屏2026-06-22 上午12.26.57.png`
- `/Users/liafenyua/Desktop/未命名文件夹/截屏2026-06-22 上午2.05.17.png`

## Primary Task

Rework only the customer Home screen represented by the screenshots.

Target screen and role:

- Screen: Customer Home
- Role: Customer

## Required Context

Read only:

1. `AGENTS.md`
2. `docs/05_workflow/SINGLE_AGENT_WORKFLOW.md`
3. this task file
4. targeted `docs/00_memory/CURRENT_STATE.md`
5. `docs/06_tasks/TASK_LEDGER.md`
6. `docs/01_product/SCREEN_INVENTORY.md`
7. `docs/01_product/DESIGN_SYSTEM.md`
8. `Features/Customer/CustomerTabView.swift`
9. `Features/Customer/Pets/CustomerPetsView.swift`
10. `Features/Customer/Pets/CustomerPetsStore.swift`
11. `Features/Customer/Requests/CustomerRequestsView.swift`
12. `Features/Customer/Requests/CustomerRequestsStore.swift`
13. `Features/Bookings/BookingsView.swift`
14. `Features/Bookings/BookingsStore.swift`
15. relevant model/repository protocols for pets, requests, and bookings

## Screenshot Analysis

Map every visible module before editing SwiftUI.

Ignore rule:

- Ignore any long oval Customer/Groomer toggle located above the visible app screen frame. Treat it as an external prototype/control annotation, not as an app module to map, classify, or implement.
- Ignore the prototype pet card timestamp such as `3 weeks ago`, per user instruction.

| Screenshot Module | Classification | Existing Support | UI Surface | Store/Repository/Model Path | Decision |
|---|---|---|---|---|---|
| Welcome back header with avatar, greeting, and bell button | visual-only / existing-feature rewire | partial | `CustomerTabView`, `CustomerPetsView` | `MarketplaceProfile.displayName`; no avatar URL or notifications backend | implement display name and static notification button; use branded placeholder avatar |
| Start grooming request promo card | existing-feature rewire | yes | `CustomerPetsView` plus existing request wizard | `CustomerRequestsStore`, `CustomerRequestRepository`, `CustomerPetRepository`, `BookingRepository` | implement by presenting the existing request wizard sheet |
| Your pets horizontal cards | existing-feature rewire | yes | `CustomerPetsView` | `CustomerPetsStore`, `CustomerPetRepository`, `CustomerPet` | implement horizontal carousel; show avatar placeholder, pet name, and breed/species; omit timestamp |
| Add pet dashed card | existing-feature rewire | yes | `CustomerPetsView` | `CustomerPetsStore.startCreate()` and existing pet form | implement |
| Active request card | existing-feature rewire | yes | `CustomerPetsView` plus existing request detail | `CustomerRequestsStore`, `CustomerGroomingRequest` | implement active request summary and link to existing detail |
| Next booking card | existing-feature rewire | partial | `CustomerPetsView` plus existing booking detail | `BookingsStore`, `Booking` | implement with existing booking time and groomer reference; do not invent groomer display names |
| Bottom customer tab bar | visual-only | yes | `CustomerTabView` | `CustomerTab` | preserve existing tab behavior and current Groomly tab styling |

## Scope

In scope:

- Recompose Customer Home as a dashboard matching the prototype hierarchy.
- Reuse existing pet, request, and booking stores/repositories.
- Keep start request, create pet, request detail, and booking detail wired to current MVP behavior.
- Keep the notification button visual/static because notification backend behavior is not implemented.
- Pass the authenticated profile display name into Customer Home.

Out of scope:

- Notification backend, unread counts, push notification routing, or notification persistence.
- Avatar upload/display contract.
- Groomer/customer participant name joins in booking summaries beyond existing booking model support.
- New backend/schema/RLS/RPC/Storage changes.
- Redesigning Requests, Bookings, Messages, Account, or Groomer screens.

## New Feature Stop Report

No stop required. Prototype notification behavior, real avatar images, and groomer display names are unsupported by current backend/model contracts, so this task implements visual placeholders or existing references only.

## Implementation Plan

1. Pass `MarketplaceProfile.displayName` from authenticated entry into `CustomerTabView` and then Customer Home.
2. Update Customer Home to own existing pet, request, and booking stores.
3. Rebuild the Home layout into a custom ScrollView with welcome, request CTA, horizontal pets, active request, and next booking sections.
4. Reuse existing pet form, request wizard/detail, and booking detail by relaxing file-private view visibility where needed.
5. Preserve loading, empty, error, disabled, and tab behavior.

## Validation

Default validation:

```sh
./scripts/ios-build.sh
git diff --check
```

Completion launch for implemented UI changes:

- After validation, launch the app in the iOS Simulator for user inspection.
- Record simulator/device and visible root screen in this task file.

## Acceptance

- Customer Home uses the prototype-inspired module order.
- External Customer/Groomer prototype toggle and pet timestamp are not implemented.
- Start grooming request opens the existing request wizard.
- Add pet opens the existing pet form.
- Active request opens existing request detail.
- Next booking opens existing booking detail.
- No backend, repository contract, schema, RLS, RPC, Storage, or role-routing change is introduced.

## Closeout

Status: `completed`

Changed files:

- `docs/06_tasks/T-040_GROOMLY_CUSTOMER_HOME_SCREENSHOT_UI.md`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Auth/AuthenticatedEntryView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/CustomerTabView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Pets/CustomerPetsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Customer/Requests/CustomerRequestsView.swift`
- `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Bookings/BookingsView.swift`

Validation:

- `./scripts/ios-build.sh` passed.
- `git diff --check` passed.

Simulator launch:

- XcodeBuildMCP `session_show_defaults` confirmed `PetGroomerMarketplace` on `iPhone 17` simulator (`B9639233-9E78-41C9-A372-330D36C38DA7`).
- XcodeBuildMCP `build_run_sim` passed and launched bundle `com.prinnyyy.PetGroomerMarketplace`.
- Runtime UI snapshot reached `customer.home` with `Welcome back`, `Start Grooming Request`, `Your pets`, `Active request`, and bottom customer tabs visible.
- Tapped `customer.home.start-request`; existing `CustomerRequestWizardView` opened with `Request details`, then cancelled back to Home.
- Tapped `customer.pets.add`; existing `CustomerPetFormView` opened, then cancelled back to Home.
- Tapped `customer.home.active-request.view`; existing `CustomerRequestDetailView` opened, then returned to Home.
- Tapped `customer.home.next-booking.view`; existing `BookingDetailView` opened, then returned to Home.
- Final screenshot: `/var/folders/bc/xmbw6w1d06s61ns9_j2fnll00000gn/T/screenshot_optimized_b75979de-dae9-42a5-a68f-a5e9dfc271ff.jpg`.

Risks:

- Notification button is visual/static only; no notification backend or unread count exists.
- Home avatar is a branded placeholder because `MarketplaceProfile` has `displayName` but no avatar URL field.
- Next booking uses the existing groomer reference and appointment time because `Booking` does not include groomer display names.
- Existing pet photo upload remains in older helper code but is not surfaced in the new compact Home card design; no Storage or signed URL behavior changed.

Next:

- App is running on the Customer Home screen in Simulator for inspection. Wait for explicit user direction before changing adjacent customer tabs, backend contracts, or notification/avatar/participant-name features.
