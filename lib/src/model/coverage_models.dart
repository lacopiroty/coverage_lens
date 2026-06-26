enum CoverageLineStatus {
  covered,
  uncovered,
  nonExecutable,
  ignored,
  missingSource,
}

class CoverageReport {
  const CoverageReport({
    required this.generatedAt,
    required this.summary,
    required this.files,
    required this.groups,
    required this.hotspots,
    required this.warnings,
    this.excludedFiles = const [],
  });

  final DateTime generatedAt;
  final CoverageSummary summary;
  final List<CoverageFile> files;
  final List<CoverageGroup> groups;
  final List<CoverageFile> hotspots;
  final List<String> warnings;
  final List<CoverageExcludedFile> excludedFiles;
}

class CoverageSummary {
  const CoverageSummary({
    required this.executableLines,
    required this.coveredLines,
    required this.uncoveredLines,
    required this.missingSourceFiles,
    required this.filesBelowThreshold,
    required this.branchFound,
    required this.branchHit,
  });

  final int executableLines;
  final int coveredLines;
  final int uncoveredLines;
  final int missingSourceFiles;
  final int filesBelowThreshold;
  final int branchFound;
  final int branchHit;

  double get lineCoveragePercent {
    if (executableLines == 0) {
      return 100;
    }
    return coveredLines * 100 / executableLines;
  }

  double? get branchCoveragePercent {
    if (branchFound == 0) {
      return null;
    }
    return branchHit * 100 / branchFound;
  }
}

class CoverageGroup {
  const CoverageGroup({
    required this.name,
    required this.path,
    required this.summary,
  });

  final String name;
  final String path;
  final CoverageSummary summary;
}

class CoverageFile {
  const CoverageFile({
    required this.path,
    required this.summary,
    required this.lines,
    required this.uncoveredRanges,
    required this.hasMissingSource,
    required this.score,
    required this.isBelowThreshold,
  });

  final String path;
  final CoverageSummary summary;
  final List<CoverageLine> lines;
  final List<CoverageRange> uncoveredRanges;
  final bool hasMissingSource;
  final int score;
  final bool isBelowThreshold;
}

class CoverageExcludedFile {
  const CoverageExcludedFile({required this.path, required this.reason});

  final String path;
  final String reason;
}

class CoverageLine {
  const CoverageLine({
    required this.number,
    required this.hitCount,
    required this.status,
    required this.text,
    this.branchFound = 0,
    this.branchHit = 0,
  });

  final int number;
  final int hitCount;
  final CoverageLineStatus status;
  final String text;
  final int branchFound;
  final int branchHit;
}

class CoverageRange {
  const CoverageRange({required this.start, required this.end});

  final int start;
  final int end;

  int get length => end - start + 1;

  String get label => start == end ? '$start' : '$start-$end';
}
