# Publishing

## Preflight

Run these commands before publishing:

```bash
dart pub get
dart analyze
dart test
dart pub publish --dry-run
```

## Publish

After the dry-run is clean and the release changes are committed:

```bash
dart pub publish
```

## Branch Coverage

Coverage Lens reads branch records from LCOV. For Flutter projects, generate
branch coverage before building the report:

```bash
flutter test --coverage --branch-coverage
```
