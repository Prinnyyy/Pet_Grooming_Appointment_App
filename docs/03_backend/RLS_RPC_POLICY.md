# RLS and RPC Policy

## RLS Principles

- RLS is the permission boundary.
- UI visibility is not security.
- Policies must match user roles.
- Test permission assumptions when possible.

## RPC Principles

Use RPC for:
- multi-step mutations
- status transitions
- operations requiring conflict protection
- operations that must be atomic
- operations where client-side sequencing could create inconsistent data

## Rules for Codex

- Do not create direct client mutations for business-critical transitions without checking this file.
- Do not change policies without documenting the reason.
- Do not mark an operation complete until production behavior is implemented or explicitly documented as pending.
