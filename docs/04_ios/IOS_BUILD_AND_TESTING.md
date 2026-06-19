# iOS Build and Testing

## Build Script

Use:

```bash
./scripts/ios-build.sh
```

## Test Script

Use:

```bash
./scripts/ios-test.sh
```

## Scheme

TODO: Fill after inspecting the Xcode project.

## Simulator

TODO: Fill after inspecting available simulators.

## Rules

- Do not invent xcodebuild commands when scripts exist.
- If scripts need project-specific values, update the script once.
- If build fails, fix only failures related to the current task.
- Stop after two focused repair attempts and report.
