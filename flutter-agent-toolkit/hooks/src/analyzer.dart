import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'util.dart';

class Issue {
  Issue(this.severity, this.code, this.path, this.line, this.message);
  final String severity;
  final String code;
  final String path;
  final int line;
  final String message;
}

/// Analyzer INFO codes worth interrupting the agent for at the default
/// strictness. Other infos are style noise.
const importantInfoCodes = {
  'deprecated_member_use',
  'deprecated_member_use_from_same_package',
  'use_build_context_synchronously',
  'unused_import',
};

/// Runs `dart analyze` once for all [files] in [projectRoot] and returns the
/// issues allowed by [config].
Future<List<Issue>> analyzeFiles(
  String projectRoot,
  List<String> files,
  ToolkitConfig config,
) async {
  final ProcessResult result;
  try {
    result = await runDart([
      'analyze',
      '--format=machine',
      ...files,
    ], cwd: projectRoot);
  } on ProcessException {
    stderr.writeln(dartMissing);
    return [];
  }
  final output = '${result.stdout}\n${result.stderr}';
  final issues = <Issue>[];
  for (final issue in LineSplitter.split(output).map(parseMachineLine)) {
    if (issue == null || config.ignoreCodes.contains(issue.code)) continue;
    final keep = switch (config.strictness) {
      Strictness.errors => issue.severity == 'ERROR',
      Strictness.warnings =>
        issue.severity != 'INFO' || importantInfoCodes.contains(issue.code),
      Strictness.all => true,
    };
    if (keep) issues.add(issue);
  }
  return issues;
}

/// Parses `SEVERITY|TYPE|CODE|PATH|LINE|COLUMN|LENGTH|MESSAGE`, where the
/// message may contain escaped pipes.
Issue? parseMachineLine(String raw) {
  final parts = raw.split(RegExp(r'(?<!\\)\|'));
  if (parts.length < 8) return null;
  final severity = parts[0].trim();
  if (!const {'ERROR', 'WARNING', 'INFO'}.contains(severity)) return null;
  final line = int.tryParse(parts[4]);
  if (line == null) return null;
  final message = _unescape(parts.sublist(7).join('|'));
  return Issue(
    severity,
    parts[2].toLowerCase(),
    _unescape(parts[3]),
    line,
    message,
  );
}

/// Machine format escapes `\` as `\\` and `|` as `\|`.
String _unescape(String s) =>
    s.replaceAllMapped(RegExp(r'\\(.)'), (m) => m[1]!);
