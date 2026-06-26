import 'package:coverage_lens/src/cli/coverage_lens_cli.dart';
import 'package:test/test.dart';

void main() {
  test('prints help without failing', () async {
    final exitCode = await CoverageLensCli().run(['--help']);

    expect(exitCode, 0);
  });

  test('returns usage exit code for unknown command', () async {
    final exitCode = await CoverageLensCli().run(['unknown']);

    expect(exitCode, 64);
  });
}
