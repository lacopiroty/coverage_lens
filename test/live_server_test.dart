import 'dart:convert';
import 'dart:io';

import 'package:coverage_lens/src/html/html_report_renderer.dart';
import 'package:coverage_lens/src/server/live_server.dart';
import 'package:test/test.dart';

void main() {
  test('serves index and preview assets from memory', () async {
    const previewPath = 'files/live-only-preview.js';
    final output = HtmlReportOutput(
      indexHtml: '<script src="$previewPath"></script>',
      assets: const {
        previewPath: 'window.loadedPreview = true;',
        'assets/source_preview.css': 'body { color: #17202a; }',
      },
    );
    final server = await CoverageLensLiveServer(output).start(port: 0);
    final client = HttpClient();

    try {
      expect(File(previewPath).existsSync(), isFalse);

      final index = await _get(client, server.port, '/');
      final preview = await _get(client, server.port, '/$previewPath');
      final css = await _get(client, server.port, '/assets/source_preview.css');
      final missing = await _get(client, server.port, '/missing.html');

      expect(index.statusCode, HttpStatus.ok);
      expect(index.body, contains(previewPath));
      expect(preview.statusCode, HttpStatus.ok);
      expect(preview.contentType, startsWith('text/javascript'));
      expect(preview.body, contains('loadedPreview'));
      expect(css.statusCode, HttpStatus.ok);
      expect(css.contentType, startsWith('text/css'));
      expect(missing.statusCode, HttpStatus.notFound);
    } finally {
      client.close(force: true);
      await server.close(force: true);
    }
  });
}

Future<_ResponseBody> _get(HttpClient client, int port, String path) async {
  final request = await client.get('127.0.0.1', port, path);
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();
  return _ResponseBody(
    statusCode: response.statusCode,
    contentType: response.headers.contentType?.toString(),
    body: body,
  );
}

class _ResponseBody {
  const _ResponseBody({
    required this.statusCode,
    required this.contentType,
    required this.body,
  });

  final int statusCode;
  final String? contentType;
  final String body;
}
