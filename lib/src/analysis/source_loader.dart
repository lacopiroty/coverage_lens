import 'dart:io';

import 'package:path/path.dart' as p;

import 'coverage_analyzer.dart';

/// Source resolver that reads files from the local file system.
class FileSystemSourceResolver implements SourceResolver {
  /// Creates a resolver rooted at [sourceRoot].
  const FileSystemSourceResolver({required this.sourceRoot});

  /// Directory used to resolve relative LCOV source paths.
  final String sourceRoot;

  @override
  String? readSource(String path) {
    final resolvedPath = p.isAbsolute(path) ? path : p.join(sourceRoot, path);
    final file = File(resolvedPath);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsStringSync();
  }
}

/// Line ignore information parsed from Dart coverage comments.
class SourceIgnoreMap {
  /// Creates an ignore map.
  const SourceIgnoreMap(this.ignoredLines, {required this.ignoreFile});

  /// One-based source line numbers excluded from coverage.
  final Set<int> ignoredLines;

  /// Whether the whole source file should be excluded.
  final bool ignoreFile;

  /// Returns whether [lineNumber] should be excluded from coverage.
  bool ignores(int lineNumber) =>
      ignoreFile || ignoredLines.contains(lineNumber);

  /// Parses `coverage:ignore-*` directives from [source].
  static SourceIgnoreMap fromSource(String? source) {
    if (source == null) {
      return const SourceIgnoreMap({}, ignoreFile: false);
    }

    final lines = source.split('\n');
    final ignored = <int>{};
    var ignoringBlock = false;
    var ignoreFile = false;

    for (var index = 0; index < lines.length; index += 1) {
      final lineNumber = index + 1;
      final line = lines[index];
      if (line.contains('coverage:ignore-file')) {
        ignoreFile = true;
      }
      if (line.contains('coverage:ignore-start')) {
        ignoringBlock = true;
        ignored.add(lineNumber);
        continue;
      }
      if (ignoringBlock) {
        ignored.add(lineNumber);
      }
      if (line.contains('coverage:ignore-end')) {
        ignoringBlock = false;
        ignored.add(lineNumber);
      }
    }

    return SourceIgnoreMap(ignored, ignoreFile: ignoreFile);
  }
}
