import 'dart:io';

import 'package:yaml/yaml.dart';

class CoverageLensConfig {
  const CoverageLensConfig({
    this.sourceRoot = '.',
    this.lcovPath = 'coverage/lcov.info',
    this.lcovPaths = const [],
    this.outputDir = 'build/coverage_lens',
    this.lineThreshold = 80,
    this.branchThreshold = 70,
    this.includes = const [],
    this.excludes = const [],
  });

  final String sourceRoot;
  final String lcovPath;
  final List<String> lcovPaths;
  final String outputDir;
  final double lineThreshold;
  final double branchThreshold;
  final List<String> includes;
  final List<String> excludes;

  List<String> get effectiveLcovPaths =>
      lcovPaths.isEmpty ? [lcovPath] : lcovPaths;

  CoverageLensConfig copyWith({
    String? sourceRoot,
    String? lcovPath,
    List<String>? lcovPaths,
    String? outputDir,
    double? lineThreshold,
    double? branchThreshold,
    List<String>? includes,
    List<String>? excludes,
  }) {
    return CoverageLensConfig(
      sourceRoot: sourceRoot ?? this.sourceRoot,
      lcovPath: lcovPath ?? this.lcovPath,
      lcovPaths: lcovPaths ?? this.lcovPaths,
      outputDir: outputDir ?? this.outputDir,
      lineThreshold: lineThreshold ?? this.lineThreshold,
      branchThreshold: branchThreshold ?? this.branchThreshold,
      includes: includes ?? this.includes,
      excludes: excludes ?? this.excludes,
    );
  }

  static CoverageLensConfig loadFromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      return const CoverageLensConfig();
    }
    final yaml = loadYaml(file.readAsStringSync());
    if (yaml is! YamlMap) {
      throw const FormatException('Config root must be a YAML map.');
    }

    final thresholds = yaml['thresholds'];
    final lineThreshold = thresholds is YamlMap && thresholds['line'] != null
        ? _number(thresholds['line'], 'thresholds.line')
        : 80.0;
    final branchThreshold =
        thresholds is YamlMap && thresholds['branch'] != null
            ? _number(thresholds['branch'], 'thresholds.branch')
            : 70.0;
    final lcovPaths = yaml.containsKey('lcovPaths')
        ? _stringList(yaml['lcovPaths'], 'lcovPaths')
        : const <String>[];

    return CoverageLensConfig(
      sourceRoot: _string(yaml['sourceRoot'], 'sourceRoot') ?? '.',
      lcovPath: _string(yaml['lcovPath'], 'lcovPath') ?? 'coverage/lcov.info',
      lcovPaths: lcovPaths,
      outputDir:
          _string(yaml['outputDir'], 'outputDir') ?? 'build/coverage_lens',
      lineThreshold: lineThreshold,
      branchThreshold: branchThreshold,
      includes: _stringList(yaml['include'], 'include'),
      excludes: _stringList(yaml['exclude'], 'exclude'),
    );
  }

  static String? _string(Object? value, String key) {
    if (value == null) {
      return null;
    }
    if (value is String) {
      return value;
    }
    throw FormatException('$key must be a string.');
  }

  static double _number(Object? value, String key) {
    if (value is num) {
      return value.toDouble();
    }
    throw FormatException('$key must be a number.');
  }

  static List<String> _stringList(Object? value, String key) {
    if (value == null) {
      return const [];
    }
    if (value is! YamlList) {
      throw FormatException('$key must be a list.');
    }
    return value.map((entry) {
      if (entry is String) {
        return entry;
      }
      throw FormatException('$key entries must be strings.');
    }).toList();
  }
}
