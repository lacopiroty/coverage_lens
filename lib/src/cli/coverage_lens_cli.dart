import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../analysis/coverage_analyzer.dart';
import '../analysis/source_loader.dart';
import '../config/coverage_lens_config.dart';
import '../html/html_report_renderer.dart';
import '../lcov/lcov_parser.dart';
import '../model/coverage_models.dart';
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

    final report = CoverageAnalyzer().analyze(
      records: mergedRecords,
      sourceResolver: FileSystemSourceResolver(sourceRoot: config.sourceRoot),
      config: CoverageAnalysisConfig(
        lineWarningThreshold: config.lineThreshold,
        branchWarningThreshold: config.branchThreshold,
        includes: config.includes,
        excludes: config.excludes,
      ),
    );

    final htmlReport = HtmlReportRenderer().renderReport(report);
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
