import 'package:path/path.dart' as p;

import '../lcov/lcov_parser.dart';
import '../model/coverage_models.dart';
import 'path_filter.dart';
import 'source_loader.dart';

abstract interface class SourceResolver {
  String? readSource(String path);
}

class InMemorySourceResolver implements SourceResolver {
  const InMemorySourceResolver(this.sources);

  final Map<String, String> sources;

  @override
  String? readSource(String path) => sources[path];
}

class CoverageAnalysisConfig {
  const CoverageAnalysisConfig({
    this.lineWarningThreshold = 80,
    this.branchWarningThreshold = 70,
    this.includes = const [],
    this.excludes = const [],
  });

  final double lineWarningThreshold;
  final double branchWarningThreshold;
  final List<String> includes;
  final List<String> excludes;
}

class CoverageAnalyzer {
  CoverageReport analyze({
    required List<LcovFileRecord> records,
    required SourceResolver sourceResolver,
    required CoverageAnalysisConfig config,
    DateTime? generatedAt,
  }) {
    final warnings = <String>[];
    final pathFilter = PathFilter(
      includes: config.includes,
      excludes: config.excludes,
    );
    final filteredRecords = <LcovFileRecord>[];
    final excludedFiles = <CoverageExcludedFile>[];
    for (final record in records) {
      if (!pathFilter.isIncluded(record.sourceFile)) {
        continue;
      }
      final exclusionPattern = pathFilter.exclusionPattern(record.sourceFile);
      if (exclusionPattern != null) {
        excludedFiles.add(
          CoverageExcludedFile(
            path: record.sourceFile,
            reason: 'Matched exclude pattern $exclusionPattern',
          ),
        );
        continue;
      }
      filteredRecords.add(record);
    }

    final files = filteredRecords.map((record) {
      final source = sourceResolver.readSource(record.sourceFile);
      if (source == null) {
        warnings.add('Missing source: ${record.sourceFile}');
      }
      return _analyzeFile(record, source, config);
    }).toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final summary = _summaryForFiles(files);
    final groups = _groupsForFiles(files);
    final hotspots = [...files]..sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        return byScore == 0 ? a.path.compareTo(b.path) : byScore;
      });

    return CoverageReport(
      generatedAt: generatedAt ?? DateTime.now().toUtc(),
      summary: summary,
      files: List.unmodifiable(files),
      groups: List.unmodifiable(groups),
      hotspots: List.unmodifiable(hotspots),
      warnings: List.unmodifiable(warnings),
      excludedFiles: List.unmodifiable(
        excludedFiles..sort((a, b) => a.path.compareTo(b.path)),
      ),
    );
  }

  CoverageFile _analyzeFile(
    LcovFileRecord record,
    String? source,
    CoverageAnalysisConfig config,
  ) {
    final ignoreMap = SourceIgnoreMap.fromSource(source);
    final effectiveLineRecords = record.lines
        .where((line) => !ignoreMap.ignores(line.lineNumber))
        .toList();
    final executable = effectiveLineRecords.length;
    final covered =
        effectiveLineRecords.where((line) => line.hitCount > 0).length;
    final uncovered = executable - covered;
    final hasMissingSource = source == null;
    final sourceLines = source?.split('\n') ?? const <String>[];
    final executableByLine = {
      for (final line in effectiveLineRecords) line.lineNumber: line.hitCount,
    };
    final branchesByLine = <int, List<LcovBranchRecord>>{};
    for (final branch in record.branches) {
      if (ignoreMap.ignores(branch.lineNumber)) {
        continue;
      }
      branchesByLine.putIfAbsent(branch.lineNumber, () => []).add(branch);
    }
    final maxLine = [
      ...executableByLine.keys,
      ...branchesByLine.keys,
      if (sourceLines.isNotEmpty) sourceLines.length,
    ].fold<int>(0, (max, value) => value > max ? value : max);

    final lines = <CoverageLine>[];
    for (var number = 1; number <= maxLine; number += 1) {
      final hitCount = executableByLine[number];
      final branches = branchesByLine[number] ?? const <LcovBranchRecord>[];
      final text = number <= sourceLines.length ? sourceLines[number - 1] : '';
      final status = ignoreMap.ignores(number)
          ? CoverageLineStatus.ignored
          : hitCount == null
              ? CoverageLineStatus.nonExecutable
              : hitCount > 0
                  ? CoverageLineStatus.covered
                  : CoverageLineStatus.uncovered;
      lines.add(
        CoverageLine(
          number: number,
          hitCount: hitCount ?? 0,
          status: hasMissingSource && hitCount != null
              ? CoverageLineStatus.missingSource
              : status,
          text: text,
          branchFound: branches.length,
          branchHit: branches.where((branch) => branch.hitCount > 0).length,
        ),
      );
    }

    final ranges = _uncoveredRanges(effectiveLineRecords);
    final largestRange = ranges.fold<int>(
      0,
      (largest, range) => range.length > largest ? range.length : largest,
    );
    final summary = CoverageSummary(
      executableLines: executable,
      coveredLines: covered,
      uncoveredLines: uncovered,
      missingSourceFiles: hasMissingSource ? 1 : 0,
      filesBelowThreshold: 0,
      branchFound: record.branchFound ?? record.branches.length,
      branchHit: record.branchHit ??
          record.branches.where((branch) => branch.hitCount > 0).length,
    );
    final isBelowThreshold =
        summary.lineCoveragePercent < config.lineWarningThreshold;
    final thresholdPenalty = isBelowThreshold ? 25 : 0;

    return CoverageFile(
      path: record.sourceFile,
      summary: summary,
      lines: List.unmodifiable(lines),
      uncoveredRanges: List.unmodifiable(ranges),
      hasMissingSource: hasMissingSource,
      score: uncovered * 2 + largestRange + thresholdPenalty,
      isBelowThreshold: isBelowThreshold,
    );
  }

  List<CoverageRange> _uncoveredRanges(List<LcovLineRecord> lines) {
    final uncoveredLines = lines
        .where((line) => line.hitCount == 0)
        .map((line) => line.lineNumber)
        .toList()
      ..sort();
    final ranges = <CoverageRange>[];
    int? start;
    int? previous;
    for (final line in uncoveredLines) {
      if (start == null) {
        start = line;
        previous = line;
        continue;
      }
      if (previous != null && line == previous + 1) {
        previous = line;
        continue;
      }
      ranges.add(CoverageRange(start: start, end: previous ?? start));
      start = line;
      previous = line;
    }
    if (start != null) {
      ranges.add(CoverageRange(start: start, end: previous ?? start));
    }
    return ranges;
  }

  CoverageSummary _summaryForFiles(List<CoverageFile> files) {
    final executable = files.fold<int>(
      0,
      (sum, file) => sum + file.summary.executableLines,
    );
    final covered = files.fold<int>(
      0,
      (sum, file) => sum + file.summary.coveredLines,
    );
    final missingSource = files.where((file) => file.hasMissingSource).length;
    final belowThreshold = files.where((file) => file.isBelowThreshold).length;
    final branchFound = files.fold<int>(
      0,
      (sum, file) => sum + file.summary.branchFound,
    );
    final branchHit = files.fold<int>(
      0,
      (sum, file) => sum + file.summary.branchHit,
    );
    return CoverageSummary(
      executableLines: executable,
      coveredLines: covered,
      uncoveredLines: executable - covered,
      missingSourceFiles: missingSource,
      filesBelowThreshold: belowThreshold,
      branchFound: branchFound,
      branchHit: branchHit,
    );
  }

  List<CoverageGroup> _groupsForFiles(List<CoverageFile> files) {
    final byDirectory = <String, List<CoverageFile>>{};
    for (final file in files) {
      final directory =
          p.dirname(file.path) == '.' ? '<root>' : p.dirname(file.path);
      byDirectory.putIfAbsent(directory, () => []).add(file);
    }
    return byDirectory.entries.map((entry) {
      final summary = _summaryForFiles(entry.value);
      return CoverageGroup(name: entry.key, path: entry.key, summary: summary);
    }).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
  }
}
