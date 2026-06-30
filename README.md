# Coverage Lens

Coverage Lens generates compact static HTML coverage reports from Dart and
Flutter LCOV output. It is designed for quick local review and CI artifacts:
open the report, expand the directories that need attention, and inspect source
lines without leaving the browser.

Coverage Lens reads the LCOV file as the source of truth. It does not run tests,
instrument code, or infer which test covered a line.

## Features

- Static report folder with a lightweight `index.html`.
- Directory tree with aggregate line and branch coverage.
- Lazy-loaded file previews with LCOV hit counts and branch markers.
- Lists for files below threshold and files with missing branch coverage.
- Include and exclude globs for generated files.
- Local live server for previewing reports without writing HTML assets.
- CI-friendly threshold exit codes.

## Install

```bash
dart pub global activate coverage_lens
```

You can also add it to a project:

```bash
dart pub add --dev coverage_lens
```

## Generate Coverage

For Flutter projects:

```bash
flutter test --coverage
```

If your Flutter/Dart toolchain supports branch coverage and emits `BRDA`
records, include branch coverage when generating the LCOV file:

```bash
flutter test --coverage --branch-coverage
```

For Dart packages, generate an LCOV file with your preferred coverage workflow,
for example `package:coverage`.

## Generate The Report

After an LCOV file exists, run:

```bash
dart run coverage_lens:coverage_lens report \
  --lcov coverage/lcov.info \
  --source . \
  --out build/coverage_lens
```

You can pass `--lcov` more than once. This is useful when a Flutter app cannot
run tests as one workspace and each package writes its own LCOV file:

```bash
dart run coverage_lens:coverage_lens report \
  --lcov coverage/lcov.info \
  --lcov modules/**/coverage/lcov.info \
  --lcov packages/**/coverage/lcov.info \
  --source . \
  --out build/coverage_lens
```

Coverage Lens merges matching `SF:` records before building the report. When an
LCOV file is inside a package coverage folder, for example
`modules/core/coverage/lcov.info`, package-relative sources such as
`SF:lib/src/file.dart` are shown as `modules/core/lib/src/file.dart`.
Glob entries that do not match any files are ignored as long as at least one
LCOV file is found.

Open `build/coverage_lens/index.html` in a browser.

The report output is a folder. Keep `index.html`, `files/`, and `assets/`
together when sharing or archiving the report. Source previews are stored in
`files/` so the main `index.html` stays small even for large projects.

If installed globally, use:

```bash
coverage_lens report
```

## Live Local Preview

For local review, run a live server instead of writing `index.html`, `files/`,
and `assets/` to disk:

```bash
dart run coverage_lens:coverage_lens serve \
  --lcov coverage/lcov.info \
  --lcov modules/**/coverage/lcov.info \
  --source .
```

By default the report is available at `http://127.0.0.1:8787/`. Use `--host`
and `--port` to change the bind address:

```bash
dart run coverage_lens:coverage_lens serve --port 9000
```

The live server still uses the LCOV file as the source of truth, but serves the
main report, source previews, and CSS from memory. This keeps local inspection
fast without creating a `files/` preview folder.

## Configuration

Coverage Lens reads `coverage_lens.yaml` from the current directory by default.
Command-line options override values from the config file.

```yaml
sourceRoot: .
lcovPaths:
  - coverage/lcov.info
  - modules/**/coverage/lcov.info
  - packages/**/coverage/lcov.info
outputDir: build/coverage_lens
thresholds:
  line: 80
  branch: 70
include:
  - lib/**
  - modules/*/lib/**
exclude:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "**/*.config.dart"
  - "**/generated/**"
```

## Thresholds

```bash
dart run coverage_lens:coverage_lens report \
  --fail-under-lines 80 \
  --fail-under-branches 70
```

Exit code `2` means the report was generated but the configured line coverage
or branch coverage threshold failed.

## LCOV Semantics

Coverage Lens displays line and branch positions exactly as they are reported in
LCOV:

- `DA:<line>,<count>` marks an instrumented line and its execution count.
- `BRDA:<line>,<block>,<branch>,<taken>` marks a branch record on that line.

Dart and Flutter coverage can attach counters to lines such as annotations or
method declarations. Coverage Lens keeps those line numbers intact so the report
matches the LCOV file it was generated from.

## Ignoring Generated Files

Use `exclude` patterns to keep generated code out of the report:

```yaml
exclude:
  - "**/*.g.dart"
  - "**/*.freezed.dart"
  - "**/generated/**"
```

Excluded files are not counted in coverage totals.
