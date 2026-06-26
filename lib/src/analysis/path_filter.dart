class PathFilter {
  const PathFilter({this.includes = const [], this.excludes = const []});

  final List<String> includes;
  final List<String> excludes;

  bool allows(String path) {
    return isIncluded(path) && exclusionPattern(path) == null;
  }

  bool isIncluded(String path) {
    final normalized = path.replaceAll('\\', '/');
    return includes.isEmpty ||
        includes.any((pattern) => _matches(pattern, normalized));
  }

  String? exclusionPattern(String path) {
    final normalized = path.replaceAll('\\', '/');
    for (final pattern in excludes) {
      if (_matches(pattern, normalized)) {
        return pattern;
      }
    }
    return null;
  }

  bool _matches(String pattern, String path) {
    final normalizedPattern = pattern.replaceAll('\\', '/');
    final regex = RegExp(
      '^${RegExp.escape(normalizedPattern).replaceAll(r'\*\*', '.*').replaceAll(r'\*', '[^/]*')}\$',
    );
    return regex.hasMatch(path);
  }
}
