# TestOps Templates

## Test Preparation

```markdown
## Preparation

- Run ID:
- Scenario:
- Customer seed:
- Groomer seed:
- App branch:
- Build/test command:
- Remote write authorization:
- Cleanup mode:
```

## Test Result

```markdown
## Result

- Status: passed / failed / blocked
- Started:
- Finished:
- Request ref:
- Offer ref:
- Booking ref:
- Review ref:
- Cleanup result:

### Phase Results

| Phase | Status | Duration ms | Notes |
|---|---:|---:|---|

### Debug Evidence

- Debug JSONL command:
- Relevant `category=test` refs:
- Relevant Store/repository refs:

### Failure Analysis

- First failing phase:
- User-facing symptom:
- Underlying API/repository error:
- Repro command:
- Next action:
```

## Failure Replay Note

````markdown
Reproduce with:

```bash
node scripts/testops.mjs run backend --scenario marketplace_full_lifecycle --run-id <RUN> --execute
./scripts/ios-debug-events.sh tail 300
```
````
