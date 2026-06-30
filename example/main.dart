import 'dart:io';

import 'package:coverage_lens/coverage_lens.dart';

void main() {
  const lcov = '''
SF:lib/calculator.dart
DA:1,1
DA:2,0
BRDA:2,0,0,1
BRDA:2,0,1,0
LF:2
LH:1
BRF:2
BRH:1
end_of_record
''';

  final parsed = LcovParser().parse(lcov);
  final records = LcovRecordMerger().merge(parsed.files);
  final report = CoverageAnalyzer().analyze(
    records: records,
    sourceResolver: const InMemorySourceResolver({
      'lib/calculator.dart': '''
int add(int a, int b) => a + b;
int sign(int value) => value >= 0 ? 1 : -1;
''',
    }),
    config: const CoverageAnalysisConfig(
      lineWarningThreshold: 90,
      branchWarningThreshold: 80,
    ),
  );

  stdout.writeln(
    'Line coverage: '
    '${report.summary.lineCoveragePercent.toStringAsFixed(1)}%',
  );
  stdout.writeln(
    'Branch coverage: '
    '${report.summary.branchCoveragePercent?.toStringAsFixed(1)}%',
  );
  stdout
      .writeln('Files below threshold: ${report.summary.filesBelowThreshold}');
}
