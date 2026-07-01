## 1.4.0

- Add `--no-source-preview` and `sourcePreview: false` for lighter HTML
  reports that keep summaries and the coverage tree without generating source
  preview assets.
- Add changed-file report scope through `--changed-from`, `--changed-to`,
  `changedFrom`, and `changedTo` for PR-focused coverage reports.

## 1.3.0

- Replace iframe and fetch based source previews with local script-loaded
  preview assets so large static reports opened from `file://` can load deeply
  nested file previews reliably.
- Keep only the currently opened source preview mounted in the DOM and remove
  temporary preview scripts after loading to reduce memory usage in large
  reports.
- Serve preview JavaScript assets with the correct content type in
  `coverage_lens serve`.

## 1.2.2

- Fix source preview loading for large reports by generating unique, bounded
  preview asset names with stable path hashes.
- Keep preview loading state active until the iframe contains a valid Coverage
  Lens source preview document.

## 1.2.1

- Add documentation comments for the public API exported by `coverage_lens`.
- Add a runnable Dart example that shows programmatic LCOV parsing and
  analysis.

## 1.2.0

- Add optional one-page summary PDF generation for aggregate coverage
  statistics through `report --summary-pdf`.
- Add `summaryIcon` / `--summary-icon` for custom project icons in summary
  PDFs.
- Add `projectName` / `--project-name` so summary PDFs can show the
  application name next to the Coverage Lens label.
- Include Git branch, commit, and dirty working tree state in summary PDFs.
- Improve summary PDF scope text and header layout.

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
