/// Parser for LCOV trace files.
class LcovParser {
  /// Parses raw LCOV [input] into file records and warnings.
  LcovParseResult parse(String input) {
    final files = <LcovFileRecord>[];
    final warnings = <LcovParseWarning>[];
    _MutableLcovFile? current;

    void finishCurrent() {
      final file = current;
      if (file == null) {
        return;
      }
      files.add(file.toRecord());
      current = null;
    }

    final inputLines = input.split(RegExp(r'\r?\n'));
    for (var index = 0; index < inputLines.length; index += 1) {
      final line = inputLines[index].trimRight();
      final inputLineNumber = index + 1;

      if (line.isEmpty || line == 'TN:') {
        continue;
      }

      if (line == 'end_of_record') {
        finishCurrent();
        continue;
      }

      if (line.startsWith('SF:')) {
        finishCurrent();
        current = _MutableLcovFile(line.substring(3));
        continue;
      }

      final file = current;
      if (file == null) {
        warnings.add(
          LcovParseWarning(
            inputLineNumber,
            'Ignoring record before SF: $line',
          ),
        );
        continue;
      }

      if (line.startsWith('DA:')) {
        final parsed = _parseDa(
          line.substring(3),
          inputLineNumber,
          warnings,
        );
        if (parsed != null) {
          file.lines.add(parsed);
        }
      } else if (line.startsWith('LF:')) {
        file.lineFound = _parseIntRecord(
          'LF',
          line.substring(3),
          inputLineNumber,
          warnings,
        );
      } else if (line.startsWith('LH:')) {
        file.lineHit = _parseIntRecord(
          'LH',
          line.substring(3),
          inputLineNumber,
          warnings,
        );
      } else if (line.startsWith('FN:')) {
        final parsed = _parseFunction(
          line.substring(3),
          inputLineNumber,
          warnings,
        );
        if (parsed != null) {
          file.functions.add(parsed);
        }
      } else if (line.startsWith('FNDA:')) {
        _applyFunctionHit(file, line.substring(5), inputLineNumber, warnings);
      } else if (line.startsWith('FNF:')) {
        file.functionFound = _parseIntRecord(
          'FNF',
          line.substring(4),
          inputLineNumber,
          warnings,
        );
      } else if (line.startsWith('FNH:')) {
        file.functionHit = _parseIntRecord(
          'FNH',
          line.substring(4),
          inputLineNumber,
          warnings,
        );
      } else if (line.startsWith('BRDA:')) {
        final parsed = _parseBranch(
          line.substring(5),
          inputLineNumber,
          warnings,
        );
        if (parsed != null) {
          file.branches.add(parsed);
        }
      } else if (line.startsWith('BRF:')) {
        file.branchFound = _parseIntRecord(
          'BRF',
          line.substring(4),
          inputLineNumber,
          warnings,
        );
      } else if (line.startsWith('BRH:')) {
        file.branchHit = _parseIntRecord(
          'BRH',
          line.substring(4),
          inputLineNumber,
          warnings,
        );
      }
    }

    finishCurrent();

    if (files.isEmpty && input.trim().isNotEmpty) {
      warnings.add(
        const LcovParseWarning(1, 'No usable LCOV file records were found.'),
      );
    }

    return LcovParseResult(files: files, warnings: warnings);
  }

  LcovLineRecord? _parseDa(
    String value,
    int inputLineNumber,
    List<LcovParseWarning> warnings,
  ) {
    final parts = value.split(',');
    if (parts.length < 2) {
      warnings.add(
        LcovParseWarning(inputLineNumber, 'Invalid DA record: $value'),
      );
      return null;
    }
    final lineNumber = int.tryParse(parts[0]);
    final hitCount = int.tryParse(parts[1]);
    if (lineNumber == null || hitCount == null) {
      warnings.add(
        LcovParseWarning(inputLineNumber, 'Invalid DA record: $value'),
      );
      return null;
    }
    return LcovLineRecord(lineNumber: lineNumber, hitCount: hitCount);
  }

  int? _parseIntRecord(
    String recordName,
    String value,
    int inputLineNumber,
    List<LcovParseWarning> warnings,
  ) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null) {
      warnings.add(
        LcovParseWarning(inputLineNumber, 'Invalid $recordName record: $value'),
      );
    }
    return parsed;
  }

  LcovFunctionRecord? _parseFunction(
    String value,
    int inputLineNumber,
    List<LcovParseWarning> warnings,
  ) {
    final commaIndex = value.indexOf(',');
    if (commaIndex <= 0 || commaIndex == value.length - 1) {
      warnings.add(
        LcovParseWarning(inputLineNumber, 'Invalid FN record: $value'),
      );
      return null;
    }
    final lineNumber = int.tryParse(value.substring(0, commaIndex));
    if (lineNumber == null) {
      warnings.add(
        LcovParseWarning(inputLineNumber, 'Invalid FN record: $value'),
      );
      return null;
    }
    return LcovFunctionRecord(
      lineNumber: lineNumber,
      name: value.substring(commaIndex + 1),
      hitCount: 0,
    );
  }

  void _applyFunctionHit(
    _MutableLcovFile file,
    String value,
    int inputLineNumber,
    List<LcovParseWarning> warnings,
  ) {
    final commaIndex = value.indexOf(',');
    if (commaIndex <= 0 || commaIndex == value.length - 1) {
      warnings.add(
        LcovParseWarning(inputLineNumber, 'Invalid FNDA record: $value'),
      );
      return;
    }
    final hitCount = int.tryParse(value.substring(0, commaIndex));
    final name = value.substring(commaIndex + 1);
    if (hitCount == null) {
      warnings.add(
        LcovParseWarning(inputLineNumber, 'Invalid FNDA record: $value'),
      );
      return;
    }
    final existingIndex = file.functions.indexWhere(
      (function) => function.name == name,
    );
    if (existingIndex == -1) {
      file.functions.add(
        LcovFunctionRecord(lineNumber: 0, name: name, hitCount: hitCount),
      );
      return;
    }
    final existing = file.functions[existingIndex];
    file.functions[existingIndex] = existing.copyWith(hitCount: hitCount);
  }

  LcovBranchRecord? _parseBranch(
    String value,
    int inputLineNumber,
    List<LcovParseWarning> warnings,
  ) {
    final parts = value.split(',');
    if (parts.length != 4) {
      warnings.add(
        LcovParseWarning(inputLineNumber, 'Invalid BRDA record: $value'),
      );
      return null;
    }
    final lineNumber = int.tryParse(parts[0]);
    final blockNumber = int.tryParse(parts[1]);
    final branchNumber = int.tryParse(parts[2]);
    final hitCount = parts[3] == '-' ? 0 : int.tryParse(parts[3]);
    if (lineNumber == null ||
        blockNumber == null ||
        branchNumber == null ||
        hitCount == null) {
      warnings.add(
        LcovParseWarning(inputLineNumber, 'Invalid BRDA record: $value'),
      );
      return null;
    }
    return LcovBranchRecord(
      lineNumber: lineNumber,
      blockNumber: blockNumber,
      branchNumber: branchNumber,
      hitCount: hitCount,
    );
  }
}

/// Merges records for the same source file by summing hit counts.
class LcovRecordMerger {
  /// Returns one merged record per source file path.
  List<LcovFileRecord> merge(List<LcovFileRecord> records) {
    final filesByPath = <String, _MergedLcovFile>{};
    for (final record in records) {
      filesByPath
          .putIfAbsent(
              record.sourceFile, () => _MergedLcovFile(record.sourceFile))
          .add(record);
    }
    final merged = filesByPath.values.map((file) => file.toRecord()).toList()
      ..sort((a, b) => a.sourceFile.compareTo(b.sourceFile));
    return List.unmodifiable(merged);
  }
}

/// Result of parsing an LCOV document.
class LcovParseResult {
  /// Creates a parse result.
  const LcovParseResult({required this.files, required this.warnings});

  /// Parsed source file records.
  final List<LcovFileRecord> files;

  /// Non-fatal parse warnings.
  final List<LcovParseWarning> warnings;
}

/// Warning emitted while parsing LCOV input.
class LcovParseWarning {
  /// Creates a parse warning for an input line.
  const LcovParseWarning(this.lineNumber, this.message);

  /// One-based line number in the LCOV input.
  final int lineNumber;

  /// Human-readable warning message.
  final String message;
}

/// LCOV data for one `SF:` source file section.
class LcovFileRecord {
  /// Creates a source file record.
  const LcovFileRecord({
    required this.sourceFile,
    required this.lines,
    required this.functions,
    required this.branches,
    this.lineFound,
    this.lineHit,
    this.functionFound,
    this.functionHit,
    this.branchFound,
    this.branchHit,
  });

  /// Source file path from the LCOV `SF:` field.
  final String sourceFile;

  /// Line execution records from `DA:` fields.
  final List<LcovLineRecord> lines;

  /// Function records from `FN:` and `FNDA:` fields.
  final List<LcovFunctionRecord> functions;

  /// Branch records from `BRDA:` fields.
  final List<LcovBranchRecord> branches;

  /// Optional total executable line count from `LF:`.
  final int? lineFound;

  /// Optional covered executable line count from `LH:`.
  final int? lineHit;

  /// Optional total function count from `FNF:`.
  final int? functionFound;

  /// Optional covered function count from `FNH:`.
  final int? functionHit;

  /// Optional total branch outcome count from `BRF:`.
  final int? branchFound;

  /// Optional covered branch outcome count from `BRH:`.
  final int? branchHit;
}

/// LCOV execution count for one source line.
class LcovLineRecord {
  /// Creates a line record.
  const LcovLineRecord({required this.lineNumber, required this.hitCount});

  /// One-based source line number.
  final int lineNumber;

  /// Number of times the line executed.
  final int hitCount;
}

/// LCOV execution count for one function.
class LcovFunctionRecord {
  /// Creates a function record.
  const LcovFunctionRecord({
    required this.lineNumber,
    required this.name,
    required this.hitCount,
  });

  /// One-based line number where the function is declared.
  final int lineNumber;

  /// Function name reported by LCOV.
  final String name;

  /// Number of times the function executed.
  final int hitCount;

  /// Returns a copy with a different hit count.
  LcovFunctionRecord copyWith({int? hitCount}) {
    return LcovFunctionRecord(
      lineNumber: lineNumber,
      name: name,
      hitCount: hitCount ?? this.hitCount,
    );
  }
}

/// LCOV execution count for one branch outcome.
class LcovBranchRecord {
  /// Creates a branch record.
  const LcovBranchRecord({
    required this.lineNumber,
    required this.blockNumber,
    required this.branchNumber,
    required this.hitCount,
  });

  /// One-based line number associated with the branch.
  final int lineNumber;

  /// LCOV block number.
  final int blockNumber;

  /// LCOV branch number inside [blockNumber].
  final int branchNumber;

  /// Number of times this branch outcome executed.
  final int hitCount;
}

class _MutableLcovFile {
  _MutableLcovFile(this.sourceFile);

  final String sourceFile;
  final lines = <LcovLineRecord>[];
  final functions = <LcovFunctionRecord>[];
  final branches = <LcovBranchRecord>[];
  int? lineFound;
  int? lineHit;
  int? functionFound;
  int? functionHit;
  int? branchFound;
  int? branchHit;

  LcovFileRecord toRecord() {
    return LcovFileRecord(
      sourceFile: sourceFile,
      lines: List.unmodifiable(lines),
      functions: List.unmodifiable(functions),
      branches: List.unmodifiable(branches),
      lineFound: lineFound,
      lineHit: lineHit,
      functionFound: functionFound,
      functionHit: functionHit,
      branchFound: branchFound,
      branchHit: branchHit,
    );
  }
}

class _MergedLcovFile {
  _MergedLcovFile(this.sourceFile);

  final String sourceFile;
  final lines = <int, LcovLineRecord>{};
  final functions = <String, LcovFunctionRecord>{};
  final branches = <String, LcovBranchRecord>{};

  void add(LcovFileRecord record) {
    for (final line in record.lines) {
      final existing = lines[line.lineNumber];
      lines[line.lineNumber] = LcovLineRecord(
        lineNumber: line.lineNumber,
        hitCount: (existing?.hitCount ?? 0) + line.hitCount,
      );
    }
    for (final function in record.functions) {
      final key = '${function.lineNumber}\u0000${function.name}';
      final existing = functions[key];
      functions[key] = LcovFunctionRecord(
        lineNumber: function.lineNumber,
        name: function.name,
        hitCount: (existing?.hitCount ?? 0) + function.hitCount,
      );
    }
    for (final branch in record.branches) {
      final key =
          '${branch.lineNumber}\u0000${branch.blockNumber}\u0000${branch.branchNumber}';
      final existing = branches[key];
      branches[key] = LcovBranchRecord(
        lineNumber: branch.lineNumber,
        blockNumber: branch.blockNumber,
        branchNumber: branch.branchNumber,
        hitCount: (existing?.hitCount ?? 0) + branch.hitCount,
      );
    }
  }

  LcovFileRecord toRecord() {
    final mergedLines = lines.values.toList()
      ..sort((a, b) => a.lineNumber.compareTo(b.lineNumber));
    final mergedFunctions = functions.values.toList()
      ..sort((a, b) {
        final byLine = a.lineNumber.compareTo(b.lineNumber);
        return byLine == 0 ? a.name.compareTo(b.name) : byLine;
      });
    final mergedBranches = branches.values.toList()
      ..sort((a, b) {
        final byLine = a.lineNumber.compareTo(b.lineNumber);
        if (byLine != 0) {
          return byLine;
        }
        final byBlock = a.blockNumber.compareTo(b.blockNumber);
        return byBlock == 0
            ? a.branchNumber.compareTo(b.branchNumber)
            : byBlock;
      });

    return LcovFileRecord(
      sourceFile: sourceFile,
      lines: List.unmodifiable(mergedLines),
      functions: List.unmodifiable(mergedFunctions),
      branches: List.unmodifiable(mergedBranches),
      lineFound: mergedLines.length,
      lineHit: mergedLines.where((line) => line.hitCount > 0).length,
      functionFound: mergedFunctions.length,
      functionHit:
          mergedFunctions.where((function) => function.hitCount > 0).length,
      branchFound: mergedBranches.length,
      branchHit: mergedBranches.where((branch) => branch.hitCount > 0).length,
    );
  }
}
