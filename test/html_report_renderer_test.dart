import 'package:coverage_lens/src/html/html_report_renderer.dart';
import 'package:coverage_lens/src/model/coverage_models.dart';
import 'package:test/test.dart';

void main() {
  test('renders clickable groups, collapsible files, and compact source', () {
    final file = const CoverageFile(
      path: 'lib/a.dart',
      summary: CoverageSummary(
        executableLines: 2,
        coveredLines: 1,
        uncoveredLines: 1,
        missingSourceFiles: 0,
        filesBelowThreshold: 0,
        branchFound: 0,
        branchHit: 0,
      ),
      lines: [
        CoverageLine(
          number: 1,
          hitCount: 1,
          status: CoverageLineStatus.covered,
          text: 'final safe = true;',
        ),
        CoverageLine(
          number: 2,
          hitCount: 0,
          status: CoverageLineStatus.uncovered,
          text: 'if (a < b) return a;',
        ),
      ],
      uncoveredRanges: [CoverageRange(start: 2, end: 2)],
      hasMissingSource: false,
      score: 28,
      isBelowThreshold: true,
    );

    final report = CoverageReport(
      generatedAt: DateTime.utc(2026, 6, 26, 12),
      summary: const CoverageSummary(
        executableLines: 2,
        coveredLines: 1,
        uncoveredLines: 1,
        missingSourceFiles: 0,
        filesBelowThreshold: 1,
        branchFound: 0,
        branchHit: 0,
      ),
      groups: [
        const CoverageGroup(
          name: 'lib',
          path: 'lib',
          summary: CoverageSummary(
            executableLines: 2,
            coveredLines: 1,
            uncoveredLines: 1,
            missingSourceFiles: 0,
            filesBelowThreshold: 1,
            branchFound: 0,
            branchHit: 0,
          ),
        ),
      ],
      hotspots: [file],
      warnings: const [],
      files: [file],
    );

    final output = HtmlReportRenderer().renderReport(report);
    final html = output.indexHtml;
    final preview = output.assets['files/lib-a-dart.html']!;
    final previewCss = output.assets['assets/source_preview.css']!;

    expect(html, contains('Coverage Lens'));
    expect(html, contains('Generated: Jun 26, 2026, 12:00 UTC'));
    expect(html, isNot(contains('2026-06-26T12:00:00.000Z')));
    expect(html, contains('50.0%'));
    expect(html, contains('Needs attention'));
    expect(html, contains('class="attention-list"'));
    expect(html, isNot(contains('id="file-filter"')));
    expect(html, isNot(contains('aria-label="Filter files"')));
    expect(html, isNot(contains('function filterTree')));
    expect(
      html,
      contains(
        '<a class="attention-file" href="#file-lib-a-dart" data-open-target="file-lib-a-dart" data-path="lib/a.dart">',
      ),
    );
    expect(html, isNot(contains('<table id="hotspots">')));
    expect(html, isNot(contains('<th>Ranges</th>')));
    expect(html, contains('Coverage tree'));
    expect(html, contains('class="coverage-tree"'));
    expect(html, contains('class="tree-folder" id="tree-folder-lib"'));
    expect(html, contains('class="tree-row tree-file"'));
    expect(
      html,
      contains(
        '<details class="tree-file-detail" id="file-lib-a-dart" data-tree-path="lib/a.dart" data-path="lib/a.dart">',
      ),
    );
    expect(html, contains('lib/a.dart'));
    expect(html, contains('data-open-target="file-lib-a-dart"'));
    expect(html, contains('data-preview-src="files/lib-a-dart.html"'));
    expect(html, contains('class="source-preview-frame"'));
    expect(html, isNot(contains('loading="lazy"')));
    expect(html, contains('function markPreviewLoaded(preview)'));
    expect(
      html,
      contains('function syncPreviewLoadState(preview, frame, expectedSrc)'),
    );
    expect(html, contains('function unloadPreview(detailsNode)'));
    expect(html, contains("frame.src = 'about:blank';"));
    expect(html, contains("frame.removeAttribute('data-preview-active-src');"));
    expect(html, contains('window.setTimeout(() => syncPreviewLoadState'));
    expect(
      html,
      contains(
        '.source-preview-frame { background: #fbfcfe; border: 1px solid var(--soft-border); border-radius: 6px; display: block;',
      ),
    );
    expect(html, isNot(contains('Coverage details')));
    expect(html, isNot(contains('class="group-detail"')));
    expect(html, isNot(contains('class="file-detail"')));
    expect(html, isNot(contains('if (a &lt; b) return a;')));
    expect(preview, contains('if (a &lt; b) return a;'));
    expect(preview, contains('class="line uncovered"'));
    expect(preview, contains('class="source-lines"'));
    expect(preview, contains('<p class="file-meta">score 28</p>'));
    expect(preview, contains('../assets/source_preview.css'));
    expect(html, isNot(contains('Missing ranges')));
    expect(html, isNot(contains('Hits are LCOV execution counts')));
    expect(html, isNot(contains('LCOV did not mark the line executable')));
    expect(preview, contains('<details class="line-detail">'));
    expect(preview, contains('<span>Status: covered</span>'));
    expect(preview, contains('<span>Hits: 1</span>'));
    expect(html, isNot(contains('<span>Tests:')));
    expect(html, contains('.tree-file-preview { margin: 0 18px 14px; }'));
    expect(
      previewCss,
      contains(
        '.line.covered { background: #ecfdf3; box-shadow: inset 3px 0 var(--green); }',
      ),
    );
    expect(html, isNot(contains('table class="source"')));
  });

  test('renders extra coverage insights', () {
    const fullFile = CoverageFile(
      path: 'lib/full.dart',
      summary: CoverageSummary(
        executableLines: 2,
        coveredLines: 2,
        uncoveredLines: 0,
        missingSourceFiles: 0,
        filesBelowThreshold: 0,
        branchFound: 2,
        branchHit: 2,
      ),
      lines: [],
      uncoveredRanges: [],
      hasMissingSource: false,
      score: 0,
      isBelowThreshold: false,
    );
    const zeroFile = CoverageFile(
      path: 'lib/zero.dart',
      summary: CoverageSummary(
        executableLines: 3,
        coveredLines: 0,
        uncoveredLines: 3,
        missingSourceFiles: 0,
        filesBelowThreshold: 1,
        branchFound: 2,
        branchHit: 0,
      ),
      lines: [],
      uncoveredRanges: [CoverageRange(start: 10, end: 12)],
      hasMissingSource: false,
      score: 30,
      isBelowThreshold: true,
    );
    const partialFile = CoverageFile(
      path: 'lib/partial.dart',
      summary: CoverageSummary(
        executableLines: 5,
        coveredLines: 3,
        uncoveredLines: 2,
        missingSourceFiles: 0,
        filesBelowThreshold: 1,
        branchFound: 4,
        branchHit: 1,
      ),
      lines: [],
      uncoveredRanges: [CoverageRange(start: 20, end: 21)],
      hasMissingSource: false,
      score: 20,
      isBelowThreshold: true,
    );

    final report = CoverageReport(
      generatedAt: DateTime.utc(2026, 6, 26, 12),
      summary: const CoverageSummary(
        executableLines: 10,
        coveredLines: 5,
        uncoveredLines: 5,
        missingSourceFiles: 0,
        filesBelowThreshold: 2,
        branchFound: 8,
        branchHit: 3,
      ),
      groups: const [],
      hotspots: const [zeroFile, partialFile],
      warnings: const [],
      files: const [fullFile, zeroFile, partialFile],
      excludedFiles: const [
        CoverageExcludedFile(
          path: 'lib/generated.g.dart',
          reason: 'Matched exclude pattern **/*.g.dart',
        ),
        CoverageExcludedFile(
          path: 'lib/config.config.dart',
          reason: 'Matched exclude pattern **/*.config.dart',
        ),
      ],
    );

    final html = HtmlReportRenderer().render(report);

    expect(html, contains('Coverage insights'));
    expect(
      html,
      contains(
        '<article class="summary-tile hint-card" tabindex="0" data-hint="Percentage of executable LCOV lines that ran at least once."><span>Line coverage</span><strong>50.0%</strong></article>',
      ),
    );
    expect(
      html,
      contains(
        '<article class="summary-tile hint-card" tabindex="0" data-hint="Executable LCOV lines with zero hits."><span>Uncovered lines</span><strong>5</strong></article>',
      ),
    );
    expect(
      html,
      contains(
        '<article class="summary-tile hint-card" tabindex="0" data-hint="Files present in LCOV but not found under the selected source directory."><span>Missing source</span><strong>0</strong></article>',
      ),
    );
    expect(html, contains('<section class="summary-section">'));
    expect(html, contains('<div class="summary-grid">'));
    expect(html, contains('<div class="summary-drawer-stack">'));
    expect(html, contains('.summary-section { padding: 20px 32px 8px; }'));
    expect(
      html,
      contains(
        '.summary-grid { align-items: stretch; display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 12px; }',
      ),
    );
    expect(
      html,
      contains('.summary-section { padding-left: 16px; padding-right: 16px; }'),
    );
    expect(
      html,
      contains(
        '.summary-grid { grid-template-columns: repeat(5, minmax(132px, 1fr)); overflow-x: auto; }',
      ),
    );
    expect(html, contains('.hint-card::before'));
    expect(html, contains('.hint-card:hover::before'));
    expect(html, contains('.hint-card:focus-visible::before'));
    expect(html, isNot(contains('summary-hint-icon')));
    expect(
      html,
      contains('<span>Fully covered files</span><strong>1 / 3</strong>'),
    );
    expect(
      html,
      contains('<span>Zero coverage files</span><strong>1</strong>'),
    );
    expect(
      html,
      contains('<span>Median file coverage</span><strong>60.0%</strong>'),
    );
    expect(html, isNot(contains('Largest gap')));
    expect(html, isNot(contains('Top 5 uncovered share')));
    expect(html, contains('<span>Excluded files</span><strong>2</strong>'));
    expect(html, contains('<span>Branches hit</span><strong>3 / 8</strong>'));
    expect(
      html,
      contains(
        '<button class="summary-card-tile summary-toggle hint-card" type="button" data-summary-target="summary-files-below-threshold" aria-expanded="false" data-hint="Files whose line coverage is below the configured threshold."><span>Files below threshold</span><strong>2</strong></button>',
      ),
    );
    expect(html, isNot(contains('class="summary-card summary-list-card"')));
    expect(
      html,
      contains(
        '<section class="summary-list-panel" id="summary-files-below-threshold" hidden>',
      ),
    );
    expect(html, isNot(contains('.summary-list-card { display: contents; }')));
    expect(html, contains('.summary-drawer-stack { margin-top: 12px; }'));
    expect(
      html,
      contains(
        '.summary-list-panel { background: var(--panel); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; }',
      ),
    );
    expect(
      html,
      contains(
        '.summary-card-tile::after { align-items: center; background: #f3f6fa; border: 1px solid var(--soft-border); border-radius: 999px; color: var(--muted); content: ">"; display: flex; font-size: 15px; font-weight: 700; height: 24px; justify-content: center; line-height: 1; position: absolute; right: 14px; top: 50%; transform: translateY(-50%); transition: transform 120ms ease, background 120ms ease, border-color 120ms ease, color 120ms ease; width: 24px; }',
      ),
    );
    expect(html, isNot(contains('.summary-list-card[open]')));
    expect(
      html,
      contains(
        '.summary-card-tile[aria-expanded="true"] { border-color: #8ea1b6; box-shadow: 0 0 0 1px rgba(142, 161, 182, .35); }',
      ),
    );
    expect(
      html,
      contains(
        '.summary-card-tile[aria-expanded="true"]::after { background: #eaf1ff; border-color: #b8c7f3; color: #1155cc; transform: translateY(-50%) rotate(90deg); }',
      ),
    );
    expect(
      html,
      contains(
        "document.querySelectorAll('[data-summary-target]').forEach((button) => {",
      ),
    );
    expect(html, contains("button.addEventListener('click', () => {"));
    expect(html, contains("other.setAttribute('aria-expanded', 'false');"));
    expect(html, contains('panel.hidden = true;'));
    expect(
      html,
      contains(
        '<a class="summary-list-item" href="#file-lib-zero-dart" data-open-target="file-lib-zero-dart" data-path="lib/zero.dart">',
      ),
    );
    expect(
      html,
      contains(
        '<span class="summary-list-meta"><span class="pill bad">0.0%</span><span>3 uncovered</span></span>',
      ),
    );
    expect(
      html,
      contains(
        '<button class="summary-card-tile summary-toggle hint-card" type="button" data-summary-target="summary-branch-coverage" aria-expanded="false" data-hint="Decision outcomes covered out of all branch outcomes reported by LCOV."><span>Branch coverage</span><strong>37.5%</strong></button>',
      ),
    );
    expect(
      html,
      contains(
        '<section class="summary-list-panel" id="summary-branch-coverage" hidden>',
      ),
    );
    expect(
      html,
      contains(
        '<article class="hint-card" tabindex="0" data-hint="Files with every executable LCOV line covered."><span>Fully covered files</span><strong>1 / 3</strong></article>',
      ),
    );
    expect(
      html,
      contains(
        '<article class="hint-card" tabindex="0" data-hint="Files skipped by coverage_lens exclude patterns and not counted in coverage totals."><span>Excluded files</span><strong>2</strong></article>',
      ),
    );
    expect(
      html,
      contains(
        '<a class="summary-list-item" href="#file-lib-partial-dart" data-open-target="file-lib-partial-dart" data-path="lib/partial.dart">',
      ),
    );
    expect(
      html,
      contains(
        '<span class="summary-list-meta"><span class="pill bad">1 / 4</span><span>3 missing</span></span>',
      ),
    );
  });

  test('renders nested coverage tree with aggregate folder coverage', () {
    const featureFile = CoverageFile(
      path: 'lib/features/a.dart',
      summary: CoverageSummary(
        executableLines: 2,
        coveredLines: 1,
        uncoveredLines: 1,
        missingSourceFiles: 0,
        filesBelowThreshold: 1,
        branchFound: 0,
        branchHit: 0,
      ),
      lines: [
        CoverageLine(
          number: 1,
          hitCount: 1,
          status: CoverageLineStatus.covered,
          text: 'void covered() {}',
        ),
        CoverageLine(
          number: 2,
          hitCount: 0,
          status: CoverageLineStatus.uncovered,
          text: 'void uncovered() {}',
        ),
      ],
      uncoveredRanges: [CoverageRange(start: 2, end: 2)],
      hasMissingSource: false,
      score: 25,
      isBelowThreshold: true,
    );
    const nestedFile = CoverageFile(
      path: 'lib/features/nested/b.dart',
      summary: CoverageSummary(
        executableLines: 2,
        coveredLines: 2,
        uncoveredLines: 0,
        missingSourceFiles: 0,
        filesBelowThreshold: 0,
        branchFound: 0,
        branchHit: 0,
      ),
      lines: [
        CoverageLine(
          number: 1,
          hitCount: 1,
          status: CoverageLineStatus.covered,
          text: 'void coveredA() {}',
        ),
        CoverageLine(
          number: 2,
          hitCount: 1,
          status: CoverageLineStatus.covered,
          text: 'void coveredB() {}',
        ),
      ],
      uncoveredRanges: [],
      hasMissingSource: false,
      score: 0,
      isBelowThreshold: false,
    );

    final report = CoverageReport(
      generatedAt: DateTime.utc(2026, 6, 26, 12),
      summary: const CoverageSummary(
        executableLines: 4,
        coveredLines: 3,
        uncoveredLines: 1,
        missingSourceFiles: 0,
        filesBelowThreshold: 1,
        branchFound: 0,
        branchHit: 0,
      ),
      groups: const [
        CoverageGroup(
          name: 'lib/features',
          path: 'lib/features',
          summary: CoverageSummary(
            executableLines: 2,
            coveredLines: 1,
            uncoveredLines: 1,
            missingSourceFiles: 0,
            filesBelowThreshold: 1,
            branchFound: 0,
            branchHit: 0,
          ),
        ),
        CoverageGroup(
          name: 'lib/features/nested',
          path: 'lib/features/nested',
          summary: CoverageSummary(
            executableLines: 2,
            coveredLines: 2,
            uncoveredLines: 0,
            missingSourceFiles: 0,
            filesBelowThreshold: 0,
            branchFound: 0,
            branchHit: 0,
          ),
        ),
      ],
      hotspots: const [featureFile],
      warnings: const [],
      files: const [featureFile, nestedFile],
      excludedFiles: const [
        CoverageExcludedFile(
          path: 'lib/features/generated_model.g.dart',
          reason: 'Matched exclude pattern **/*.g.dart',
        ),
      ],
    );

    final html = HtmlReportRenderer().render(report);

    expect(
      html,
      contains(
        '<details class="tree-folder" id="tree-folder-lib" data-tree-path="lib">',
      ),
    );
    expect(
      html,
      contains(
        '<details class="tree-folder" id="tree-folder-lib-features" data-tree-path="lib/features">',
      ),
    );
    expect(
      html,
      contains(
        '<details class="tree-folder" id="tree-folder-lib-features-nested" data-tree-path="lib/features/nested">',
      ),
    );
    expect(
      html,
      contains(
        '<details class="tree-file-detail" id="file-lib-features-a-dart" data-tree-path="lib/features/a.dart" data-path="lib/features/a.dart">',
      ),
    );
    expect(
      html,
      contains('<summary class="tree-row tree-file" style="--depth: 2">'),
    );
    expect(html, contains('<span class="tree-label">features</span>'));
    expect(html, contains('<span class="tree-file-name">a.dart</span>'));
    expect(
      html,
      contains(
        '<div class="tree-row tree-excluded-file" style="--depth: 2" data-tree-path="lib/features/generated_model.g.dart">',
      ),
    );
    expect(
      html,
      contains('<span class="tree-file-name">generated_model.g.dart</span>'),
    );
    expect(
      html,
      contains('<span class="tree-pill pill muted">Excluded</span>'),
    );
    expect(html, contains('Matched exclude pattern **/*.g.dart'));
    expect(html, contains('<span class="tree-count">2 files</span>'));
    expect(
      html,
      contains('<span class="tree-count excluded">1 excluded</span>'),
    );
    expect(html, contains('<span class="tree-pill pill warn">75.0%</span>'));
  });

  test('renders coverage tree when only excluded files are present', () {
    final report = CoverageReport(
      generatedAt: DateTime.utc(2026, 6, 26, 12),
      summary: const CoverageSummary(
        executableLines: 0,
        coveredLines: 0,
        uncoveredLines: 0,
        missingSourceFiles: 0,
        filesBelowThreshold: 0,
        branchFound: 0,
        branchHit: 0,
      ),
      groups: const [],
      hotspots: const [],
      warnings: const [],
      files: const [],
      excludedFiles: const [
        CoverageExcludedFile(
          path: 'lib/generated_model.g.dart',
          reason: 'Matched exclude pattern **/*.g.dart',
        ),
      ],
    );

    final html = HtmlReportRenderer().render(report);

    expect(html, contains('Coverage tree'));
    expect(
      html,
      contains(
        '<div class="tree-row tree-excluded-file" style="--depth: 1" data-tree-path="lib/generated_model.g.dart">',
      ),
    );
    expect(
      html,
      contains('<span class="tree-file-name">generated_model.g.dart</span>'),
    );
    expect(
      html,
      contains('<span class="tree-pill pill muted">Excluded</span>'),
    );
  });

  test(
    'renders non executable source lines with inherited visual coverage',
    () {
      final report = CoverageReport(
        generatedAt: DateTime.utc(2026, 6, 26, 12),
        summary: const CoverageSummary(
          executableLines: 2,
          coveredLines: 0,
          uncoveredLines: 2,
          missingSourceFiles: 0,
          filesBelowThreshold: 1,
          branchFound: 0,
          branchHit: 0,
        ),
        groups: const [],
        hotspots: const [],
        warnings: const [],
        files: const [
          CoverageFile(
            path: 'lib/a.dart',
            summary: CoverageSummary(
              executableLines: 2,
              coveredLines: 0,
              uncoveredLines: 2,
              missingSourceFiles: 0,
              filesBelowThreshold: 1,
              branchFound: 0,
              branchHit: 0,
            ),
            lines: [
              CoverageLine(
                number: 10,
                hitCount: 0,
                status: CoverageLineStatus.uncovered,
                text: 'if (enabled) {',
              ),
              CoverageLine(
                number: 11,
                hitCount: 0,
                status: CoverageLineStatus.nonExecutable,
                text: '  return value;',
              ),
              CoverageLine(
                number: 12,
                hitCount: 0,
                status: CoverageLineStatus.uncovered,
                text: '}',
              ),
            ],
            uncoveredRanges: [CoverageRange(start: 10, end: 10)],
            hasMissingSource: false,
            score: 10,
            isBelowThreshold: true,
          ),
        ],
      );

      final output = HtmlReportRenderer().renderReport(report);
      final html = output.indexHtml;
      final preview = output.assets['files/lib-a-dart.html']!;

      expect(
        preview,
        contains('<summary class="line nonExecutable inferredUncovered">'),
      );
      expect(preview, contains('<span class="line-number">11</span>'));
      expect(preview, contains('<span class="line-hits">-</span>'));
      expect(preview, contains('<span>Status: not executable</span>'));
      expect(preview, contains('<span>Hits: none</span>'));
      expect(preview, contains('<span>Block: uncovered</span>'));
      expect(html, isNot(contains('<span>Tests: not applicable</span>')));
    },
  );

  test('renders branch coverage markers in source preview', () {
    final report = CoverageReport(
      generatedAt: DateTime.utc(2026, 6, 26, 12),
      summary: const CoverageSummary(
        executableLines: 1,
        coveredLines: 1,
        uncoveredLines: 0,
        missingSourceFiles: 0,
        filesBelowThreshold: 0,
        branchFound: 2,
        branchHit: 1,
      ),
      groups: const [],
      hotspots: const [],
      warnings: const [],
      files: const [
        CoverageFile(
          path: 'lib/a.dart',
          summary: CoverageSummary(
            executableLines: 1,
            coveredLines: 1,
            uncoveredLines: 0,
            missingSourceFiles: 0,
            filesBelowThreshold: 0,
            branchFound: 2,
            branchHit: 1,
          ),
          lines: [
            CoverageLine(
              number: 5,
              hitCount: 1,
              status: CoverageLineStatus.covered,
              text: 'if (enabled) return value;',
              branchFound: 2,
              branchHit: 1,
            ),
          ],
          uncoveredRanges: [],
          hasMissingSource: false,
          score: 0,
          isBelowThreshold: false,
        ),
      ],
    );

    final output = HtmlReportRenderer().renderReport(report);
    final preview = output.assets['files/lib-a-dart.html']!;
    final previewCss = output.assets['assets/source_preview.css']!;

    expect(preview, contains('<summary class="line covered branchMissing">'));
    expect(preview, contains('<span class="line-branch">B 1/2</span>'));
    expect(preview, contains('<span>Branches: 1 / 2</span>'));
    expect(preview, contains('<span>Missing branches: 1</span>'));
    expect(
      previewCss,
      contains(
        '.line.branchMissing { background: #fff8e8; box-shadow: inset 3px 0 var(--amber); }',
      ),
    );
  });
}
