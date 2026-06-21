# Swift Style Guide

## General

- Prefer clear names over clever names.
- Use explicit types where they improve readability.
- Keep files focused.
- Avoid large view files when extracting components would clarify intent.
- Avoid new dependencies unless approved.

## Async

- Use structured concurrency when appropriate.
- Avoid untracked background work.
- Handle cancellation when relevant.
- Keep UI updates on the main actor.

## Models

- Prefer typed models over loosely shaped dictionaries.
- Keep DTO/backend models separate from domain models when the difference matters.

## Error Handling

- Avoid `try?` unless failure is intentionally ignored and documented.
- Avoid silent catch blocks.
- Return user-safe errors to UI layers.
