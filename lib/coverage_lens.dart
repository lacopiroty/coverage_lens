/// Public API for parsing LCOV data and building Coverage Lens reports.
///
/// Most users run the `coverage_lens` executable from the command line. These
/// exports are useful when another Dart tool wants to parse LCOV, merge records,
/// inspect coverage summaries, or render reports programmatically.
library;

export 'src/analysis/coverage_analyzer.dart';
export 'src/analysis/source_loader.dart';
export 'src/config/coverage_lens_config.dart';
export 'src/html/html_report_renderer.dart';
export 'src/lcov/lcov_parser.dart';
export 'src/model/coverage_models.dart';
