# Supabase Contract

This is the source of truth for backend expectations.

Do not invent schema facts. Inspect migrations or Supabase metadata before updating.

## Tables

| Table | Purpose | Key Columns | RLS Summary | Notes |
|---|---|---|---|---|
| TODO | TODO | TODO | TODO | TODO |

## RPC Functions

| Function | Purpose | Inputs | Returns | Security Notes |
|---|---|---|---|---|
| TODO | TODO | TODO | TODO | TODO |

## Storage Buckets

| Bucket | Purpose | Access Rules | Notes |
|---|---|---|---|
| TODO | TODO | TODO | TODO |

## Client Rules

- Client code must not use service-role keys.
- Client code must not bypass RLS.
- Business-critical multi-step mutations should use RPC.
- Update this file when migrations, RPC, policies, or storage rules change.
