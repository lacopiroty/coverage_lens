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
