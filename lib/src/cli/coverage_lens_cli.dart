import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../analysis/coverage_analyzer.dart';
import '../analysis/source_loader.dart';
import '../config/coverage_lens_config.dart';
import '../html/html_report_renderer.dart';
import '../lcov/lcov_parser.dart';
import '../model/coverage_models.dart';
import '../pdf/pdf_summary_renderer.dart';
import '../server/live_server.dart';

class CoverageLensCli {
  Future<int> run(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addCommand('report', _reportParser())
      ..addCommand('serve', _serveParser());

    ArgResults parsed;
    try {
      parsed = parser.parse(arguments);
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      stderr.writeln('Usage: dart run coverage_lens:coverage_lens report');
      return 64;
    }

    if (arguments.isEmpty || parsed['help'] == true) {
      stdout.writeln(
        'Usage: dart run coverage_lens:coverage_lens <report|serve>',
      );
      return 0;
    }

    final command = parsed.command;
    if (command == null) {
      stderr.writeln(
        'Unknown command: ${arguments.first}',
      );
      return 64;
    }

    switch (command.name) {
      case 'report':
        return _runReport(command);
      case 'serve':
        return _runServe(command);
      default:
        return _unknownCommand(command.name ?? arguments.first);
    }
  }

  ArgParser _reportParser() {
    return ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('config', defaultsTo: 'coverage_lens.yaml')
      ..addMultiOption('lcov')
      ..addOption('source')
      ..addOption('out')
      ..addFlag('summary-pdf', negatable: false)
      ..addOption('summary-pdf-out')
      ..addOption('summary-icon')
      ..addOption('project-name')
      ..addFlag('source-preview', defaultsTo: true)
      ..addOption('changed-from')
      ..addOption('changed-to')
      ..addOption('fail-under-lines')
      ..addOption('fail-under-branches')
      ..addMultiOption('include')
      ..addMultiOption('exclude');
  }

  ArgParser _serveParser() {
    return ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addOption('config', defaultsTo: 'coverage_lens.yaml')
      ..addMultiOption('lcov')
      ..addOption('source')
      ..addOption('host', defaultsTo: CoverageLensLiveServer.defaultHost)
      ..addOption('port', defaultsTo: '${CoverageLensLiveServer.defaultPort}')
      ..addFlag('source-preview', defaultsTo: true)
      ..addOption('changed-from')
      ..addOption('changed-to')
      ..addOption('fail-under-lines')
      ..addOption('fail-under-branches')
      ..addMultiOption('include')
      ..addMultiOption('exclude');
  }

  Future<int> _runReport(ArgResults command) async {
    if (command['help'] == true) {
      stdout.writeln('Usage: dart run coverage_lens:coverage_lens report');
      return 0;
    }

    final prepared = await _prepareReport(command);
    if (prepared.exitCode != null) {
      return prepared.exitCode!;
    }

    final config = prepared.config!;
    final report = prepared.report!;
    final htmlReport = prepared.htmlReport!;

    final outputDir = Directory(config.outputDir)..createSync(recursive: true);
    _clearManagedOutput(outputDir);
    File(p.join(outputDir.path, 'index.html')).writeAsStringSync(
      htmlReport.indexHtml,
    );
    for (final entry in htmlReport.assets.entries) {
      final file = File(p.join(outputDir.path, entry.key));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
    }
    stdout.writeln('Coverage report written to ${outputDir.path}/index.html');
    final pdfExitCode = _writeSummaryPdfIfRequested(
      command,
      outputDir: outputDir,
      config: config,
      report: report,
    );
    if (pdfExitCode != null) {
      return pdfExitCode;
    }

    if (report.summary.lineCoveragePercent < config.lineThreshold) {
      stderr.writeln(
        'Line coverage ${report.summary.lineCoveragePercent.toStringAsFixed(1)}% is below ${config.lineThreshold.toStringAsFixed(1)}%.',
      );
      return 2;
    }

    final branchCoverage = report.summary.branchCoveragePercent;
    if (branchCoverage != null && branchCoverage < config.branchThreshold) {
      stderr.writeln(
        'Branch coverage ${branchCoverage.toStringAsFixed(1)}% is below ${config.branchThreshold.toStringAsFixed(1)}%.',
      );
      return 2;
    }

    return 0;
  }

  int? _writeSummaryPdfIfRequested(
    ArgResults command, {
    required Directory outputDir,
    required CoverageLensConfig config,
    required CoverageReport report,
  }) {
    final requested = command['summary-pdf'] == true;
    final customPath = command['summary-pdf-out'] as String?;
    if (!requested && (customPath == null || customPath.isEmpty)) {
      return null;
    }

    final iconPath = command['summary-icon'] as String? ?? config.summaryIcon;
    final icon = _loadSummaryIcon(iconPath);
    if (iconPath != null && iconPath.isNotEmpty && icon == null) {
      return 66;
    }
    final file = customPath == null || customPath.isEmpty
        ? File(p.join(outputDir.path, 'summary.pdf'))
        : File(customPath);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(
      const PdfSummaryRenderer().render(
        report,
        options: PdfSummaryOptions(
          branch: _gitValue(config.sourceRoot, [
            'rev-parse',
            '--abbrev-ref',
            'HEAD',
          ]),
          commit: _gitValue(config.sourceRoot, [
            'rev-parse',
            '--short',
            'HEAD',
          ]),
          isDirty: _gitIsDirty(config.sourceRoot),
          lineThreshold: config.lineThreshold,
          branchThreshold: config.branchThreshold,
          icon: icon,
          projectName: _summaryProjectName(config),
        ),
      ),
    );
    stdout.writeln('Coverage summary PDF written to ${file.path}');
    return null;
  }

  Future<int> _runServe(ArgResults command) async {
    if (command['help'] == true) {
      stdout.writeln('Usage: dart run coverage_lens:coverage_lens serve');
      return 0;
    }

    final prepared = await _prepareReport(command);
    if (prepared.exitCode != null) {
      return prepared.exitCode!;
    }

    final port = int.tryParse(command['port'] as String? ?? '');
    if (port == null || port < 0 || port > 65535) {
      stderr.writeln('Invalid port: ${command['port']}');
      return 64;
    }

    final host =
        command['host'] as String? ?? CoverageLensLiveServer.defaultHost;
    final server = await CoverageLensLiveServer(
      prepared.htmlReport!,
    ).start(host: host, port: port);
    stdout.writeln(
      'Coverage Lens live report available at http://$host:${server.port}/',
    );
    stdout.writeln('Press Ctrl+C to stop.');

    final shutdown = Completer<int>();
    final subscriptions = <StreamSubscription<ProcessSignal>>[];

    Future<void> stop() async {
      if (shutdown.isCompleted) {
        return;
      }
      await server.close(force: true);
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
      shutdown.complete(0);
    }

    try {
      subscriptions.add(ProcessSignal.sigint.watch().listen((_) => stop()));
      subscriptions.add(ProcessSignal.sigterm.watch().listen((_) => stop()));
    } on UnsupportedError {
      // The open server keeps the process alive on platforms without signals.
    }

    return shutdown.future;
  }

  Future<_PreparedCoverageReport> _prepareReport(ArgResults command) async {
    CoverageLensConfig config;
    try {
      config = CoverageLensConfig.loadFromFile(command['config'] as String);
    } on FormatException catch (error) {
      stderr.writeln('Invalid config: ${error.message}');
      return const _PreparedCoverageReport(exitCode: 64);
    }

    final cliLcovPaths = command['lcov'] as List<String>;
    config = config.copyWith(
      lcovPaths: cliLcovPaths.isEmpty ? config.lcovPaths : cliLcovPaths,
      sourceRoot: command['source'] as String? ?? config.sourceRoot,
      outputDir: command.options.contains('out')
          ? command['out'] as String? ?? config.outputDir
          : config.outputDir,
      projectName: command.options.contains('project-name')
          ? command['project-name'] as String? ?? config.projectName
          : config.projectName,
      sourcePreview: command.wasParsed('source-preview')
          ? command['source-preview'] as bool
          : config.sourcePreview,
      changedFrom: command.wasParsed('changed-from')
          ? command['changed-from'] as String?
          : config.changedFrom,
      changedTo: command.wasParsed('changed-to')
          ? command['changed-to'] as String?
          : config.changedTo,
      lineThreshold:
          _doubleOption(command['fail-under-lines']) ?? config.lineThreshold,
      branchThreshold: _doubleOption(command['fail-under-branches']) ??
          config.branchThreshold,
      includes: (command['include'] as List<String>).isEmpty
          ? config.includes
          : command['include'] as List<String>,
      excludes: [
        ...config.excludes,
        ...command['exclude'] as List<String>,
      ],
    );

    final sourceRoot = Directory(config.sourceRoot);
    if (!sourceRoot.existsSync()) {
      stderr.writeln('Source root not found: ${config.sourceRoot}');
      return const _PreparedCoverageReport(exitCode: 66);
    }
    if (_hasValue(config.changedTo) && !_hasValue(config.changedFrom)) {
      stderr.writeln('changed-to requires changed-from.');
      return const _PreparedCoverageReport(exitCode: 64);
    }

    final lcovFiles = _resolveLcovFiles(config.effectiveLcovPaths);
    if (lcovFiles == null) {
      return const _PreparedCoverageReport(exitCode: 66);
    }

    final parser = LcovParser();
    final records = <LcovFileRecord>[];
    for (final lcovFile in lcovFiles) {
      final parseResult = parser.parse(lcovFile.readAsStringSync());
      records.addAll(
        _rebaseRecords(
          parseResult.files,
          lcovFile: lcovFile,
          sourceRoot: sourceRoot,
        ),
      );
    }
    if (records.isEmpty) {
      stderr.writeln(
        'No usable LCOV records found in ${lcovFiles.map((file) => file.path).join(', ')}',
      );
      return const _PreparedCoverageReport(exitCode: 66);
    }
    final mergedRecords = LcovRecordMerger().merge(records);
    final changedFilesResult = _resolveChangedFiles(config);
    if (changedFilesResult.exitCode != null) {
      return _PreparedCoverageReport(exitCode: changedFilesResult.exitCode);
    }
    final changedFiles = changedFilesResult.files;
    final recordsForAnalysis = changedFiles == null
        ? mergedRecords
        : mergedRecords
            .where(
                (record) => changedFiles.contains(_toPosix(record.sourceFile)))
            .toList();

    var report = CoverageAnalyzer().analyze(
      records: recordsForAnalysis,
      sourceResolver: FileSystemSourceResolver(sourceRoot: config.sourceRoot),
      config: CoverageAnalysisConfig(
        lineWarningThreshold: config.lineThreshold,
        branchWarningThreshold: config.branchThreshold,
        includes: config.includes,
        excludes: config.excludes,
      ),
    );
    if (changedFiles != null && recordsForAnalysis.isEmpty) {
      report = _copyReportWithWarnings(report, [
        'No LCOV records matched changed files from ${config.changedFrom} to ${_changedTo(config)}.',
      ]);
    }

    final htmlReport = HtmlReportRenderer().renderReport(
      report,
      options: HtmlReportRenderOptions(
        includeSourcePreviews: config.sourcePreview,
      ),
    );
    return _PreparedCoverageReport(
      config: config,
      report: report,
      htmlReport: htmlReport,
    );
  }

  List<File>? _resolveLcovFiles(List<String> paths) {
    final filesByPath = <String, File>{};
    for (final path in paths) {
      final matches = _expandLcovPath(path);
      if (matches.isEmpty && !_hasGlob(path)) {
        stderr.writeln('LCOV file not found: $path');
        return null;
      }
      for (final file in matches) {
        filesByPath.putIfAbsent(p.normalize(file.path), () => file);
      }
    }
    if (filesByPath.isEmpty) {
      stderr.writeln('LCOV file not found: ${paths.join(', ')}');
      return null;
    }
    return List.unmodifiable(filesByPath.values);
  }

  _ChangedFilesResult _resolveChangedFiles(CoverageLensConfig config) {
    if (!_hasValue(config.changedFrom)) {
      return const _ChangedFilesResult();
    }
    final from = config.changedFrom!;
    final to = _changedTo(config);
    final result = Process.runSync(
      'git',
      ['diff', '--name-only', '--relative', '$from...$to'],
      workingDirectory: config.sourceRoot,
    );
    if (result.exitCode != 0) {
      stderr.writeln(
        'Unable to resolve changed files from $from to $to: ${result.stderr}',
      );
      return const _ChangedFilesResult(exitCode: 66);
    }
    final files = const LineSplitter()
        .convert(result.stdout.toString())
        .map((line) => _toPosix(p.normalize(line.trim())))
        .where((line) => line.isNotEmpty)
        .toSet();
    return _ChangedFilesResult(files: files);
  }

  String _changedTo(CoverageLensConfig config) =>
      _hasValue(config.changedTo) ? config.changedTo! : 'HEAD';

  bool _hasValue(String? value) => value != null && value.trim().isNotEmpty;

  List<File> _expandLcovPath(String path) {
    if (!_hasGlob(path)) {
      final file = File(path);
      return file.existsSync() ? [file] : const [];
    }

    final root = _globRoot(path);
    final rootDirectory = Directory(root);
    if (!rootDirectory.existsSync()) {
      return const [];
    }

    final normalizedPattern = _toPosix(
      p.isAbsolute(path) ? p.normalize(path) : p.normalize(path),
    );
    final matches =
        rootDirectory.listSync(recursive: true).whereType<File>().where((file) {
      final candidate = _toPosix(
        p.isAbsolute(path)
            ? p.normalize(file.absolute.path)
            : p.normalize(p.relative(file.path)),
      );
      return _globMatches(normalizedPattern, candidate);
    }).toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    return List.unmodifiable(matches);
  }

  bool _hasGlob(String path) => path.contains('*') || path.contains('?');

  String _globRoot(String pattern) {
    final normalized = _toPosix(pattern);
    final segments = normalized.split('/');
    final rootSegments = <String>[];
    for (final segment in segments) {
      if (_hasGlob(segment)) {
        break;
      }
      rootSegments.add(segment);
    }
    if (rootSegments.isEmpty) {
      return '.';
    }
    return rootSegments.join('/');
  }

  bool _globMatches(String pattern, String path) {
    final buffer = StringBuffer('^');
    for (var index = 0; index < pattern.length; index += 1) {
      final char = pattern[index];
      if (char == '*') {
        if (index + 1 < pattern.length && pattern[index + 1] == '*') {
          buffer.write('.*');
          index += 1;
        } else {
          buffer.write('[^/]*');
        }
      } else if (char == '?') {
        buffer.write('[^/]');
      } else {
        buffer.write(RegExp.escape(char));
      }
    }
    buffer.write(r'$');
    return RegExp(buffer.toString()).hasMatch(path);
  }

  List<LcovFileRecord> _rebaseRecords(
    List<LcovFileRecord> records, {
    required File lcovFile,
    required Directory sourceRoot,
  }) {
    return records
        .map(
          (record) => _copyRecordWithSourceFile(
            record,
            _rebaseSourceFile(
              record.sourceFile,
              lcovFile: lcovFile,
              sourceRoot: sourceRoot,
            ),
          ),
        )
        .toList();
  }

  String _rebaseSourceFile(
    String sourceFile, {
    required File lcovFile,
    required Directory sourceRoot,
  }) {
    final sourceRootPath = p.normalize(sourceRoot.absolute.path);
    final normalizedSourceFile = _toPosix(sourceFile);
    if (p.isAbsolute(sourceFile)) {
      final absoluteSourceFile = p.normalize(sourceFile);
      return _isWithinOrEqual(sourceRootPath, absoluteSourceFile)
          ? _toPosix(p.relative(absoluteSourceFile, from: sourceRootPath))
          : _toPosix(absoluteSourceFile);
    }

    final directSourceFile =
        p.normalize(p.join(sourceRootPath, normalizedSourceFile));
    if (File(directSourceFile).existsSync()) {
      return _toPosix(p.normalize(normalizedSourceFile));
    }

    final packageRootPath = _packageRootForLcovFile(lcovFile);
    final packageSourceFile =
        p.normalize(p.join(packageRootPath, normalizedSourceFile));
    if (_isWithinOrEqual(sourceRootPath, packageSourceFile)) {
      return _toPosix(p.relative(packageSourceFile, from: sourceRootPath));
    }

    return normalizedSourceFile;
  }

  String _packageRootForLcovFile(File lcovFile) {
    final coverageDirectory = lcovFile.absolute.parent;
    final packageRoot = p.basename(coverageDirectory.path) == 'coverage'
        ? coverageDirectory.parent
        : coverageDirectory;
    return p.normalize(packageRoot.path);
  }

  LcovFileRecord _copyRecordWithSourceFile(
    LcovFileRecord record,
    String sourceFile,
  ) {
    return LcovFileRecord(
      sourceFile: sourceFile,
      lines: record.lines,
      functions: record.functions,
      branches: record.branches,
      lineFound: record.lineFound,
      lineHit: record.lineHit,
      functionFound: record.functionFound,
      functionHit: record.functionHit,
      branchFound: record.branchFound,
      branchHit: record.branchHit,
    );
  }

  bool _isWithinOrEqual(String parent, String child) {
    final normalizedParent = p.normalize(parent);
    final normalizedChild = p.normalize(child);
    return normalizedParent == normalizedChild ||
        p.isWithin(normalizedParent, normalizedChild);
  }

  String _toPosix(String path) => path.replaceAll('\\', '/');

  CoverageReport _copyReportWithWarnings(
    CoverageReport report,
    List<String> warnings,
  ) {
    return CoverageReport(
      generatedAt: report.generatedAt,
      summary: report.summary,
      files: report.files,
      groups: report.groups,
      hotspots: report.hotspots,
      warnings: List.unmodifiable([...report.warnings, ...warnings]),
      excludedFiles: report.excludedFiles,
    );
  }

  void _clearManagedOutput(Directory outputDir) {
    for (final child in ['assets', 'files']) {
      final directory = Directory(p.join(outputDir.path, child));
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    }
  }

  double? _doubleOption(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is! String || value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  int _unknownCommand(String command) {
    stderr.writeln('Unknown command: $command');
    return 64;
  }

  PdfSummaryIcon? _loadSummaryIcon(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('Summary icon not found: $path');
      return null;
    }
    image.Image? decoded;
    try {
      decoded = image.decodeImage(file.readAsBytesSync());
    } on image.ImageException {
      decoded = null;
    }
    if (decoded == null) {
      stderr.writeln('Summary icon must be a supported image file: $path');
      return null;
    }

    const maxSize = 96;
    final largestSide =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final ratio = largestSide == 0 ? 1.0 : maxSize / largestSide;
    final resized = ratio < 1
        ? image.copyResize(
            decoded,
            width: (decoded.width * ratio).round(),
            height: (decoded.height * ratio).round(),
            interpolation: image.Interpolation.average,
          )
        : decoded;
    final rgb = <int>[];
    for (var y = 0; y < resized.height; y += 1) {
      for (var x = 0; x < resized.width; x += 1) {
        final pixel = resized.getPixel(x, y);
        final alpha = pixel.aNormalized;
        rgb
          ..add(_blendOnWhite(pixel.rNormalized, alpha))
          ..add(_blendOnWhite(pixel.gNormalized, alpha))
          ..add(_blendOnWhite(pixel.bNormalized, alpha));
      }
    }
    return PdfSummaryIcon(
      width: resized.width,
      height: resized.height,
      rgbBytes: List.unmodifiable(rgb),
    );
  }

  int _blendOnWhite(num channel, num alpha) {
    final blended = 1 - (1 - channel) * alpha;
    return (blended * 255).round().clamp(0, 255).toInt();
  }

  String? _summaryProjectName(CoverageLensConfig config) {
    final configured = config.projectName;
    if (configured != null && configured.trim().isNotEmpty) {
      return configured.trim();
    }
    final pubspec = File(p.join(config.sourceRoot, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return null;
    }
    try {
      final yaml = loadYaml(pubspec.readAsStringSync());
      if (yaml is! YamlMap || yaml['name'] is! String) {
        return null;
      }
      return _displayProjectName(yaml['name'] as String);
    } on FormatException {
      return null;
    }
  }

  String _displayProjectName(String packageName) {
    return packageName
        .split(RegExp(r'[_\-\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  static String? _gitValue(String sourceRoot, List<String> arguments) {
    try {
      final result = Process.runSync(
        'git',
        ['-C', Directory(sourceRoot).absolute.path, ...arguments],
        stdoutEncoding: systemEncoding,
        stderrEncoding: systemEncoding,
      );
      if (result.exitCode != 0) {
        return null;
      }
      final value = (result.stdout as String).trim();
      return value.isEmpty ? null : value;
    } on ProcessException {
      return null;
    }
  }

  static bool? _gitIsDirty(String sourceRoot) {
    try {
      final result = Process.runSync(
        'git',
        ['-C', Directory(sourceRoot).absolute.path, 'diff', '--quiet'],
        stdoutEncoding: systemEncoding,
        stderrEncoding: systemEncoding,
      );
      if (result.exitCode == 0) {
        return false;
      }
      if (result.exitCode == 1) {
        return true;
      }
      return null;
    } on ProcessException {
      return null;
    }
  }
}

class _PreparedCoverageReport {
  const _PreparedCoverageReport({
    this.exitCode,
    this.config,
    this.report,
    this.htmlReport,
  });

  final int? exitCode;
  final CoverageLensConfig? config;
  final CoverageReport? report;
  final HtmlReportOutput? htmlReport;
}

class _ChangedFilesResult {
  const _ChangedFilesResult({this.files, this.exitCode});

  final Set<String>? files;
  final int? exitCode;
}
