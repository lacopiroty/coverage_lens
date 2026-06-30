/// Coverage state assigned to a source line in a rendered report.
enum CoverageLineStatus {
  /// LCOV marked the line as executable and it ran at least once.
  covered,

  /// LCOV marked the line as executable and it did not run.
  uncovered,

  /// The source line exists, but LCOV did not mark it as executable.
  nonExecutable,

  /// The line is excluded by a `coverage:ignore-*` directive.
  ignored,

  /// LCOV references the line, but the source file could not be read.
  missingSource,
}

/// Complete analyzed coverage report used by HTML and PDF renderers.
class CoverageReport {
  /// Creates an immutable report model.
  const CoverageReport({
    required this.generatedAt,
    required this.summary,
    required this.files,
    required this.groups,
    required this.hotspots,
    required this.warnings,
    this.excludedFiles = const [],
  });

  /// UTC timestamp used by generated report outputs.
  final DateTime generatedAt;

  /// Aggregate coverage values across every included file.
  final CoverageSummary summary;

  /// Included files sorted by path.
  final List<CoverageFile> files;

  /// Directory-level summaries derived from [files].
  final List<CoverageGroup> groups;

  /// Files ordered by the analyzer's attention score.
  final List<CoverageFile> hotspots;

  /// Non-fatal issues discovered while analyzing input data.
  final List<String> warnings;

  /// Files matched by exclude patterns and removed from coverage totals.
  final List<CoverageExcludedFile> excludedFiles;
}

/// Aggregate line and branch coverage counters.
class CoverageSummary {
  /// Creates a summary from already aggregated counters.
  const CoverageSummary({
    required this.executableLines,
    required this.coveredLines,
    required this.uncoveredLines,
    required this.missingSourceFiles,
    required this.filesBelowThreshold,
    required this.branchFound,
    required this.branchHit,
  });

  /// Number of executable lines reported by LCOV.
  final int executableLines;

  /// Number of executable lines with at least one hit.
  final int coveredLines;

  /// Number of executable lines with zero hits.
  final int uncoveredLines;

  /// Number of LCOV files whose source text could not be loaded.
  final int missingSourceFiles;

  /// Number of files below the configured line coverage threshold.
  final int filesBelowThreshold;

  /// Number of branch outcomes reported by LCOV.
  final int branchFound;

  /// Number of branch outcomes that executed at least once.
  final int branchHit;

  /// Line coverage percentage, or `100` when there are no executable lines.
  double get lineCoveragePercent {
    if (executableLines == 0) {
      return 100;
    }
    return coveredLines * 100 / executableLines;
  }

  /// Branch coverage percentage, or `null` when LCOV has no branch data.
  double? get branchCoveragePercent {
    if (branchFound == 0) {
      return null;
    }
    return branchHit * 100 / branchFound;
  }
}

/// Coverage summary for one directory in the source tree.
class CoverageGroup {
  /// Creates a directory coverage group.
  const CoverageGroup({
    required this.name,
    required this.path,
    required this.summary,
  });

  /// Human-readable directory name.
  final String name;

  /// Directory path relative to the configured source root.
  final String path;

  /// Aggregated summary for files inside this group.
  final CoverageSummary summary;
}

/// Coverage analysis result for one source file.
class CoverageFile {
  /// Creates an analyzed file entry.
  const CoverageFile({
    required this.path,
    required this.summary,
    required this.lines,
    required this.uncoveredRanges,
    required this.hasMissingSource,
    required this.score,
    required this.isBelowThreshold,
  });

  /// File path as it appears in LCOV.
  final String path;

  /// Aggregate coverage counters for this file.
  final CoverageSummary summary;

  /// Source lines annotated with line and branch coverage data.
  final List<CoverageLine> lines;

  /// Consecutive uncovered executable line ranges.
  final List<CoverageRange> uncoveredRanges;

  /// Whether LCOV referenced this file but source text was unavailable.
  final bool hasMissingSource;

  /// Attention score used to sort files that may need review.
  final int score;

  /// Whether [summary] is below the configured line coverage threshold.
  final bool isBelowThreshold;
}

/// File skipped by an exclude pattern.
class CoverageExcludedFile {
  /// Creates an excluded file entry.
  const CoverageExcludedFile({required this.path, required this.reason});

  /// Excluded file path.
  final String path;

  /// Explanation of why the file was excluded.
  final String reason;
}

/// Coverage details for a single source line.
class CoverageLine {
  /// Creates an annotated source line.
  const CoverageLine({
    required this.number,
    required this.hitCount,
    required this.status,
    required this.text,
    this.branchFound = 0,
    this.branchHit = 0,
  });

  /// One-based source line number.
  final int number;

  /// LCOV execution count for this line.
  final int hitCount;

  /// Display status derived from LCOV and ignore directives.
  final CoverageLineStatus status;

  /// Source text for this line, or an empty string when missing.
  final String text;

  /// Number of branch outcomes mapped to this line.
  final int branchFound;

  /// Number of branch outcomes on this line that executed at least once.
  final int branchHit;
}

/// Inclusive range of uncovered executable source lines.
class CoverageRange {
  /// Creates an uncovered range from [start] to [end], inclusive.
  const CoverageRange({required this.start, required this.end});

  /// First one-based line number in the range.
  final int start;

  /// Last one-based line number in the range.
  final int end;

  /// Number of lines contained in the range.
  int get length => end - start + 1;

  /// Human-readable representation such as `7` or `10-14`.
  String get label => start == end ? '$start' : '$start-$end';
}
