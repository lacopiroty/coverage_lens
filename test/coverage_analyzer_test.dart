import 'package:coverage_lens/src/analysis/coverage_analyzer.dart';
import 'package:coverage_lens/src/analysis/source_loader.dart';
import 'package:coverage_lens/src/lcov/lcov_parser.dart';
import 'package:coverage_lens/src/model/coverage_models.dart';
import 'package:test/test.dart';

void main() {
  test('aggregates line coverage and uncovered ranges', () {
    final records = [
      const LcovFileRecord(
        sourceFile: 'lib/a.dart',
        lines: [
          LcovLineRecord(lineNumber: 1, hitCount: 1),
          LcovLineRecord(lineNumber: 2, hitCount: 0),
          LcovLineRecord(lineNumber: 3, hitCount: 0),
          LcovLineRecord(lineNumber: 7, hitCount: 0),
        ],
        functions: [],
        branches: [],
      ),
    ];

    final report = CoverageAnalyzer().analyze(
      records: records,
      sourceResolver: const InMemorySourceResolver({
        'lib/a.dart': 'void main() {}\nprint(1);\nprint(2);\n\n\n\nprint(7);\n',
      }),
      config: const CoverageAnalysisConfig(),
      generatedAt: DateTime.utc(2026, 6, 26),
    );

    expect(report.summary.executableLines, 4);
    expect(report.summary.coveredLines, 1);
    expect(report.summary.uncoveredLines, 3);
    expect(report.summary.lineCoveragePercent, 25);
    expect(report.files.single.uncoveredRanges.map((range) => range.label), [
      '2-3',
      '7',
    ]);
  });

  test('sorts hotspot files by score', () {
    final records = [
      const LcovFileRecord(
        sourceFile: 'lib/small.dart',
        lines: [LcovLineRecord(lineNumber: 1, hitCount: 0)],
        functions: [],
        branches: [],
      ),
      const LcovFileRecord(
        sourceFile: 'lib/big.dart',
        lines: [
          LcovLineRecord(lineNumber: 1, hitCount: 1),
          LcovLineRecord(lineNumber: 2, hitCount: 0),
          LcovLineRecord(lineNumber: 3, hitCount: 0),
          LcovLineRecord(lineNumber: 4, hitCount: 0),
        ],
        functions: [],
        branches: [],
      ),
    ];

    final report = CoverageAnalyzer().analyze(
      records: records,
      sourceResolver: const InMemorySourceResolver({}),
      config: const CoverageAnalysisConfig(lineWarningThreshold: 80),
      generatedAt: DateTime.utc(2026, 6, 26),
    );

    expect(report.hotspots.first.path, 'lib/big.dart');
    expect(
      report.hotspots.first.score,
      greaterThan(report.hotspots.last.score),
    );
  });

  test('maps branch coverage to source lines', () {
    final records = [
      const LcovFileRecord(
        sourceFile: 'lib/branchy.dart',
        lines: [
          LcovLineRecord(lineNumber: 1, hitCount: 1),
          LcovLineRecord(lineNumber: 2, hitCount: 1),
        ],
        functions: [],
        branches: [
          LcovBranchRecord(
            lineNumber: 2,
            blockNumber: 0,
            branchNumber: 0,
            hitCount: 3,
          ),
          LcovBranchRecord(
            lineNumber: 2,
            blockNumber: 0,
            branchNumber: 1,
            hitCount: 0,
          ),
        ],
      ),
    ];

    final report = CoverageAnalyzer().analyze(
      records: records,
      sourceResolver: const InMemorySourceResolver({
        'lib/branchy.dart': 'void main() {\nif (enabled) print(1);\n}',
      }),
      config: const CoverageAnalysisConfig(),
      generatedAt: DateTime.utc(2026, 6, 26),
    );

    final branchLine = report.files.single.lines[1];
    expect(branchLine.number, 2);
    expect(branchLine.branchFound, 2);
    expect(branchLine.branchHit, 1);
  });

  test('uses exact LCOV line numbers for branch markers', () {
    final records = [
      const LcovFileRecord(
        sourceFile: 'lib/app_switch_tile.dart',
        lines: [
          LcovLineRecord(lineNumber: 4, hitCount: 0),
          LcovLineRecord(lineNumber: 17, hitCount: 0),
          LcovLineRecord(lineNumber: 21, hitCount: 0),
          LcovLineRecord(lineNumber: 23, hitCount: 0),
          LcovLineRecord(lineNumber: 24, hitCount: 0),
        ],
        functions: [],
        branches: [
          LcovBranchRecord(
            lineNumber: 4,
            blockNumber: 0,
            branchNumber: 0,
            hitCount: 0,
          ),
          LcovBranchRecord(
            lineNumber: 17,
            blockNumber: 0,
            branchNumber: 0,
            hitCount: 0,
          ),
          LcovBranchRecord(
            lineNumber: 23,
            blockNumber: 0,
            branchNumber: 0,
            hitCount: 0,
          ),
          LcovBranchRecord(
            lineNumber: 24,
            blockNumber: 0,
            branchNumber: 0,
            hitCount: 0,
          ),
        ],
      ),
    ];

    final report = CoverageAnalyzer().analyze(
      records: records,
      sourceResolver: const InMemorySourceResolver({
        'lib/app_switch_tile.dart': '''
part of 'app_toggle_tiles.dart';

class AppSwitchTile extends StatelessWidget {
  const AppSwitchTile({
    super.key,
    required this.value,
    required this.title,
    this.subtitle,
    this.onChanged,
  });

  final bool value;
  final String title;
  final String? subtitle;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged == null
          ? null
          : (nextValue) {
              if (nextValue != value) {
                AppHaptics.trigger(AppHapticStyle.selection);
              }
              onChanged?.call(nextValue);
            },
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      contentPadding: EdgeInsets.zero,
    );
  }
}
''',
      }),
      config: const CoverageAnalysisConfig(),
      generatedAt: DateTime.utc(2026, 6, 26),
    );

    final linesByNumber = {
      for (final line in report.files.single.lines) line.number: line,
    };

    expect(linesByNumber[4]!.branchFound, 1);
    expect(linesByNumber[17]!.branchFound, 1);
    expect(linesByNumber[23]!.branchFound, 1);
    expect(linesByNumber[24]!.branchFound, 1);
    expect(report.files.single.summary.branchFound, 4);
    expect(report.files.single.summary.branchHit, 0);
  });

  test('uses exact LCOV line numbers for annotation line hits', () {
    final records = [
      const LcovFileRecord(
        sourceFile: 'lib/widget.dart',
        lines: [
          LcovLineRecord(lineNumber: 4, hitCount: 7),
          LcovLineRecord(lineNumber: 6, hitCount: 7),
        ],
        functions: [],
        branches: [],
      ),
    ];

    final report = CoverageAnalyzer().analyze(
      records: records,
      sourceResolver: const InMemorySourceResolver({
        'lib/widget.dart': '''
class ExampleWidget extends StatelessWidget {
  const ExampleWidget();

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
''',
      }),
      config: const CoverageAnalysisConfig(),
      generatedAt: DateTime.utc(2026, 6, 26),
    );

    final linesByNumber = {
      for (final line in report.files.single.lines) line.number: line,
    };

    expect(linesByNumber[4]!.status, CoverageLineStatus.covered);
    expect(linesByNumber[4]!.hitCount, 7);
    expect(linesByNumber[5]!.status, CoverageLineStatus.nonExecutable);
    expect(linesByNumber[5]!.hitCount, 0);
    expect(report.files.single.summary.executableLines, 2);
    expect(report.files.single.summary.coveredLines, 2);
  });

  test('loads source files and applies ignore markers', () {
    final records = [
      const LcovFileRecord(
        sourceFile: 'lib/calculator.dart',
        lines: [
          LcovLineRecord(lineNumber: 1, hitCount: 1),
          LcovLineRecord(lineNumber: 2, hitCount: 1),
          LcovLineRecord(lineNumber: 5, hitCount: 0),
          LcovLineRecord(lineNumber: 6, hitCount: 0),
          LcovLineRecord(lineNumber: 10, hitCount: 0),
          LcovLineRecord(lineNumber: 11, hitCount: 0),
        ],
        functions: [],
        branches: [],
      ),
    ];

    final report = CoverageAnalyzer().analyze(
      records: records,
      sourceResolver: const FileSystemSourceResolver(
        sourceRoot: 'test/fixtures/project',
      ),
      config: const CoverageAnalysisConfig(),
      generatedAt: DateTime.utc(2026, 6, 26),
    );

    final file = report.files.single;
    expect(file.lines.first.text, 'int add(int a, int b) {');
    expect(
      file.lines
          .where((line) => line.status == CoverageLineStatus.ignored)
          .map((line) => line.number),
      [9, 10, 11, 12, 13],
    );
    expect(file.summary.uncoveredLines, 2);
  });

  test('tracks excluded generated files without counting them in coverage', () {
    final records = [
      const LcovFileRecord(
        sourceFile: 'lib/generated_model.g.dart',
        lines: [LcovLineRecord(lineNumber: 2, hitCount: 0)],
        functions: [],
        branches: [],
      ),
    ];

    final report = CoverageAnalyzer().analyze(
      records: records,
      sourceResolver: const FileSystemSourceResolver(
        sourceRoot: 'test/fixtures/project',
      ),
      config: const CoverageAnalysisConfig(excludes: ['**/*.g.dart']),
      generatedAt: DateTime.utc(2026, 6, 26),
    );

    expect(report.files, isEmpty);
    expect(report.excludedFiles.single.path, 'lib/generated_model.g.dart');
    expect(
      report.excludedFiles.single.reason,
      'Matched exclude pattern **/*.g.dart',
    );
    expect(report.summary.executableLines, 0);
    expect(report.summary.coveredLines, 0);
    expect(report.summary.uncoveredLines, 0);
  });
}
