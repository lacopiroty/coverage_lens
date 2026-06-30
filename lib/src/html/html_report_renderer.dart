import '../model/coverage_models.dart';

/// HTML report document and companion asset files.
class HtmlReportOutput {
  /// Creates generated HTML output.
  const HtmlReportOutput({required this.indexHtml, required this.assets});

  /// Main `index.html` content.
  final String indexHtml;

  /// Additional files keyed by output-relative path.
  final Map<String, String> assets;
}

/// Renders an analyzed coverage report as static HTML.
class HtmlReportRenderer {
  /// Renders only the main HTML document.
  String render(CoverageReport report) => renderReport(report).indexHtml;

  /// Renders the main HTML document and lazily loaded source preview assets.
  HtmlReportOutput renderReport(CoverageReport report) {
    return HtmlReportOutput(
      indexHtml: _renderIndex(report),
      assets: {
        'assets/source_preview.css': _sourcePreviewCss(),
        for (final file in report.files)
          _previewPath(file): _filePreviewDocument(file),
      },
    );
  }

  String _renderIndex(CoverageReport report) {
    final buffer = StringBuffer()
      ..writeln('<!doctype html>')
      ..writeln('<html lang="en">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
      )
      ..writeln('<title>Coverage Lens</title>')
      ..writeln('<style>${_css()}</style>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<header class="topbar">')
      ..writeln('<div>')
      ..writeln('<p class="eyebrow">Coverage Lens</p>')
      ..writeln('<h1>Coverage report</h1>')
      ..writeln('<p>Generated: ${_formatGeneratedAt(report.generatedAt)}</p>')
      ..writeln('</div>')
      ..writeln(
        '<div class="score ${_tone(report.summary.lineCoveragePercent)}">${_percent(report.summary.lineCoveragePercent)}</div>',
      )
      ..writeln('</header>')
      ..writeln(_summary(report))
      ..writeln(_insights(report))
      ..writeln(_warnings(report))
      ..writeln(_coverageTree(report))
      ..writeln(_hotspots(report))
      ..writeln(_script())
      ..writeln('</body>')
      ..writeln('</html>');
    return buffer.toString();
  }

  String _summary(CoverageReport report) {
    final branch = report.summary.branchCoveragePercent;
    final belowThresholdFiles = report.files
        .where((file) => file.isBelowThreshold)
        .toList()
      ..sort(_compareLineCoverageRisk);
    final branchGapFiles = report.files
        .where(
          (file) =>
              file.summary.branchFound > 0 &&
              file.summary.branchHit < file.summary.branchFound,
        )
        .toList()
      ..sort(_compareBranchCoverageRisk);
    return '''
<section class="summary-section">
  <div class="summary-grid">
    ${_summaryMetricCard(label: 'Line coverage', value: _percent(report.summary.lineCoveragePercent), hint: 'Percentage of executable LCOV lines that ran at least once.')}
    ${_summaryMetricCard(label: 'Uncovered lines', value: report.summary.uncoveredLines.toString(), hint: 'Executable LCOV lines with zero hits.')}
    ${_summaryListToggle(id: 'summary-files-below-threshold', label: 'Files below threshold', value: report.summary.filesBelowThreshold.toString(), hint: 'Files whose line coverage is below the configured threshold.')}
    ${_summaryMetricCard(label: 'Missing source', value: report.summary.missingSourceFiles.toString(), hint: 'Files present in LCOV but not found under the selected source directory.')}
    ${_summaryListToggle(id: 'summary-branch-coverage', label: 'Branch coverage', value: branch == null ? 'n/a' : _percent(branch), hint: 'Decision outcomes covered out of all branch outcomes reported by LCOV.')}
  </div>
  <div class="summary-drawer-stack">
    ${_summaryListPanel(id: 'summary-files-below-threshold', items: _belowThresholdFileItems(belowThresholdFiles), emptyMessage: 'No files below threshold.')}
    ${_summaryListPanel(id: 'summary-branch-coverage', items: _branchGapFileItems(branchGapFiles), emptyMessage: branch == null ? 'No branch data in LCOV.' : 'All discovered branches are covered.')}
  </div>
</section>
<section class="quality"><div style="width: ${report.summary.lineCoveragePercent.clamp(0, 100).toStringAsFixed(1)}%"></div></section>
''';
  }

  String _summaryMetricCard({
    required String label,
    required String value,
    required String hint,
  }) {
    return '<article class="summary-tile hint-card" tabindex="0" data-hint="${_escape(hint)}"><span>$label</span><strong>$value</strong></article>';
  }

  String _summaryListToggle({
    required String id,
    required String label,
    required String value,
    required String hint,
  }) {
    return '<button class="summary-card-tile summary-toggle hint-card" type="button" data-summary-target="$id" aria-expanded="false" data-hint="${_escape(hint)}"><span>$label</span><strong>$value</strong></button>';
  }

  String _summaryListPanel({
    required String id,
    required String items,
    required String emptyMessage,
  }) {
    final content = items.isEmpty
        ? '<p class="summary-list-empty">${_escape(emptyMessage)}</p>'
        : items;
    return '''
<section class="summary-list-panel" id="$id" hidden>
  <div class="summary-list">$content</div>
</section>''';
  }

  String _belowThresholdFileItems(List<CoverageFile> files) {
    return files.map((file) {
      return _summaryFileItem(
        file,
        '<span class="pill ${_tone(file.summary.lineCoveragePercent)}">${_percent(file.summary.lineCoveragePercent)}</span><span>${file.summary.uncoveredLines} uncovered</span>',
      );
    }).join();
  }

  String _branchGapFileItems(List<CoverageFile> files) {
    return files.map((file) {
      final missingBranches = file.summary.branchFound - file.summary.branchHit;
      final branchCoverage = file.summary.branchCoveragePercent ?? 0;
      return _summaryFileItem(
        file,
        '<span class="pill ${_tone(branchCoverage)}">${file.summary.branchHit} / ${file.summary.branchFound}</span><span>${_missingBranchLabel(missingBranches)}</span>',
      );
    }).join();
  }

  String _summaryFileItem(CoverageFile file, String meta) {
    final fileId = 'file-${_id(file.path)}';
    return '''
<a class="summary-list-item" href="#$fileId" data-open-target="$fileId" data-path="${_escape(file.path)}">
  <span class="summary-list-path">${_escape(file.path)}</span>
  <span class="summary-list-meta">$meta</span>
</a>''';
  }

  String _insights(CoverageReport report) {
    final files = report.files;
    final fullyCovered = files
        .where(
          (file) =>
              file.summary.executableLines > 0 &&
              file.summary.uncoveredLines == 0,
        )
        .length;
    final zeroCoverage = files
        .where(
          (file) =>
              file.summary.executableLines > 0 &&
              file.summary.coveredLines == 0,
        )
        .length;
    final branchHitLabel = report.summary.branchFound == 0
        ? 'n/a'
        : '${report.summary.branchHit} / ${report.summary.branchFound}';

    return '''
<section class="panel insights-panel">
  <h2>Coverage insights</h2>
  <div class="insights-grid">
    ${_insightCard(label: 'Fully covered files', value: '$fullyCovered / ${files.length}', hint: 'Files with every executable LCOV line covered.')}
    ${_insightCard(label: 'Zero coverage files', value: zeroCoverage.toString(), hint: 'Files with executable lines but no hits.')}
    ${_insightCard(label: 'Median file coverage', value: _percent(_medianFileCoverage(files)), hint: 'Middle file coverage value after sorting files by line coverage.')}
    ${_insightCard(label: 'Excluded files', value: report.excludedFiles.length.toString(), hint: 'Files skipped by coverage_lens exclude patterns and not counted in coverage totals.')}
    ${_insightCard(label: 'Branches hit', value: branchHitLabel, hint: 'Executed branch outcomes out of all branch outcomes reported by LCOV.')}
  </div>
</section>
''';
  }

  String _insightCard({
    required String label,
    required String value,
    required String hint,
  }) {
    return '<article class="hint-card" tabindex="0" data-hint="${_escape(hint)}"><span>$label</span><strong>$value</strong></article>';
  }

  String _warnings(CoverageReport report) {
    if (report.warnings.isEmpty) {
      return '';
    }
    final items =
        report.warnings.map((warning) => '<li>${_escape(warning)}</li>').join();
    return '''
<section class="panel warning-panel">
  <h2>Warnings</h2>
  <ul>$items</ul>
</section>
''';
  }

  String _coverageTree(CoverageReport report) {
    if (report.files.isEmpty && report.excludedFiles.isEmpty) {
      return '';
    }
    final tree = _buildCoverageTree(report.files, report.excludedFiles);
    final folders = tree.directories.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final files = tree.files.toList()..sort((a, b) => a.path.compareTo(b.path));
    final excludedFiles = tree.excludedFiles.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final items = [
      ...folders.map((folder) => _treeFolder(folder, depth: 0)),
      ...files.map((file) => _treeFile(file, depth: 0)),
      ...excludedFiles.map((file) => _treeExcludedFile(file, depth: 0)),
    ].join();
    return '''
<section class="panel tree-panel">
  <div class="tree-toolbar">
    <h2>Coverage tree</h2>
    <div class="tree-actions">
      <button class="tree-action" type="button" data-tree-action="expand">Expand all</button>
      <button class="tree-action" type="button" data-tree-action="collapse">Collapse all</button>
    </div>
  </div>
  <div class="coverage-tree">$items</div>
</section>
''';
  }

  _CoverageTreeDirectory _buildCoverageTree(
    List<CoverageFile> files,
    List<CoverageExcludedFile> excludedFiles,
  ) {
    final root = _CoverageTreeDirectory(name: '', path: '');
    for (final file in files) {
      _directoryForPath(root, file.path).files.add(file);
    }
    for (final file in excludedFiles) {
      _directoryForPath(root, file.path).excludedFiles.add(file);
    }
    return root;
  }

  _CoverageTreeDirectory _directoryForPath(
    _CoverageTreeDirectory root,
    String filePath,
  ) {
    final parts = _normalizePath(
      filePath,
    ).split('/').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) {
      return root;
    }

    var current = root;
    final pathParts = <String>[];
    for (final segment in parts.take(parts.length - 1)) {
      pathParts.add(segment);
      final directoryPath = pathParts.join('/');
      current = current.directories.putIfAbsent(
        segment,
        () => _CoverageTreeDirectory(name: segment, path: directoryPath),
      );
    }
    return current;
  }

  String _treeFolder(_CoverageTreeDirectory directory, {required int depth}) {
    final summary = _summaryForTreeDirectory(directory);
    final childFolders = directory.directories.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final files = directory.files.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final excludedFiles = directory.excludedFiles.toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final excludedCount = _excludedFileCountForTreeDirectory(directory);
    final children = [
      ...childFolders.map((folder) => _treeFolder(folder, depth: depth + 1)),
      ...files.map((file) => _treeFile(file, depth: depth + 1)),
      ...excludedFiles.map((file) => _treeExcludedFile(file, depth: depth + 1)),
    ].join();
    return '''
<details class="tree-folder" id="tree-folder-${_id(directory.path)}" data-tree-path="${_escape(directory.path)}">
  <summary class="tree-row folder-row" style="--depth: $depth">
    <span class="tree-name"><span class="chevron">&rsaquo;</span><span class="tree-icon folder"></span><span class="tree-label">${_escape(directory.name)}</span></span>
    <span class="tree-meta"><span class="tree-pill pill ${_tone(summary.lineCoveragePercent)}">${_percent(summary.lineCoveragePercent)}</span><span>${summary.uncoveredLines} uncovered</span><span class="tree-count">${_fileCountLabel(_fileCountForTreeDirectory(directory))}</span>${_excludedCountLabel(excludedCount)}</span>
  </summary>
  <div class="tree-children">$children</div>
</details>''';
  }

  String _treeFile(CoverageFile file, {required int depth}) {
    final fileId = 'file-${_id(file.path)}';
    return '''
<details class="tree-file-detail" id="$fileId" data-tree-path="${_escape(file.path)}" data-path="${_escape(file.path)}">
  <summary class="tree-row tree-file" style="--depth: $depth">
    <span class="tree-name"><span class="tree-spacer"></span><span class="tree-icon file"></span><span class="tree-file-name">${_escape(_basename(file.path))}</span></span>
    <span class="tree-meta"><span class="tree-pill pill ${_tone(file.summary.lineCoveragePercent)}">${_percent(file.summary.lineCoveragePercent)}</span><span>${file.summary.uncoveredLines} uncovered</span></span>
  </summary>
  ${_filePreviewFrame(file, depth: depth)}
</details>''';
  }

  String _treeExcludedFile(CoverageExcludedFile file, {required int depth}) {
    return '''
<div class="tree-row tree-excluded-file" style="--depth: $depth" data-tree-path="${_escape(file.path)}">
  <span class="tree-name"><span class="tree-spacer"></span><span class="tree-icon file excluded"></span><span class="tree-file-name">${_escape(_basename(file.path))}</span></span>
  <span class="tree-meta"><span class="tree-pill pill muted">Excluded</span><span>${_escape(file.reason)}</span></span>
</div>''';
  }

  String _hotspots(CoverageReport report) {
    final items = report.hotspots.where((file) => file.score > 0).take(20).map((
      file,
    ) {
      final fileId = 'file-${_id(file.path)}';
      return '''
<a class="attention-file" href="#$fileId" data-open-target="$fileId" data-path="${_escape(file.path)}">
  <span class="attention-path">${_escape(file.path)}</span>
  <span class="attention-meta"><span class="pill ${_tone(file.summary.lineCoveragePercent)}">${_percent(file.summary.lineCoveragePercent)}</span><span>${file.summary.uncoveredLines} uncovered</span></span>
</a>''';
    }).join();
    return '''
<section class="panel attention-panel">
  <h2>Needs attention</h2>
  <div class="attention-list">$items</div>
</section>
''';
  }

  String _filePreviewFrame(CoverageFile file, {required int depth}) {
    final previewPath = _previewPath(file);
    return '''
<div class="tree-file-preview" style="--depth: $depth" data-preview-src="${_escape(previewPath)}" data-preview-loaded="false">
  <p class="preview-state">Loading source preview...</p>
  <iframe class="source-preview-frame" title="Source preview for ${_escape(file.path)}"></iframe>
</div>
''';
  }

  String _filePreviewDocument(CoverageFile file) {
    return '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_escape(file.path)}</title>
<link rel="stylesheet" href="../assets/source_preview.css">
</head>
<body>
${_sourcePreview(file)}
</body>
</html>
''';
  }

  String _sourcePreview(CoverageFile file) {
    final inheritedStatuses = _inheritedVisualStatuses(file.lines);
    final renderedLines = <String>[];
    for (var index = 0; index < file.lines.length; index += 1) {
      final line = file.lines[index];
      final inheritedStatus = inheritedStatuses[index];
      final lineClasses = _lineCssClasses(line, inheritedStatus);
      renderedLines.add('''
<li class="line-shell $lineClasses">
  <details class="line-detail">
    <summary class="line $lineClasses">
      <span class="line-number">${line.number}</span>
      <span class="line-hits">${_hitLabel(line)}</span>
      <span class="line-branch">${_branchLabel(line)}</span>
      <code>${_escape(line.text)}</code>
    </summary>
    <div class="line-info">${_lineInfo(line, inheritedStatus)}</div>
  </details>
</li>''');
    }
    final lines = renderedLines.join();
    return '''
<div class="source-preview">
  <p class="file-meta">score ${file.score}</p>
  <ol class="source-lines">$lines</ol>
</div>
''';
  }

  String _css() {
    return '''
:root { color-scheme: light; --bg: #f6f8fa; --panel: #ffffff; --text: #17202a; --muted: #657385; --border: #d8dee8; --soft-border: #e7ecf3; --green: #198754; --amber: #b7791f; --red: #c2413b; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--text); font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
.topbar { display: flex; justify-content: space-between; gap: 24px; align-items: center; padding: 28px 32px; background: #101820; color: #fff; }
.eyebrow { margin: 0 0 6px; color: #9fb1c6; font-size: 12px; text-transform: uppercase; letter-spacing: 0; }
h1, h2, p { margin-top: 0; }
.score { min-width: 128px; padding: 18px; border-radius: 8px; text-align: center; font-size: 30px; font-weight: 700; background: #22313f; }
.score.good { color: #7ee2a8; }
.score.warn { color: #ffd37a; }
.score.bad { color: #ff9a92; }
.pill.good { background: #e7f6ed; color: var(--green); }
.pill.warn { background: #fff5d8; color: var(--amber); }
.pill.bad { background: #fff0ef; color: var(--red); }
.summary-section { padding: 20px 32px 8px; }
.summary-grid { align-items: stretch; display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 12px; }
.summary-grid article, .summary-card-tile, .summary-list-panel, .panel { background: var(--panel); border: 1px solid var(--border); border-radius: 8px; }
.summary-grid article, .summary-card-tile { padding: 16px; }
.summary-grid span { display: block; color: var(--muted); font-size: 13px; }
.summary-grid strong { display: block; margin-top: 8px; font-size: 26px; }
.hint-card { position: relative; }
.hint-card::before { background: #101820; border-radius: 6px; bottom: calc(100% + 8px); box-shadow: 0 10px 28px rgba(16, 24, 32, .18); color: #fff; content: attr(data-hint); font-size: 12px; font-weight: 500; left: 12px; line-height: 1.35; max-width: min(320px, calc(100vw - 48px)); opacity: 0; padding: 8px 10px; pointer-events: none; position: absolute; transform: translateY(4px); transition: opacity 120ms ease, transform 120ms ease; white-space: normal; width: max-content; z-index: 20; }
.hint-card:hover::before, .hint-card:focus-visible::before { opacity: 1; transform: translateY(0); }
.summary-card-tile { appearance: none; color: inherit; cursor: pointer; font: inherit; min-height: 100%; padding: 16px 44px 16px 16px; position: relative; text-align: left; transition: background 120ms ease, border-color 120ms ease, box-shadow 120ms ease; width: 100%; }
.summary-card-tile::after { align-items: center; background: #f3f6fa; border: 1px solid var(--soft-border); border-radius: 999px; color: var(--muted); content: ">"; display: flex; font-size: 15px; font-weight: 700; height: 24px; justify-content: center; line-height: 1; position: absolute; right: 14px; top: 50%; transform: translateY(-50%); transition: transform 120ms ease, background 120ms ease, border-color 120ms ease, color 120ms ease; width: 24px; }
.summary-card-tile:hover { background: #f8fafc; border-color: #b9c6d4; box-shadow: 0 1px 0 rgba(16, 24, 32, .04); }
.summary-card-tile[aria-expanded="true"] { border-color: #8ea1b6; box-shadow: 0 0 0 1px rgba(142, 161, 182, .35); }
.summary-card-tile[aria-expanded="true"]::after { background: #eaf1ff; border-color: #b8c7f3; color: #1155cc; transform: translateY(-50%) rotate(90deg); }
.summary-drawer-stack { margin-top: 12px; }
.summary-list-panel { background: var(--panel); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; }
.summary-list { display: grid; max-height: 260px; overflow: auto; }
.summary-list-empty { color: var(--muted); font-size: 13px; margin: 0; padding: 12px 14px; }
.summary-list-item { align-items: center; color: var(--text); display: grid; gap: 8px; grid-template-columns: minmax(0, 1fr); padding: 10px 14px; text-decoration: none; }
.summary-list-item + .summary-list-item { border-top: 1px solid var(--soft-border); }
.summary-list-item:hover { background: #f8fafc; text-decoration: none; }
.summary-list-path { color: var(--text) !important; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 12px !important; overflow-wrap: anywhere; }
.summary-list-meta { align-items: center; display: flex !important; flex-wrap: wrap; gap: 6px; }
.summary-list-meta span { display: inline-flex; }
.quality { height: 10px; margin: 8px 32px 20px; border-radius: 999px; background: #e1e7ef; overflow: hidden; }
.quality div { height: 100%; background: linear-gradient(90deg, var(--red), var(--amber), var(--green)); }
.panel { margin: 16px 32px; padding: 18px; }
.insights-panel { margin-top: 0; }
.insights-panel h2 { margin-bottom: 14px; }
.insights-grid { display: grid; gap: 10px; grid-template-columns: repeat(auto-fit, minmax(168px, 1fr)); }
.insights-grid article { background: #fbfcfe; border: 1px solid var(--soft-border); border-radius: 8px; padding: 13px; }
.insights-grid span { color: var(--muted); display: block; font-size: 12px; }
.insights-grid strong { display: block; font-size: 16px; line-height: 1.25; margin-top: 6px; overflow-wrap: anywhere; }
.warning-panel { border-color: #f3c46b; background: #fff8e8; }
table { width: 100%; border-collapse: collapse; }
th, td { border-bottom: 1px solid var(--border); padding: 9px 10px; text-align: left; vertical-align: top; }
th { color: var(--muted); font-size: 12px; text-transform: uppercase; }
a { color: #1155cc; text-underline-offset: 2px; }
.directory-link { font-weight: 650; text-decoration: none; }
.directory-link:hover, .attention-file:hover { text-decoration: underline; }
.attention-panel { padding-bottom: 10px; }
.attention-list { display: grid; gap: 0; margin-top: 12px; }
.attention-file { align-items: center; color: var(--text); display: grid; gap: 12px; grid-template-columns: minmax(0, 1fr) auto; min-height: 38px; padding: 8px 0; text-decoration: none; }
.attention-file + .attention-file { border-top: 1px solid var(--soft-border); }
.attention-file:hover { background: #f8fafc; }
.attention-path { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 13px; overflow-wrap: anywhere; }
.attention-meta { align-items: center; color: var(--muted); display: flex; gap: 8px; justify-content: flex-end; white-space: nowrap; font-size: 13px; }
.tree-panel { padding: 0; overflow: hidden; }
.tree-toolbar { display: flex; justify-content: space-between; gap: 16px; align-items: center; padding: 18px; border-bottom: 1px solid var(--border); }
.tree-toolbar h2 { margin-bottom: 0; }
.tree-actions { display: flex; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }
.tree-action { background: #f8fafc; border: 1px solid var(--border); border-radius: 6px; color: var(--text); cursor: pointer; font: inherit; font-size: 13px; padding: 7px 10px; }
.tree-action:hover { background: #eef3f8; }
.coverage-tree { padding: 8px 0 12px; }
.tree-folder, .tree-file-detail { scroll-margin-top: 16px; }
.tree-folder + .tree-folder, .tree-file-detail + .tree-file-detail, .tree-folder + .tree-file-detail, .tree-file-detail + .tree-folder { border-top: 1px solid var(--soft-border); }
.tree-row { align-items: center; color: var(--text); display: grid; gap: 12px; grid-template-columns: minmax(0, 1fr) auto; min-height: 38px; padding: 7px 18px 7px calc(18px + (var(--depth) * 22px)); text-decoration: none; }
.tree-row:hover { background: #f7f9fc; }
.tree-name { align-items: center; display: flex; gap: 8px; min-width: 0; }
.tree-label { font-weight: 700; overflow-wrap: anywhere; }
.tree-file-name { font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 13px; overflow-wrap: anywhere; }
.tree-meta { align-items: center; color: var(--muted); display: flex; gap: 8px; justify-content: flex-end; white-space: nowrap; font-size: 13px; }
.tree-count { min-width: 48px; text-align: right; }
.tree-icon { display: inline-block; flex: 0 0 auto; height: 14px; position: relative; width: 14px; }
.tree-icon.folder { border: 1px solid #8ea1b6; border-radius: 3px; }
.tree-icon.folder::before { background: var(--panel); border-left: 1px solid #8ea1b6; border-right: 1px solid #8ea1b6; border-top: 1px solid #8ea1b6; border-radius: 2px 2px 0 0; content: ""; height: 4px; left: 1px; position: absolute; top: -4px; width: 7px; }
.tree-icon.file { border: 1px solid #a5b2c1; border-radius: 3px; }
.tree-icon.file::after { border-left: 4px solid transparent; border-top: 4px solid #a5b2c1; content: ""; position: absolute; right: 0; top: 0; }
.tree-icon.file.excluded { opacity: .45; }
.tree-spacer { flex: 0 0 auto; width: 20px; }
.tree-pill { min-width: 56px; justify-content: center; }
.tree-pill.muted { background: #eef2f6; color: var(--muted); }
.tree-count.excluded { color: var(--muted); min-width: 70px; }
.tree-excluded-file { color: var(--muted); }
.tree-excluded-file .tree-file-name { text-decoration: line-through; text-decoration-thickness: 1px; text-decoration-color: #b7c0cc; }
details > summary { list-style: none; }
details > summary::-webkit-details-marker { display: none; }
.tree-file-detail > summary { cursor: pointer; }
.tree-file-detail[open] > summary { background: #f8fafc; }
.tree-file-preview { margin: 0 18px 14px; }
.chevron { color: var(--muted); display: inline-block; font-size: 20px; line-height: 1; transition: transform 120ms ease; }
details[open] > summary .chevron { transform: rotate(90deg); }
.pill { border-radius: 999px; display: inline-flex; font-weight: 700; padding: 3px 8px; }
.preview-state { background: #fbfcfe; border: 1px solid var(--soft-border); border-radius: 6px; color: var(--muted); font-size: 12px; margin: 0; padding: 12px; }
.tree-file-preview[data-preview-loaded="true"] .preview-state { display: none; }
.tree-file-preview[data-preview-error="true"] .preview-state { color: var(--red); display: block; }
.source-preview-frame { background: #fbfcfe; border: 1px solid var(--soft-border); border-radius: 6px; display: block; height: 560px; min-height: 140px; width: 100%; }
.tree-file-preview[data-preview-loaded="true"] .source-preview-frame { display: block; }
@media (max-width: 900px) { .topbar { align-items: flex-start; flex-direction: column; } .summary-section { padding-left: 16px; padding-right: 16px; } .summary-grid { grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); overflow-x: visible; } .panel, .quality { margin-left: 16px; margin-right: 16px; } .insights-grid { grid-template-columns: 1fr 1fr; } .tree-toolbar { align-items: flex-start; grid-template-columns: 1fr; flex-direction: column; } .tree-actions { justify-content: flex-start; } .attention-file, .tree-row { align-items: flex-start; grid-template-columns: 1fr; } .tree-row { padding-left: calc(14px + (var(--depth) * 16px)); } .attention-meta, .tree-meta { justify-content: flex-start; white-space: normal; } }
''';
  }

  String _sourcePreviewCss() {
    return '''
:root { color-scheme: light; --text: #17202a; --muted: #657385; --soft-border: #e7ecf3; --green: #198754; --amber: #b7791f; --red: #c2413b; }
* { box-sizing: border-box; }
body { background: #fbfcfe; color: var(--text); font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; margin: 0; }
.source-preview { padding: 0; }
.file-meta { color: var(--muted); font-size: 12px; margin: 0; padding: 8px 10px; }
.source-lines { background: #fbfcfe; border: 0; list-style: none; margin: 0; overflow: auto; padding: 6px 0; }
.line-shell { list-style: none; }
.line-detail > summary { cursor: pointer; list-style: none; }
.line-detail > summary::-webkit-details-marker { display: none; }
.line { align-items: baseline; border: 0; display: grid; font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 12px; gap: 10px; grid-template-columns: 52px 48px 58px minmax(0, max-content); line-height: 1.45; min-height: 20px; padding: 1px 10px; }
.line code { font-family: inherit; white-space: pre; }
.line-number, .line-hits, .line-branch { color: var(--muted); text-align: right; user-select: none; }
.line-branch { font-weight: 700; }
.line-info { background: #ffffff; color: var(--muted); display: flex; flex-wrap: wrap; font-size: 11px; gap: 8px; padding: 4px 10px 7px 188px; }
.line-info span { background: #f8fafc; border: 1px solid var(--soft-border); border-radius: 999px; padding: 2px 7px; }
.line.covered { background: #ecfdf3; box-shadow: inset 3px 0 var(--green); }
.line.covered .line-hits { color: var(--green); font-weight: 700; }
.line.uncovered { background: #fff5f3; box-shadow: inset 3px 0 var(--red); }
.line.uncovered .line-hits { color: var(--red); font-weight: 700; }
.line.branchMissing { background: #fff8e8; box-shadow: inset 3px 0 var(--amber); }
.line.branchMissing .line-branch { color: var(--amber); }
.line.nonExecutable { color: #7f8a99; }
.line.nonExecutable .line-hits { color: #b7c0cc; }
.line.nonExecutable.inferredCovered { background: #f5fff8; box-shadow: inset 3px 0 #a8e3ba; color: var(--text); }
.line.nonExecutable.inferredUncovered { background: #fff8f6; box-shadow: inset 3px 0 #f0aaa4; color: var(--text); }
.line.ignored { background: #f5f7fa; color: var(--muted); }
.line.missingSource { background: #fff8e6; }
''';
  }

  String _script() {
    return '''
<script>
function markPreviewLoaded(preview) {
  preview.setAttribute('data-preview-loaded', 'true');
  preview.removeAttribute('data-preview-loading');
  preview.removeAttribute('data-preview-error');
}

function markPreviewError(preview) {
  preview.removeAttribute('data-preview-loading');
  preview.setAttribute('data-preview-error', 'true');
  const state = preview.querySelector('.preview-state');
  if (state) state.textContent = 'Could not load source preview.';
}

function resetPreviewState(preview) {
  preview.setAttribute('data-preview-loaded', 'false');
  preview.removeAttribute('data-preview-loading');
  preview.removeAttribute('data-preview-error');
  const state = preview.querySelector('.preview-state');
  if (state) state.textContent = 'Loading source preview...';
}

function nextPreviewToken(preview) {
  const next = String((Number(preview.getAttribute('data-preview-token')) || 0) + 1);
  preview.setAttribute('data-preview-token', next);
  return next;
}

function isPreviewRequestCurrent(preview, frame, expectedSrc, token, detailsNode) {
  if (!preview || !frame || preview.getAttribute('data-preview-token') !== token) return false;
  if (detailsNode && !detailsNode.open) return false;
  return frame.getAttribute('data-preview-active-src') === expectedSrc &&
    frame.getAttribute('src') === expectedSrc;
}

function frameMatchesPreviewSource(frame, expectedSrc) {
  if (!frame || frame.getAttribute('src') !== expectedSrc) return false;
  try {
    const expectedUrl = new URL(expectedSrc, window.location.href).href;
    if (frame.contentWindow.location.href !== expectedUrl) return false;
    const doc = frame.contentDocument;
    return Boolean(doc && doc.readyState !== 'loading' && doc.body);
  } catch (_) {
    // Cross-origin access should not happen for generated local files, but keep
    // iframe loading resilient if a report is hosted from an unusual location.
    return frame.getAttribute('src') === expectedSrc;
  }
}

function resizePreviewFrame(preview, frame) {
  if (!preview || !frame) return;
  try {
    const doc = frame.contentDocument;
    const source = doc ? doc.querySelector('.source-preview') : null;
    if (!source) return;
    const minHeight = 140;
    const maxHeight = 560;
    const measuredHeight = Math.ceil(source.getBoundingClientRect().height);
    const contentHeight = Math.max(measuredHeight, source.scrollHeight);
    const height = Math.max(minHeight, Math.min(maxHeight, contentHeight));
    frame.style.height = height + 'px';
    preview.setAttribute('data-preview-height', String(height));
  } catch (_) {
    // Keep the default fixed frame height if browser restrictions block access.
  }
}

function resetPreviewFrameHeight(preview, frame) {
  if (frame) frame.style.height = '';
  if (preview) preview.removeAttribute('data-preview-height');
}

function bindPreviewAutoResize(preview, frame) {
  if (!preview || !frame) return;
  try {
    const doc = frame.contentDocument;
    if (!doc || !doc.body || doc.body.getAttribute('data-preview-resize-bound') === 'true') return;
    doc.body.setAttribute('data-preview-resize-bound', 'true');
    doc.addEventListener('toggle', () => {
      window.requestAnimationFrame(() => resizePreviewFrame(preview, frame));
    }, true);
  } catch (_) {
    // Preview stays usable with the default height if resize observation fails.
  }
}

function syncPreviewLoadState(preview, frame, expectedSrc, detailsNode, token) {
  if (!isPreviewRequestCurrent(preview, frame, expectedSrc, token, detailsNode)) return false;
  if (preview.getAttribute('data-preview-loaded') === 'true') return true;
  if (!frameMatchesPreviewSource(frame, expectedSrc)) return false;
  resizePreviewFrame(preview, frame);
  bindPreviewAutoResize(preview, frame);
  markPreviewLoaded(preview);
  return true;
}

function schedulePreviewSync(preview, frame, expectedSrc, detailsNode, token, attempt) {
  if (syncPreviewLoadState(preview, frame, expectedSrc, detailsNode, token)) return;
  if (!isPreviewRequestCurrent(preview, frame, expectedSrc, token, detailsNode)) return;
  if (attempt >= 30) {
    markPreviewError(preview);
    return;
  }
  const delay = attempt < 4 ? 100 : 350;
  window.setTimeout(
    () => schedulePreviewSync(preview, frame, expectedSrc, detailsNode, token, attempt + 1),
    delay,
  );
}

function unloadPreview(detailsNode) {
  if (!detailsNode || !detailsNode.matches || !detailsNode.matches('.tree-file-detail')) return;
  const preview = detailsNode.querySelector('[data-preview-src]');
  if (!preview) return;
  const frame = preview.querySelector('iframe');
  if (!frame) return;

  nextPreviewToken(preview);
  frame.removeAttribute('data-preview-active-src');
  frame.src = 'about:blank';
  resetPreviewFrameHeight(preview, frame);
  resetPreviewState(preview);
}

function closeOtherFilePreviews(activeDetailsNode) {
  if (!activeDetailsNode || !activeDetailsNode.matches || !activeDetailsNode.matches('.tree-file-detail')) return;
  document.querySelectorAll('.tree-file-detail[open]').forEach((detailsNode) => {
    if (detailsNode === activeDetailsNode) return;
    detailsNode.open = false;
    unloadPreview(detailsNode);
  });
}

function syncTreeFilePreview(detailsNode) {
  if (!detailsNode || !detailsNode.matches || !detailsNode.matches('.tree-file-detail')) return;
  window.requestAnimationFrame(() => {
    if (detailsNode.open) {
      loadPreview(detailsNode);
    } else {
      unloadPreview(detailsNode);
    }
  });
}

function syncOpenPreviewsWithin(node) {
  if (!node || !node.querySelectorAll) return;
  node.querySelectorAll('.tree-file-detail[open]').forEach(syncTreeFilePreview);
}

function unloadPreviewsWithin(node) {
  if (!node || !node.querySelectorAll) return;
  node.querySelectorAll('.tree-file-detail').forEach(unloadPreview);
}

function loadPreview(detailsNode) {
  if (!detailsNode || !detailsNode.matches || !detailsNode.matches('.tree-file-detail')) return;
  const preview = detailsNode.querySelector('[data-preview-src]');
  if (!preview) return;
  const frame = preview.querySelector('iframe');
  if (!frame) return;
  const previewSrc = preview.getAttribute('data-preview-src');
  if (!previewSrc) return;
  closeOtherFilePreviews(detailsNode);
  if (preview.getAttribute('data-preview-loaded') === 'true' && frameMatchesPreviewSource(frame, previewSrc)) {
    resizePreviewFrame(preview, frame);
    return;
  }

  if (preview.getAttribute('data-preview-loading') === 'true') {
    const activeToken = preview.getAttribute('data-preview-token') || '';
    schedulePreviewSync(preview, frame, previewSrc, detailsNode, activeToken, 0);
    return;
  }
  resetPreviewState(preview);
  resetPreviewFrameHeight(preview, frame);
  const token = nextPreviewToken(preview);
  preview.setAttribute('data-preview-loading', 'true');
  frame.setAttribute('data-preview-active-src', previewSrc);

  frame.addEventListener('load', () => {
    syncPreviewLoadState(preview, frame, previewSrc, detailsNode, token);
  }, { once: true });

  frame.addEventListener('error', () => {
    if (!isPreviewRequestCurrent(preview, frame, previewSrc, token, detailsNode)) return;
    markPreviewError(preview);
  }, { once: true });

  if (frame.getAttribute('src') !== previewSrc) {
    frame.src = previewSrc;
  } else {
    syncPreviewLoadState(preview, frame, previewSrc, detailsNode, token);
  }

  schedulePreviewSync(preview, frame, previewSrc, detailsNode, token, 0);
}

function revealTarget(id) {
  const node = document.getElementById(id);
  if (!node) return;
  node.style.display = '';
  let parent = node;
  while (parent) {
    if (parent.tagName && parent.tagName.toLowerCase() === 'details') {
      parent.open = true;
      parent.style.display = '';
      syncTreeFilePreview(parent);
    }
    parent = parent.parentElement;
  }
  node.scrollIntoView({ behavior: 'smooth', block: 'start' });
}

document.querySelectorAll('[data-open-target]').forEach((link) => {
  link.addEventListener('click', (event) => {
    const target = link.getAttribute('data-open-target');
    if (!target) return;
    event.preventDefault();
    revealTarget(target);
    if (history.pushState) {
      history.pushState(null, '', '#' + target);
    } else {
      location.hash = target;
    }
  });
});

document.querySelectorAll('.tree-file-detail').forEach((detailsNode) => {
  detailsNode.addEventListener('toggle', () => syncTreeFilePreview(detailsNode));
});

document.querySelectorAll('.tree-folder').forEach((folder) => {
  folder.addEventListener('toggle', () => {
    window.requestAnimationFrame(() => {
      if (folder.open) {
        syncOpenPreviewsWithin(folder);
      } else {
        unloadPreviewsWithin(folder);
      }
    });
  });
});

window.addEventListener('load', () => {
  if (location.hash.length > 1) {
    revealTarget(decodeURIComponent(location.hash.substring(1)));
  }
});

document.querySelectorAll('[data-tree-action]').forEach((button) => {
  button.addEventListener('click', () => {
    const open = button.getAttribute('data-tree-action') === 'expand';
    document.querySelectorAll('.tree-folder').forEach((folder) => {
      folder.open = open;
      if (open) {
        syncOpenPreviewsWithin(folder);
      } else {
        unloadPreviewsWithin(folder);
      }
    });
  });
});

document.querySelectorAll('[data-summary-target]').forEach((button) => {
  button.addEventListener('click', () => {
    const targetId = button.getAttribute('data-summary-target');
    const target = targetId ? document.getElementById(targetId) : null;
    const shouldOpen = button.getAttribute('aria-expanded') !== 'true';

    document.querySelectorAll('[data-summary-target]').forEach((other) => {
      other.setAttribute('aria-expanded', 'false');
      const panelId = other.getAttribute('data-summary-target');
      const panel = panelId ? document.getElementById(panelId) : null;
      if (panel) {
        panel.hidden = true;
      }
    });

    if (target && shouldOpen) {
      button.setAttribute('aria-expanded', 'true');
      target.hidden = false;
    }
  });
});
</script>
''';
  }

  String _percent(double value) => '${value.toStringAsFixed(1)}%';

  String _tone(double value) {
    if (value >= 80) {
      return 'good';
    }
    if (value >= 60) {
      return 'warn';
    }
    return 'bad';
  }

  String _normalizePath(String path) => path.replaceAll('\\', '/');

  int _compareLineCoverageRisk(CoverageFile left, CoverageFile right) {
    final byCoverage = left.summary.lineCoveragePercent.compareTo(
      right.summary.lineCoveragePercent,
    );
    if (byCoverage != 0) {
      return byCoverage;
    }
    final byUncovered = right.summary.uncoveredLines.compareTo(
      left.summary.uncoveredLines,
    );
    return byUncovered == 0 ? left.path.compareTo(right.path) : byUncovered;
  }

  int _compareBranchCoverageRisk(CoverageFile left, CoverageFile right) {
    final leftCoverage = left.summary.branchCoveragePercent ?? 100;
    final rightCoverage = right.summary.branchCoveragePercent ?? 100;
    final byCoverage = leftCoverage.compareTo(rightCoverage);
    if (byCoverage != 0) {
      return byCoverage;
    }
    final leftMissing = left.summary.branchFound - left.summary.branchHit;
    final rightMissing = right.summary.branchFound - right.summary.branchHit;
    final byMissing = rightMissing.compareTo(leftMissing);
    return byMissing == 0 ? left.path.compareTo(right.path) : byMissing;
  }

  String _missingBranchLabel(int count) {
    return count == 1 ? '1 missing' : '$count missing';
  }

  String _basename(String filePath) {
    final path = _normalizePath(filePath);
    final separator = path.lastIndexOf('/');
    if (separator == -1) {
      return path;
    }
    return path.substring(separator + 1);
  }

  CoverageSummary _summaryForTreeDirectory(_CoverageTreeDirectory directory) {
    var executableLines = 0;
    var coveredLines = 0;
    var uncoveredLines = 0;
    var missingSourceFiles = 0;
    var filesBelowThreshold = 0;
    var branchFound = 0;
    var branchHit = 0;

    void addSummary(CoverageSummary summary) {
      executableLines += summary.executableLines;
      coveredLines += summary.coveredLines;
      uncoveredLines += summary.uncoveredLines;
      missingSourceFiles += summary.missingSourceFiles;
      filesBelowThreshold += summary.filesBelowThreshold;
      branchFound += summary.branchFound;
      branchHit += summary.branchHit;
    }

    for (final file in directory.files) {
      addSummary(file.summary);
    }
    for (final child in directory.directories.values) {
      addSummary(_summaryForTreeDirectory(child));
    }

    return CoverageSummary(
      executableLines: executableLines,
      coveredLines: coveredLines,
      uncoveredLines: uncoveredLines,
      missingSourceFiles: missingSourceFiles,
      filesBelowThreshold: filesBelowThreshold,
      branchFound: branchFound,
      branchHit: branchHit,
    );
  }

  int _fileCountForTreeDirectory(_CoverageTreeDirectory directory) {
    var count = directory.files.length;
    for (final child in directory.directories.values) {
      count += _fileCountForTreeDirectory(child);
    }
    return count;
  }

  int _excludedFileCountForTreeDirectory(_CoverageTreeDirectory directory) {
    var count = directory.excludedFiles.length;
    for (final child in directory.directories.values) {
      count += _excludedFileCountForTreeDirectory(child);
    }
    return count;
  }

  String _fileCountLabel(int count) => count == 1 ? '1 file' : '$count files';

  String _excludedCountLabel(int count) {
    if (count == 0) {
      return '';
    }
    final label = count == 1 ? '1 excluded' : '$count excluded';
    return '<span class="tree-count excluded">$label</span>';
  }

  List<CoverageLineStatus?> _inheritedVisualStatuses(List<CoverageLine> lines) {
    final inherited = List<CoverageLineStatus?>.filled(lines.length, null);
    var segmentStart = 0;

    while (segmentStart < lines.length) {
      while (segmentStart < lines.length &&
          lines[segmentStart].text.trim().isEmpty) {
        segmentStart += 1;
      }
      if (segmentStart >= lines.length) {
        break;
      }

      var segmentEnd = segmentStart;
      while (segmentEnd < lines.length &&
          lines[segmentEnd].text.trim().isNotEmpty) {
        segmentEnd += 1;
      }

      for (var index = segmentStart; index < segmentEnd; index += 1) {
        final line = lines[index];
        if (!_canInheritVisualStatus(line)) {
          continue;
        }
        inherited[index] = _nearestVisualStatus(
          lines,
          index,
          segmentStart,
          segmentEnd,
        );
      }

      segmentStart = segmentEnd;
    }

    return inherited;
  }

  CoverageLineStatus? _nearestVisualStatus(
    List<CoverageLine> lines,
    int index,
    int segmentStart,
    int segmentEnd,
  ) {
    CoverageLineStatus? previous;
    for (var cursor = index - 1; cursor >= segmentStart; cursor -= 1) {
      previous = _visualStatusForExecutableLine(lines[cursor]);
      if (previous != null) {
        break;
      }
    }

    CoverageLineStatus? next;
    for (var cursor = index + 1; cursor < segmentEnd; cursor += 1) {
      next = _visualStatusForExecutableLine(lines[cursor]);
      if (next != null) {
        break;
      }
    }

    return previous ?? next;
  }

  CoverageLineStatus? _visualStatusForExecutableLine(CoverageLine line) {
    return switch (line.status) {
      CoverageLineStatus.covered => CoverageLineStatus.covered,
      CoverageLineStatus.uncovered => CoverageLineStatus.uncovered,
      CoverageLineStatus.nonExecutable ||
      CoverageLineStatus.ignored ||
      CoverageLineStatus.missingSource =>
        null,
    };
  }

  bool _canInheritVisualStatus(CoverageLine line) {
    if (line.status != CoverageLineStatus.nonExecutable) {
      return false;
    }
    final trimmed = line.text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    return !trimmed.startsWith('import ') &&
        !trimmed.startsWith('export ') &&
        !trimmed.startsWith('library ') &&
        !trimmed.startsWith('part ') &&
        !trimmed.startsWith('//') &&
        !trimmed.startsWith('/*') &&
        !trimmed.startsWith('*') &&
        !trimmed.startsWith('*/');
  }

  String _lineCssClasses(
    CoverageLine line,
    CoverageLineStatus? inheritedStatus,
  ) {
    final classes = <String>[line.status.name];
    if (line.branchFound > 0 && line.branchHit < line.branchFound) {
      classes.add('branchMissing');
    }
    if (inheritedStatus == CoverageLineStatus.covered) {
      classes.add('inferredCovered');
    } else if (inheritedStatus == CoverageLineStatus.uncovered) {
      classes.add('inferredUncovered');
    }
    return classes.join(' ');
  }

  String _lineInfo(CoverageLine line, CoverageLineStatus? inheritedStatus) {
    final items = [
      '<span>Status: ${_lineStatusLabel(line)}</span>',
      '<span>Hits: ${_lineHitDetail(line)}</span>',
    ];
    if (inheritedStatus != null) {
      items.add(
        '<span>Block: ${_lineStatusLabelForStatus(inheritedStatus)}</span>',
      );
    }
    if (line.branchFound > 0) {
      items.add(
        '<span>Branches: ${line.branchHit} / ${line.branchFound}</span>',
      );
      final missingBranches = line.branchFound - line.branchHit;
      if (missingBranches > 0) {
        items.add('<span>Missing branches: $missingBranches</span>');
      }
    }
    return items.join();
  }

  String _branchLabel(CoverageLine line) {
    if (line.branchFound == 0) {
      return '';
    }
    return 'B ${line.branchHit}/${line.branchFound}';
  }

  String _hitLabel(CoverageLine line) {
    if (line.status == CoverageLineStatus.nonExecutable) {
      return '-';
    }
    if (line.status == CoverageLineStatus.ignored) {
      return 'skip';
    }
    if (line.status == CoverageLineStatus.missingSource) {
      return 'miss';
    }
    return line.hitCount.toString();
  }

  String _lineStatusLabelForStatus(CoverageLineStatus status) {
    return switch (status) {
      CoverageLineStatus.covered => 'covered',
      CoverageLineStatus.uncovered => 'uncovered',
      CoverageLineStatus.nonExecutable => 'not executable',
      CoverageLineStatus.ignored => 'ignored',
      CoverageLineStatus.missingSource => 'missing source',
    };
  }

  String _lineStatusLabel(CoverageLine line) {
    return _lineStatusLabelForStatus(line.status);
  }

  String _lineHitDetail(CoverageLine line) {
    if (line.status == CoverageLineStatus.nonExecutable) {
      return 'none';
    }
    if (line.status == CoverageLineStatus.ignored) {
      return 'ignored';
    }
    if (line.status == CoverageLineStatus.missingSource) {
      return 'unknown';
    }
    return line.hitCount.toString();
  }

  double _medianFileCoverage(List<CoverageFile> files) {
    final values = files
        .where((file) => file.summary.executableLines > 0)
        .map((file) => file.summary.lineCoveragePercent)
        .toList()
      ..sort();
    if (values.isEmpty) {
      return 0;
    }
    final middle = values.length ~/ 2;
    if (values.length.isOdd) {
      return values[middle];
    }
    return (values[middle - 1] + values[middle]) / 2;
  }

  String _formatGeneratedAt(DateTime value) {
    final utc = value.toUtc();
    return '${_monthName(utc.month)} ${utc.day}, ${utc.year}, ${_twoDigits(utc.hour)}:${_twoDigits(utc.minute)} UTC';
  }

  String _monthName(int month) {
    return const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][month - 1];
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _previewPath(CoverageFile file) => 'files/${_id(file.path)}.html';

  String _id(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
  }

  String _escape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

class _CoverageTreeDirectory {
  _CoverageTreeDirectory({required this.name, required this.path});

  final String name;
  final String path;
  final Map<String, _CoverageTreeDirectory> directories = {};
  final List<CoverageFile> files = [];
  final List<CoverageExcludedFile> excludedFiles = [];
}
