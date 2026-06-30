import 'dart:io';

import '../html/html_report_renderer.dart';

class CoverageLensLiveServer {
  const CoverageLensLiveServer(this.report);

  static const defaultHost = '127.0.0.1';
  static const defaultPort = 8787;

  final HtmlReportOutput report;

  Future<HttpServer> start({
    String host = defaultHost,
    int port = defaultPort,
  }) async {
    final server = await HttpServer.bind(host, port);
    server.listen(_handleRequest);
    return server;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');

    final path = _requestPath(request);
    final content =
        path == 'index.html' ? report.indexHtml : report.assets[path];

    if (content == null) {
      response.statusCode = HttpStatus.notFound;
      response.headers.contentType = ContentType.text;
      response.write('Not found');
      await response.close();
      return;
    }

    response.headers.contentType = _contentTypeFor(path);
    response.write(content);
    await response.close();
  }

  String _requestPath(HttpRequest request) {
    if (request.uri.path == '/' || request.uri.path.isEmpty) {
      return 'index.html';
    }
    return request.uri.pathSegments.join('/');
  }

  ContentType _contentTypeFor(String path) {
    if (path.endsWith('.css')) {
      return ContentType('text', 'css', charset: 'utf-8');
    }
    if (path.endsWith('.html')) {
      return ContentType.html;
    }
    return ContentType.text;
  }
}
