import 'dart:io';

import 'package:coverage_lens/src/cli/coverage_lens_cli.dart';
import 'package:test/test.dart';

void main() {
  test('returns input error when lcov file is missing', () async {
    final exitCode = await CoverageLensCli().run([
      'report',
      '--lcov',
      'missing.lcov',
      '--source',
      '.',
      '--out',
      'build/test_missing',
    ]);

    expect(exitCode, 66);
  });

  test('generates report and returns threshold failure code', () async {
    final outDir = Directory('build/test_cli_threshold');
    if (outDir.existsSync()) {
      outDir.deleteSync(recursive: true);
    }

    final exitCode = await CoverageLensCli().run([
      'report',
      '--lcov',
      'test/fixtures/sample.lcov',
      '--source',
      'test/fixtures/project',
      '--out',
      outDir.path,
      '--fail-under-lines',
      '90',
    ]);

    expect(File('${outDir.path}/index.html').existsSync(), isTrue);
    expect(exitCode, 2);
  });

  test('writes source previews outside the index html', () async {
    final outDir = Directory('build/test_cli_assets');
    if (outDir.existsSync()) {
      outDir.deleteSync(recursive: true);
    }

    final exitCode = await CoverageLensCli().run([
      'report',
      '--lcov',
      'test/fixtures/sample.lcov',
      '--source',
      'test/fixtures/project',
      '--out',
      outDir.path,
      '--fail-under-lines',
      '0',
      '--fail-under-branches',
      '0',
    ]);

    final indexFile = File('${outDir.path}/index.html');
    final previewFile = File('${outDir.path}/files/lib-calculator-dart.html');

    expect(exitCode, 0);
    expect(indexFile.existsSync(), isTrue);
    expect(previewFile.existsSync(), isTrue);

    final indexHtml = indexFile.readAsStringSync();
    final previewHtml = previewFile.readAsStringSync();

    expect(indexHtml,
        contains('data-preview-src="files/lib-calculator-dart.html"'));
    expect(indexHtml, isNot(contains('return a + b;')));
    expect(previewHtml, contains('return a + b;'));
    expect(previewHtml, contains('../assets/source_preview.css'));
  });
}
