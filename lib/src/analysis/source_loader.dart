import 'dart:io';

import 'package:path/path.dart' as p;

import 'coverage_analyzer.dart';

class FileSystemSourceResolver implements SourceResolver {
  const FileSystemSourceResolver({required this.sourceRoot});

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

class SourceIgnoreMap {
  const SourceIgnoreMap(this.ignoredLines, {required this.ignoreFile});

  final Set<int> ignoredLines;
  final bool ignoreFile;

  bool ignores(int lineNumber) =>
      ignoreFile || ignoredLines.contains(lineNumber);

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
