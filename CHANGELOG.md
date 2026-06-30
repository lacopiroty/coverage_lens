## 1.1.0

- Add `coverage_lens serve` for local live reports that serve `index.html`,
  source previews, and CSS from memory without writing report assets to disk.

## 1.0.2

- Support multiple LCOV inputs through repeated `--lcov` options.
- Support `lcovPaths` config entries with glob patterns.
- Merge duplicate LCOV `SF:` records and rebase package-relative source paths from nested package coverage files.
- Improve nested source preview loading by validating the loaded iframe document before marking it ready.
- Keep only one source preview open at a time and unload closed previews to reduce browser memory use.
- Resize source preview frames to compact content height for short files while preserving a maximum height for long files.
- Wrap summary tiles on smaller screens instead of showing a horizontal scrollbar.

## 1.0.1

- Improve source preview loading reliability in generated reports.
- Release source preview iframe contents when a file preview is collapsed to reduce browser memory use.
- Keep generated report assets split across `index.html`, `files/`, and `assets/` for smaller main HTML output.

## 1.0.0

- Initial release.
- Generate compact static HTML reports from LCOV files.
- Show aggregate line and branch coverage, directory summaries, and file-level source previews.
- Support include and exclude globs for generated files and other ignored paths.
- Support line and branch coverage thresholds for CI-friendly exit codes.
