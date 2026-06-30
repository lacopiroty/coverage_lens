import 'dart:convert';
import 'dart:math' as math;

import '../model/coverage_models.dart';

class PdfSummaryRenderer {
  const PdfSummaryRenderer();

  List<int> render(
    CoverageReport report, {
    PdfSummaryOptions options = const PdfSummaryOptions(),
  }) {
    final content = _renderPageContent(report, options);
    final imageResources = options.icon == null
        ? ''
        : ' /XObject << /Im1 $_imageObjectNumber 0 R >>';
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '''
<< /Type /Page
   /Parent 2 0 R
   /MediaBox [0 0 595 842]
   /Resources << /Font << /F1 4 0 R /F2 5 0 R >>$imageResources >>
   /Contents 6 0 R
>>''',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
      '''
<< /Length ${latin1.encode(content).length} >>
stream
$content
endstream''',
    ];
    final icon = options.icon;
    if (icon != null) {
      objects.add(_imageObject(icon));
    }

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];
    for (var index = 0; index < objects.length; index += 1) {
      offsets.add(latin1.encode(buffer.toString()).length);
      buffer
        ..writeln('${index + 1} 0 obj')
        ..writeln(objects[index])
        ..writeln('endobj');
    }

    final xrefOffset = latin1.encode(buffer.toString()).length;
    buffer
      ..writeln('xref')
      ..writeln('0 ${objects.length + 1}')
      ..writeln('0000000000 65535 f ');
    for (final offset in offsets) {
      buffer.writeln('${offset.toString().padLeft(10, '0')} 00000 n ');
    }
    buffer
      ..writeln('trailer')
      ..writeln('<< /Size ${objects.length + 1} /Root 1 0 R >>')
      ..writeln('startxref')
      ..writeln(xrefOffset)
      ..writeln('%%EOF');

    return latin1.encode(buffer.toString());
  }

  String _renderPageContent(CoverageReport report, PdfSummaryOptions options) {
    final summary = report.summary;
    final files = report.files;
    final branchCoverage = summary.branchCoveragePercent;
    final sourceDescription = _sourceDescription(options);
    final scopeLines = _scopeLines(options);
    final metrics = [
      _PdfMetric(label: 'Lines covered', value: '${summary.coveredLines}'),
      _PdfMetric(label: 'Lines missing', value: '${summary.uncoveredLines}'),
      _PdfMetric(
        label: 'Branch outcomes',
        value: summary.branchFound == 0
            ? 'n/a'
            : '${summary.branchHit} / ${summary.branchFound}',
      ),
      _PdfMetric(label: 'Files analyzed', value: '${files.length}'),
      _PdfMetric(
        label: 'Below target',
        value: '${summary.filesBelowThreshold}',
      ),
      _PdfMetric(
        label: 'Median file',
        value: _percent(_medianFileCoverage(files)),
      ),
    ];
    final details = [
      _PdfMetric(
        label: 'Fully covered',
        value: '${_fullyCoveredFiles(files)} / ${files.length}',
      ),
      _PdfMetric(label: 'No coverage', value: '${_zeroCoverageFiles(files)}'),
      _PdfMetric(
          label: 'Missing source', value: '${summary.missingSourceFiles}'),
      _PdfMetric(
          label: 'Excluded files', value: '${report.excludedFiles.length}'),
      _PdfMetric(label: 'Warnings', value: '${report.warnings.length}'),
      _PdfMetric(label: 'Executable', value: '${summary.executableLines}'),
    ];
    final lineCoverage = summary.lineCoveragePercent;
    final coveredPercent = summary.executableLines == 0
        ? 100.0
        : summary.coveredLines * 100 / summary.executableLines;
    final accent = _coverageColor(lineCoverage);

    final buffer = StringBuffer()
      ..writeln('q 0.965 0.975 0.988 rg 0 0 595 842 re f Q');
    _softCircle(
      buffer,
      centerX: 505,
      centerY: 778,
      radius: 116,
      color: '0.88 0.93 0.98',
    );
    _softCircle(
      buffer,
      centerX: 91,
      centerY: 735,
      radius: 44,
      color: '0.90 0.96 0.92',
    );
    _softCircle(
      buffer,
      centerX: 472,
      centerY: 112,
      radius: 130,
      color: '0.90 0.93 0.98',
    );
    final icon = options.icon;
    final labelX = icon == null ? 48.0 : 87.0;
    if (icon != null) {
      _roundedRect(
        buffer,
        x: 48,
        y: 780,
        width: 28,
        height: 28,
        radius: 7,
        fill: '1 1 1',
      );
      final scale = math.min(22 / icon.width, 22 / icon.height);
      final iconWidth = icon.width * scale;
      final iconHeight = icon.height * scale;
      _image(
        buffer,
        x: 48 + (28 - iconWidth) / 2,
        y: 780 + (28 - iconHeight) / 2 + 1.8,
        width: iconWidth,
        height: iconHeight,
      );
    }
    final projectName = options.projectName;
    if (projectName != null && projectName.isNotEmpty) {
      _text(
        buffer,
        x: labelX,
        y: 792,
        size: 9,
        font: 'F2',
        text: '${_shorten(projectName, 36).toUpperCase()} | COVERAGE LENS',
        color: _accentText,
      );
    } else {
      _text(
        buffer,
        x: labelX,
        y: 792,
        size: 9,
        font: 'F2',
        text: 'COVERAGE LENS',
        color: _accentText,
      );
    }
    _text(
      buffer,
      x: 48,
      y: 755,
      size: 31,
      font: 'F2',
      text: 'Coverage summary',
      color: _ink,
    );
    _text(
      buffer,
      x: 48,
      y: 732,
      size: 10,
      font: 'F1',
      text: sourceDescription,
      color: _muted,
    );
    _text(
      buffer,
      x: 48,
      y: 710,
      size: 9,
      font: 'F1',
      text: 'Generated: ${_formatGeneratedAt(report.generatedAt)}',
      color: _muted,
    );

    _card(buffer, x: 42, y: 420, width: 511, height: 258);
    _donutChart(
      buffer,
      centerX: 174,
      centerY: 548,
      radius: 88,
      thickness: 18,
      percent: lineCoverage,
    );
    _centeredText(
      buffer,
      centerX: 174,
      y: 554,
      size: 27,
      font: 'F2',
      text: _percent(lineCoverage),
      color: _ink,
    );
    _centeredText(
      buffer,
      centerX: 174,
      y: 528,
      size: 9,
      font: 'F1',
      text: 'line coverage',
      color: _muted,
    );

    _statusPill(
      buffer,
      x: 315,
      y: 626,
      width: 148,
      height: 26,
      color: accent,
      text: _coverageStatus(lineCoverage),
    );
    _text(
      buffer,
      x: 315,
      y: 596,
      size: 23,
      font: 'F2',
      text: _percent(lineCoverage),
      color: _ink,
    );
    _text(
      buffer,
      x: 315,
      y: 574,
      size: 10,
      font: 'F1',
      text: 'overall lines covered',
      color: _muted,
    );

    _thinRule(buffer, x: 315, y: 548, width: 178, color: '0.89 0.92 0.96');
    _text(
      buffer,
      x: 315,
      y: 525,
      size: 8,
      font: 'F1',
      text: 'Branch coverage',
      color: _muted,
    );
    _text(
      buffer,
      x: 456,
      y: 525,
      size: 10,
      font: 'F2',
      text: branchCoverage == null ? 'n/a' : _percent(branchCoverage),
      color: _ink,
    );
    _progressBar(
      buffer,
      x: 315,
      y: 505,
      width: 178,
      height: 8,
      percent: branchCoverage ?? 0,
      background: '0.88 0.91 0.95',
      color: _blue,
    );
    _text(
      buffer,
      x: 315,
      y: 478,
      size: 8,
      font: 'F1',
      text: 'Line mix',
      color: _muted,
    );
    _gradientBar(
      buffer,
      x: 315,
      y: 459,
      width: 178,
      height: 9,
      markerPercent: coveredPercent,
    );
    _legendDot(buffer, x: 315, y: 443, color: _green);
    _text(
      buffer,
      x: 329,
      y: 440,
      size: 8,
      font: 'F1',
      text: '${summary.coveredLines} covered',
      color: _muted,
    );
    _legendDot(buffer, x: 410, y: 443, color: _red);
    _text(
      buffer,
      x: 424,
      y: 440,
      size: 8,
      font: 'F1',
      text: '${summary.uncoveredLines} uncovered',
      color: _muted,
    );

    _text(buffer, x: 48, y: 381, size: 15, font: 'F2', text: 'At a glance');
    for (var index = 0; index < metrics.length; index += 1) {
      final column = index % 3;
      final row = index ~/ 3;
      _metricCard(
        buffer,
        x: 42 + column * 174,
        y: 302 - row * 64,
        width: 158,
        height: 50,
        metric: metrics[index],
      );
    }

    _text(
      buffer,
      x: 48,
      y: 214,
      size: 13,
      font: 'F2',
      text: 'Coverage context',
      color: _ink,
    );
    for (var index = 0; index < details.length; index += 1) {
      _detailCard(
        buffer,
        x: 42 + index * 86,
        y: 158,
        width: 76,
        height: 40,
        metric: details[index],
      );
    }

    _roundedRect(
      buffer,
      x: 42,
      y: 56,
      width: 511,
      height: 56,
      radius: 8,
      fill: '0.93 0.96 0.98',
    );
    _text(
      buffer,
      x: 62,
      y: 92,
      size: 8,
      font: 'F2',
      text: 'Report scope',
      color: _muted,
    );
    _text(
      buffer,
      x: 62,
      y: 78,
      size: 8,
      font: 'F1',
      text: scopeLines.first,
      color: _muted,
    );
    _text(
      buffer,
      x: 62,
      y: 66,
      size: 8,
      font: 'F1',
      text: scopeLines.last,
      color: _muted,
    );

    return buffer.toString();
  }

  String _imageObject(PdfSummaryIcon icon) {
    final imageData = '${_hex(icon.rgbBytes)}>';
    return '''
<< /Type /XObject
   /Subtype /Image
   /Width ${icon.width}
   /Height ${icon.height}
   /ColorSpace /DeviceRGB
   /BitsPerComponent 8
   /Filter /ASCIIHexDecode
   /Length ${imageData.length}
>>
stream
$imageData
endstream''';
  }

  void _metricCard(
    StringBuffer buffer, {
    required double x,
    required double y,
    required double width,
    required double height,
    required _PdfMetric metric,
  }) {
    _roundedRect(
      buffer,
      x: x + 2,
      y: y - 2,
      width: width,
      height: height,
      radius: 7,
      fill: '0.88 0.91 0.95',
    );
    _roundedRect(
      buffer,
      x: x,
      y: y,
      width: width,
      height: height,
      radius: 7,
      fill: '1 1 1',
    );
    _text(
      buffer,
      x: x + 14,
      y: y + 30,
      size: 8,
      font: 'F1',
      text: metric.label,
      color: _muted,
    );
    _text(
      buffer,
      x: x + 14,
      y: y + 8,
      size: 18,
      font: 'F2',
      text: metric.value,
      color: _ink,
    );
  }

  void _detailCard(
    StringBuffer buffer, {
    required double x,
    required double y,
    required double width,
    required double height,
    required _PdfMetric metric,
  }) {
    _roundedRect(
      buffer,
      x: x,
      y: y,
      width: width,
      height: height,
      radius: 7,
      fill: '0.985 0.990 0.995',
    );
    _text(
      buffer,
      x: x + 9,
      y: y + 24,
      size: 6.8,
      font: 'F1',
      text: metric.label,
      color: _muted,
    );
    _text(
      buffer,
      x: x + 9,
      y: y + 9,
      size: 11,
      font: 'F2',
      text: metric.value,
      color: _ink,
    );
  }

  void _card(
    StringBuffer buffer, {
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    _roundedRect(
      buffer,
      x: x + 3,
      y: y - 3,
      width: width,
      height: height,
      radius: 10,
      fill: '0.88 0.91 0.95',
    );
    _roundedRect(
      buffer,
      x: x,
      y: y,
      width: width,
      height: height,
      radius: 10,
      fill: '1 1 1',
    );
  }

  void _statusPill(
    StringBuffer buffer, {
    required double x,
    required double y,
    required double width,
    required double height,
    required String color,
    required String text,
  }) {
    _roundedRect(
      buffer,
      x: x,
      y: y,
      width: width,
      height: height,
      radius: height / 2,
      fill: color,
    );
    _text(
      buffer,
      x: x + 14,
      y: y + 10,
      size: 9,
      font: 'F2',
      text: text,
      color: '1 1 1',
    );
  }

  void _progressBar(
    StringBuffer buffer, {
    required double x,
    required double y,
    required double width,
    required double height,
    required double percent,
    String background = '0.86 0.89 0.93',
    String? color,
  }) {
    final filledWidth = width * percent.clamp(0, 100) / 100;
    _roundedRect(
      buffer,
      x: x,
      y: y,
      width: width,
      height: height,
      radius: height / 2,
      fill: background,
    );
    if (filledWidth <= 0) {
      return;
    }
    _roundedRect(
      buffer,
      x: x,
      y: y,
      width: filledWidth,
      height: height,
      radius: height / 2,
      fill: color ?? _coverageColor(percent),
    );
  }

  void _gradientBar(
    StringBuffer buffer, {
    required double x,
    required double y,
    required double width,
    required double height,
    required double markerPercent,
  }) {
    _roundedRect(
      buffer,
      x: x,
      y: y,
      width: width,
      height: height,
      radius: height / 2,
      fill: '0.88 0.91 0.95',
    );
    const steps = 72;
    final bodyX = x + height / 2;
    final bodyWidth = width - height;
    final segmentWidth = bodyWidth / steps;
    _circle(
      buffer,
      centerX: x + height / 2,
      centerY: y + height / 2,
      radius: height / 2,
      color: _lineMixColor(0),
    );
    _circle(
      buffer,
      centerX: x + width - height / 2,
      centerY: y + height / 2,
      radius: height / 2,
      color: _lineMixColor(1),
    );
    for (var index = 0; index < steps; index += 1) {
      final t = index / (steps - 1);
      buffer.writeln(
        'q ${_lineMixColor(t)} rg ${_n(bodyX + index * segmentWidth)} '
        '${_n(y)} ${_n(segmentWidth + 0.4)} ${_n(height)} re f Q',
      );
    }
    final markerX = x + width * markerPercent.clamp(0, 100) / 100;
    _roundedRect(
      buffer,
      x: markerX - 1.2,
      y: y - 2,
      width: 2.4,
      height: height + 4,
      radius: 1.2,
      fill: '1 1 1',
    );
    _circle(
      buffer,
      centerX: markerX,
      centerY: y + height / 2,
      radius: 3.7,
      color: '1 1 1',
    );
    _circle(
      buffer,
      centerX: markerX,
      centerY: y + height / 2,
      radius: 2.0,
      color: _ink,
    );
  }

  void _thinRule(
    StringBuffer buffer, {
    required double x,
    required double y,
    required double width,
    required String color,
  }) {
    buffer.writeln('q $color rg ${_n(x)} ${_n(y)} ${_n(width)} 1 re f Q');
  }

  void _image(
    StringBuffer buffer, {
    required double x,
    required double y,
    required double width,
    required double height,
  }) {
    buffer.writeln(
      'q ${_n(width)} 0 0 ${_n(height)} ${_n(x)} ${_n(y)} cm /Im1 Do Q',
    );
  }

  void _donutChart(
    StringBuffer buffer, {
    required double centerX,
    required double centerY,
    required double radius,
    required double thickness,
    required double percent,
  }) {
    final innerRadius = radius - thickness;
    final color = _coverageColor(percent);
    _circle(
      buffer,
      centerX: centerX,
      centerY: centerY,
      radius: radius,
      color: '0.88 0.91 0.95',
    );
    if (percent >= 100) {
      _circle(
        buffer,
        centerX: centerX,
        centerY: centerY,
        radius: radius,
        color: _lightenColor(color, 0.30),
      );
      _circle(
        buffer,
        centerX: centerX,
        centerY: centerY,
        radius: radius - 4,
        color: color,
      );
    } else {
      _donutArc(
        buffer,
        centerX: centerX,
        centerY: centerY,
        radius: radius,
        innerRadius: innerRadius,
        percent: percent,
        color: _lightenColor(color, 0.26),
      );
      _donutArc(
        buffer,
        centerX: centerX,
        centerY: centerY,
        radius: radius - 3,
        innerRadius: innerRadius + 3,
        percent: percent,
        color: color,
      );
    }
    _circle(
      buffer,
      centerX: centerX,
      centerY: centerY,
      radius: innerRadius,
      color: '1 1 1',
    );
  }

  void _donutArc(
    StringBuffer buffer, {
    required double centerX,
    required double centerY,
    required double radius,
    required double innerRadius,
    required double percent,
    required String color,
  }) {
    final clamped = percent.clamp(0, 100).toDouble();
    if (clamped <= 0) {
      return;
    }
    final steps = math.max(12, (160 * clamped / 100).ceil());
    final start = -math.pi / 2;
    final sweep = math.pi * 2 * clamped / 100;
    final path = StringBuffer('q $color rg ');
    for (var index = 0; index <= steps; index += 1) {
      final angle = start + sweep * index / steps;
      final point = _pointOnCircle(centerX, centerY, radius, angle);
      if (index == 0) {
        path.write('${_n(point.x)} ${_n(point.y)} m ');
      } else {
        path.write('${_n(point.x)} ${_n(point.y)} l ');
      }
    }
    for (var index = steps; index >= 0; index -= 1) {
      final angle = start + sweep * index / steps;
      final point = _pointOnCircle(centerX, centerY, innerRadius, angle);
      path.write('${_n(point.x)} ${_n(point.y)} l ');
    }
    path.write('h f Q');
    buffer.writeln(path.toString());
  }

  void _legendDot(
    StringBuffer buffer, {
    required double x,
    required double y,
    required String color,
  }) {
    _roundedRect(
      buffer,
      x: x,
      y: y,
      width: 7,
      height: 7,
      radius: 2,
      fill: color,
    );
  }

  void _circle(
    StringBuffer buffer, {
    required double centerX,
    required double centerY,
    required double radius,
    required String color,
  }) {
    final k = radius * 0.5522847498;
    buffer.writeln(
      'q $color rg '
      '${_n(centerX + radius)} ${_n(centerY)} m '
      '${_n(centerX + radius)} ${_n(centerY + k)} ${_n(centerX + k)} ${_n(centerY + radius)} ${_n(centerX)} ${_n(centerY + radius)} c '
      '${_n(centerX - k)} ${_n(centerY + radius)} ${_n(centerX - radius)} ${_n(centerY + k)} ${_n(centerX - radius)} ${_n(centerY)} c '
      '${_n(centerX - radius)} ${_n(centerY - k)} ${_n(centerX - k)} ${_n(centerY - radius)} ${_n(centerX)} ${_n(centerY - radius)} c '
      '${_n(centerX + k)} ${_n(centerY - radius)} ${_n(centerX + radius)} ${_n(centerY - k)} ${_n(centerX + radius)} ${_n(centerY)} c h f Q',
    );
  }

  void _softCircle(
    StringBuffer buffer, {
    required double centerX,
    required double centerY,
    required double radius,
    required String color,
  }) {
    _circle(
      buffer,
      centerX: centerX,
      centerY: centerY,
      radius: radius,
      color: _lightenColor(color, 0.55),
    );
    _circle(
      buffer,
      centerX: centerX,
      centerY: centerY,
      radius: radius * 0.72,
      color: _lightenColor(color, 0.30),
    );
    _circle(
      buffer,
      centerX: centerX,
      centerY: centerY,
      radius: radius * 0.46,
      color: color,
    );
  }

  void _roundedRect(
    StringBuffer buffer, {
    required double x,
    required double y,
    required double width,
    required double height,
    required double radius,
    required String fill,
  }) {
    final r = math.min(radius, math.min(width, height) / 2);
    final k = r * 0.5522847498;
    final right = x + width;
    final top = y + height;
    buffer.writeln(
      'q $fill rg '
      '${_n(x + r)} ${_n(y)} m '
      '${_n(right - r)} ${_n(y)} l '
      '${_n(right - r + k)} ${_n(y)} ${_n(right)} ${_n(y + r - k)} ${_n(right)} ${_n(y + r)} c '
      '${_n(right)} ${_n(top - r)} l '
      '${_n(right)} ${_n(top - r + k)} ${_n(right - r + k)} ${_n(top)} ${_n(right - r)} ${_n(top)} c '
      '${_n(x + r)} ${_n(top)} l '
      '${_n(x + r - k)} ${_n(top)} ${_n(x)} ${_n(top - r + k)} ${_n(x)} ${_n(top - r)} c '
      '${_n(x)} ${_n(y + r)} l '
      '${_n(x)} ${_n(y + r - k)} ${_n(x + r - k)} ${_n(y)} ${_n(x + r)} ${_n(y)} c h f Q',
    );
  }

  _PdfPoint _pointOnCircle(
    double centerX,
    double centerY,
    double radius,
    double angle,
  ) {
    return _PdfPoint(
      centerX + math.cos(angle) * radius,
      centerY + math.sin(angle) * radius,
    );
  }

  String _coverageColor(double percent) {
    if (percent >= 80) {
      return _green;
    }
    if (percent >= 60) {
      return '0.88 0.61 0.20';
    }
    return _red;
  }

  String _coverageStatus(double percent) {
    if (percent >= 85) {
      return 'Ready to share';
    }
    if (percent >= 70) {
      return 'Healthy';
    }
    if (percent >= 50) {
      return 'Room to improve';
    }
    return 'Needs more tests';
  }

  void _text(
    StringBuffer buffer, {
    required double x,
    required double y,
    required double size,
    required String font,
    required String text,
    String color = _ink,
  }) {
    buffer.writeln(
      'q $color rg BT /$font ${_n(size)} Tf ${_n(x)} ${_n(y)} Td (${_escapeText(text)}) Tj ET Q',
    );
  }

  void _centeredText(
    StringBuffer buffer, {
    required double centerX,
    required double y,
    required double size,
    required String font,
    required String text,
    String color = _ink,
  }) {
    _text(
      buffer,
      x: centerX - _estimatedTextWidth(text, size, font) / 2,
      y: y,
      size: size,
      font: font,
      text: text,
      color: color,
    );
  }

  double _estimatedTextWidth(String text, double size, String font) {
    final factor = font == 'F2' ? 0.56 : 0.50;
    return text.length * size * factor;
  }

  double _medianFileCoverage(List<CoverageFile> files) {
    final values = files
        .where((file) => file.summary.executableLines > 0)
        .map((file) => file.summary.lineCoveragePercent)
        .toList()
      ..sort();
    if (values.isEmpty) {
      return 100;
    }
    final middle = values.length ~/ 2;
    if (values.length.isOdd) {
      return values[middle];
    }
    return (values[middle - 1] + values[middle]) / 2;
  }

  int _fullyCoveredFiles(List<CoverageFile> files) {
    return files
        .where(
          (file) =>
              file.summary.executableLines > 0 &&
              file.summary.uncoveredLines == 0,
        )
        .length;
  }

  int _zeroCoverageFiles(List<CoverageFile> files) {
    return files
        .where(
          (file) =>
              file.summary.executableLines > 0 &&
              file.summary.coveredLines == 0,
        )
        .length;
  }

  String _formatGeneratedAt(DateTime value) {
    final local = value.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _sourceDescription(PdfSummaryOptions options) {
    final parts = <String>[];
    final branch = options.branch;
    final commit = options.commit;
    if (branch != null && branch.isNotEmpty) {
      parts.add('Branch: ${_shorten(branch, 44)}');
    }
    if (commit != null && commit.isNotEmpty) {
      parts.add('Commit: $commit');
    }
    if (options.isDirty == true) {
      parts.add('Working tree: modified');
    }
    if (parts.isEmpty) {
      return 'Git source: unavailable for this generated report.';
    }
    return _shorten(parts.join(' | '), 92);
  }

  List<String> _scopeLines(PdfSummaryOptions options) {
    final firstLine = _shorten(
      'This PDF summarizes the configured LCOV source scope for the current Git snapshot.',
      96,
    );
    final thresholdText = options.lineThreshold == null
        ? 'Quality gates: no thresholds configured for this run.'
        : 'Quality gates: ${_percent(options.lineThreshold!)} line coverage and '
            '${options.branchThreshold == null ? 'n/a' : _percent(options.branchThreshold!)} branch coverage.';
    final secondLine = _shorten(thresholdText, 96);
    return [firstLine, secondLine];
  }

  String _percent(double value) => '${value.toStringAsFixed(1)}%';

  String _two(int value) => value.toString().padLeft(2, '0');

  String _n(num value) => value.toStringAsFixed(1);

  String _lightenColor(String color, double amount) {
    final values = color.split(' ').map(double.parse).toList();
    return values
        .map((value) => value + (1 - value) * amount)
        .map((value) => value.toStringAsFixed(3))
        .join(' ');
  }

  String _lineMixColor(double t) {
    const amber = '0.93 0.68 0.28';
    if (t <= 0.58) {
      return _mixColor(_green, amber, t / 0.58);
    }
    return _mixColor(amber, _red, (t - 0.58) / 0.42);
  }

  String _mixColor(String from, String to, double amount) {
    final start = from.split(' ').map(double.parse).toList();
    final end = to.split(' ').map(double.parse).toList();
    final t = amount.clamp(0, 1).toDouble();
    return List.generate(start.length, (index) {
      return (start[index] + (end[index] - start[index]) * t)
          .toStringAsFixed(3);
    }).join(' ');
  }

  String _shorten(String value, int maxLength) {
    if (value.length <= maxLength) {
      return value;
    }
    if (maxLength <= 3) {
      return value.substring(0, maxLength);
    }
    return '${value.substring(0, maxLength - 3)}...';
  }

  String _hex(List<int> bytes) {
    const alphabet = '0123456789ABCDEF';
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer
        ..write(alphabet[(byte >> 4) & 0x0f])
        ..write(alphabet[byte & 0x0f]);
    }
    return buffer.toString();
  }

  String _escapeText(String value) {
    final sanitized = value.runes.map((rune) {
      if (rune < 32 || rune > 126) {
        return 32;
      }
      return rune;
    });
    return String.fromCharCodes(
      sanitized,
    ).replaceAll(r'\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');
  }
}

const _imageObjectNumber = 7;
const _ink = '0.05 0.09 0.16';
const _muted = '0.34 0.41 0.51';
const _accentText = '0.17 0.34 0.56';
const _green = '0.20 0.62 0.43';
const _red = '0.82 0.28 0.28';
const _blue = '0.22 0.48 0.72';

class _PdfMetric {
  const _PdfMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class PdfSummaryOptions {
  const PdfSummaryOptions({
    this.branch,
    this.commit,
    this.isDirty,
    this.lineThreshold,
    this.branchThreshold,
    this.icon,
    this.projectName,
  });

  final String? branch;
  final String? commit;
  final bool? isDirty;
  final double? lineThreshold;
  final double? branchThreshold;
  final PdfSummaryIcon? icon;
  final String? projectName;
}

class PdfSummaryIcon {
  const PdfSummaryIcon({
    required this.width,
    required this.height,
    required this.rgbBytes,
  });

  final int width;
  final int height;
  final List<int> rgbBytes;
}

class _PdfPoint {
  const _PdfPoint(this.x, this.y);

  final double x;
  final double y;
}
