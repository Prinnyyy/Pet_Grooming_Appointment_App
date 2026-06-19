# Migration Rules

## Principles

- Migrations are append-only by default.
- Do not rewrite applied migrations unless explicitly authorized.
- Keep schema changes small and named clearly.
- Update `SUPABASE_CONTRACT.md` after schema changes.
- Add RLS/policy documentation for permission-sensitive changes.

## Migration Checklist

Before creating a migration:

- [ ] Read existing migrations.
- [ ] Confirm the target schema change.
- [ ] Confirm whether RLS is affected.
- [ ] Confirm whether RPC is needed.
- [ ] Confirm whether app code depends on the change.

After creating a migration:

- [ ] Update backend docs.
- [ ] Run `./scripts/supabase-check.sh`.
- [ ] Update memory docs.
