# T-034 - Groomly Chat UI

- State: planned.
- Mode: Standard.
- Depends on: completed T-033.

## Goal

Apply Groomly styling to participant conversation list, chat thread, message rows, composer, and chat loading/empty/error states while preserving the current text-only chat behavior.

## Required Context

Read only:

1. `AGENTS.md`
2. this task file
3. `docs/06_tasks/T-026_TO_T-035_GROOMLY_UI_COMPLETION_SEQUENCE.md`
4. `docs/08_design/UI_IMPLEMENTATION_NOTES.md`
5. `docs/08_design/design_tokens.json`
6. `docs/01_product/DESIGN_SYSTEM.md`
7. `docs/04_ios/SWIFTUI_STATE_RULES.md`
8. `ios/PetGroomerMarketplace/PetGroomerMarketplace/Features/Chat/ChatView.swift`
9. Groomly primitive files under `ios/PetGroomerMarketplace/PetGroomerMarketplace/DesignSystem/`

## Scope

In scope:

- Restyle `ChatConversationsView`, `ChatConversationRow`, `ChatThreadView`, `ChatMessageRow`, `ChatComposerView`, and `ChatStatusView`.
- Use Groomly background, cards, section headers, loading/empty/error primitives, message bubbles, composer form styling, and primary send action styling.
- Preserve conversation loading, selection, booking context, message loading, text input, send action, disabled state, retry/error behavior, and participant-only access assumptions.

Out of scope:

- Realtime subscriptions, attachments, images, typing indicators, push notifications, read receipts, message editing/deletion, backend changes, repository changes, Store changes, booking changes, account/debug changes, scripts, assets, or routing changes.

## Implementation Rules

- Keep chat text-only.
- Keep message ownership and send behavior in `ChatStore`.
- Do not change repository calls or introduce local-only message persistence.
- Use existing roles/context only; do not invent participant metadata.

## Validation

Run:

```sh
./scripts/ios-build.sh
git diff --check
```

## Acceptance

- Conversation list, chat thread, message rows, composer, and chat status states use Groomly styling.
- Existing load, selection, text input, send, disabled, retry, and error behavior is preserved.
- No Store, repository, model, backend, Supabase, script, asset, booking, request, account, debug, or tab-routing file is changed.
- Next planned task remains T-035.

## Stop Conditions

Stop and report if the restyle requires realtime chat, attachments, message schema changes, repository changes, or backend/RLS changes.
