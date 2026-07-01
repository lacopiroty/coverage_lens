import 'dart:io';

import 'package:coverage_lens/src/cli/coverage_lens_cli.dart';
import 'package:image/image.dart' as image;
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
    final previewFile = _previewFile(outDir, 'lib-calculator-dart-');

    expect(exitCode, 0);
    expect(indexFile.existsSync(), isTrue);
    expect(previewFile.existsSync(), isTrue);

    final indexHtml = indexFile.readAsStringSync();
    final previewScript = previewFile.readAsStringSync();

    expect(indexHtml, contains('data-preview-src="files/lib-calculator-dart-'));
    expect(
      indexHtml,
      contains('<link rel="stylesheet" href="assets/source_preview.css">'),
    );
    expect(indexHtml, isNot(contains('return a + b;')));
    expect(previewScript, contains('return a + b;'));
    expect(previewScript, contains('window.__coverageLensPreviewStore'));
  });

  test('writes a one-page summary pdf without source file details', () async {
    final outDir = Directory('build/test_cli_summary_pdf');
    if (outDir.existsSync()) {
      outDir.deleteSync(recursive: true);
    }
    final iconImage = image.Image(width: 2, height: 2)
      ..setPixelRgba(0, 0, 34, 116, 180, 255)
      ..setPixelRgba(1, 0, 34, 116, 180, 255)
      ..setPixelRgba(0, 1, 52, 166, 112, 255)
      ..setPixelRgba(1, 1, 52, 166, 112, 255);
    final iconFile = File('${outDir.path}/icon.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(image.encodePng(iconImage));

    final exitCode = await CoverageLensCli().run([
      'report',
      '--lcov',
      'test/fixtures/sample.lcov',
      '--source',
      'test/fixtures/project',
      '--out',
      outDir.path,
      '--summary-pdf',
      '--summary-icon',
      iconFile.path,
      '--project-name',
      'Sample App',
      '--fail-under-lines',
      '0',
      '--fail-under-branches',
      '0',
    ]);

    final pdfFile = File('${outDir.path}/summary.pdf');
    final pdfText = String.fromCharCodes(pdfFile.readAsBytesSync());

    expect(exitCode, 0);
    expect(pdfFile.existsSync(), isTrue);
    expect(pdfText, startsWith('%PDF-1.4'));
    expect(RegExp(r'/Type /Page\b').allMatches(pdfText), hasLength(1));
    expect(pdfText, contains('/Count 1'));
    expect(pdfText, contains('Coverage summary'));
    expect(pdfText, contains('SAMPLE APP | COVERAGE LENS'));
    expect(pdfText, isNot(contains('COVERAGE LENS REPORT')));
    expect(pdfText, contains('Branch coverage'));
    expect(pdfText, contains('Line mix'));
    expect(pdfText, contains('At a glance'));
    expect(pdfText, contains('Files analyzed'));
    expect(pdfText, contains('/Subtype /Image'));
    expect(pdfText, contains('Report scope'));
    expect(
      pdfText,
      contains(
        'This PDF summarizes the configured LCOV source scope for the current Git snapshot.',
      ),
    );
    expect(
      pdfText,
      isNot(
        contains(
          'A one-page view of aggregate test coverage. No source files, no code.',
        ),
      ),
    );
    expect(pdfText, isNot(contains('lib/calculator.dart')));
    expect(pdfText, isNot(contains('return a + b;')));
  });

  test('merges multiple lcov files and rebases package relative sources',
      () async {
    final projectDir = Directory('build/test_cli_multi_project');
    final outDir = Directory('build/test_cli_multi_report');
    if (projectDir.existsSync()) {
      projectDir.deleteSync(recursive: true);
    }
    if (outDir.existsSync()) {
      outDir.deleteSync(recursive: true);
    }

    File('${projectDir.path}/lib/root.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('int root() => 1;\n');
    File('${projectDir.path}/modules/core/lib/core.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('int core() => 2;\n');
    File('${projectDir.path}/coverage/lcov.info')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
SF:lib/root.dart
DA:1,1
LF:1
LH:1
end_of_record
''');
    File('${projectDir.path}/modules/core/coverage/lcov.info')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
SF:lib/core.dart
DA:1,1
LF:1
LH:1
end_of_record
''');

    final exitCode = await CoverageLensCli().run([
      'report',
      '--lcov',
      '${projectDir.path}/coverage/lcov.info',
      '--lcov',
      '${projectDir.path}/modules/**/coverage/lcov.info',
      '--source',
      projectDir.path,
      '--out',
      outDir.path,
      '--fail-under-lines',
      '0',
      '--fail-under-branches',
      '0',
    ]);

    final indexHtml = File('${outDir.path}/index.html').readAsStringSync();

    expect(exitCode, 0);
    expect(indexHtml, contains('lib/root.dart'));
    expect(indexHtml, contains('modules/core/lib/core.dart'));
    expect(
      _previewFile(outDir, 'modules-core-lib-core-dart-').existsSync(),
      isTrue,
    );
  });

  test('reads lcovPaths from config and expands globs', () async {
    final projectDir = Directory('build/test_cli_config_paths_project');
    final outDir = Directory('build/test_cli_config_paths_report');
    final configFile = File('build/test_cli_config_paths.yaml');
    if (projectDir.existsSync()) {
      projectDir.deleteSync(recursive: true);
    }
    if (outDir.existsSync()) {
      outDir.deleteSync(recursive: true);
    }

    File('${projectDir.path}/packages/nested/lib/nested.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('int nested() => 3;\n');
    File('${projectDir.path}/packages/nested/coverage/lcov.info')
      ..createSync(recursive: true)
      ..writeAsStringSync('''
SF:lib/nested.dart
DA:1,1
LF:1
LH:1
end_of_record
''');
    configFile
      ..createSync(recursive: true)
      ..writeAsStringSync('''
sourceRoot: ${projectDir.path}
outputDir: ${outDir.path}
lcovPaths:
  - ${projectDir.path}/packages/**/coverage/lcov.info
  - ${projectDir.path}/missing/**/coverage/lcov.info
thresholds:
  line: 0
  branch: 0
''');

    final exitCode = await CoverageLensCli().run([
      'report',
      '--config',
      configFile.path,
    ]);

    final indexHtml = File('${outDir.path}/index.html').readAsStringSync();

    expect(exitCode, 0);
    expect(indexHtml, contains('packages/nested/lib/nested.dart'));
  });
}

File _previewFile(Directory outDir, String basenamePrefix) {
  return Directory('${outDir.path}/files')
      .listSync()
      .whereType<File>()
      .singleWhere((file) {
    final name = file.uri.pathSegments.last;
    return name.startsWith(basenamePrefix) && name.endsWith('.js');
  });
}
