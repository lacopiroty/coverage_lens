import 'dart:io';

import 'package:coverage_lens/src/lcov/lcov_parser.dart';
import 'package:test/test.dart';

void main() {
  test('parses file, line, function, and branch coverage', () {
    final text = File('test/fixtures/sample.lcov').readAsStringSync();

    final result = LcovParser().parse(text);

    expect(result.files, hasLength(2));

    final calculator = result.files.first;
    expect(calculator.sourceFile, 'lib/calculator.dart');
    expect(calculator.lines.map((line) => line.lineNumber), [1, 2, 4, 5]);
    expect(calculator.lines.map((line) => line.hitCount), [3, 3, 0, 0]);
    expect(calculator.lineFound, 4);
    expect(calculator.lineHit, 2);
    expect(calculator.functions.single.name, 'add');
    expect(calculator.functions.single.hitCount, 3);
    expect(calculator.branches, hasLength(2));
    expect(calculator.branchFound, 2);
    expect(calculator.branchHit, 1);
  });

  test('keeps usable file records and reports malformed records', () {
    final text = File('test/fixtures/sample.lcov').readAsStringSync();

    final result = LcovParser().parse(text);

    expect(result.files.last.sourceFile, 'lib/malformed.dart');
    expect(result.files.last.lines.single.lineNumber, 10);
    expect(result.warnings.single.message, contains('Invalid DA record'));
  });
}
