import 'dart:io';

import 'package:coverage_lens/src/cli/coverage_lens_cli.dart';

Future<void> main(List<String> arguments) async {
  final exitCode = await CoverageLensCli().run(arguments);
  exit(exitCode);
}
