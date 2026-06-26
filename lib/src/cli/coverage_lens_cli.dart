import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import '../analysis/coverage_analyzer.dart';
import '../analysis/source_loader.dart';
import '../config/coverage_lens_config.dart';
import '../html/html_report_renderer.dart';
import '../lcov/lcov_parser.dart';

class CoverageLensCli {
  Future<int> run(List<String> arguments) async {
    final parser = ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addCommand('report', _reportParser());

    ArgResults parsed;
    try {
      parsed = parser.parse(arguments);
    } on FormatException catch (error) {
      stderr.writeln(error.message);
      stderr.writeln('Usage: dart run coverage_lens:coverage_lens report');
      return 64;
    }

    if (arguments.isEmpty || parsed['help'] == true) {
      stdout.writeln('Usage: dart run coverage_lens:coverage_lens report');
      return 0;
    }

    if (parsed.command?.name != 'report') {
      stderr.writeln(
          'Unknown command: ${parsed.command?.name ?? arguments.first}');
      return 64;
    }

    return _runReport(parsed.command!);
  }

  ArgParser _reportParser() {
    return ArgParser()
      ..addOption('config', defaultsTo: 'coverage_lens.yaml')
      ..addOption('lcov')
      ..addOption('source')
      ..addOption('out')
      ..addOption('fail-under-lines')
      ..addOption('fail-under-branches')
      ..addMultiOption('include')
      ..addMultiOption('exclude');
  }

  Future<int> _runReport(ArgResults command) async {
    CoverageLensConfig config;
    try {
      config = CoverageLensConfig.loadFromFile(command['config'] as String);
    } on FormatException catch (error) {
      stderr.writeln('Invalid config: ${error.message}');
      return 64;
    }

    config = config.copyWith(
      lcovPath: command['lcov'] as String? ?? config.lcovPath,
      sourceRoot: command['source'] as String? ?? config.sourceRoot,
      outputDir: command['out'] as String? ?? config.outputDir,
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

    final lcovFile = File(config.lcovPath);
    if (!lcovFile.existsSync()) {
      stderr.writeln('LCOV file not found: ${config.lcovPath}');
      return 66;
    }

    final sourceRoot = Directory(config.sourceRoot);
    if (!sourceRoot.existsSync()) {
      stderr.writeln('Source root not found: ${config.sourceRoot}');
      return 66;
    }

    final parseResult = LcovParser().parse(lcovFile.readAsStringSync());
    if (parseResult.files.isEmpty) {
      stderr.writeln('No usable LCOV records found in ${config.lcovPath}');
      return 66;
    }

    final report = CoverageAnalyzer().analyze(
      records: parseResult.files,
      sourceResolver: FileSystemSourceResolver(sourceRoot: config.sourceRoot),
      config: CoverageAnalysisConfig(
        lineWarningThreshold: config.lineThreshold,
        branchWarningThreshold: config.branchThreshold,
        includes: config.includes,
        excludes: config.excludes,
      ),
    );

    final outputDir = Directory(config.outputDir)..createSync(recursive: true);
    _clearManagedOutput(outputDir);
    final htmlReport = HtmlReportRenderer().renderReport(report);
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
}
