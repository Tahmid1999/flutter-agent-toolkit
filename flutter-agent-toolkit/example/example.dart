// Uses the flutter_agent_toolkit rules engine directly.
//
// Most people use the CLI instead:
//   dart pub global activate flutter_agent_toolkit
//   flutter_agent_toolkit check
import 'package:flutter_agent_toolkit/flutter_agent_toolkit.dart';

void main() {
  const source = '''
import 'package:flutter/material.dart';

Widget badge() {
  print('building badge'); // team rule: no print
  return Container(color: Colors.red.withOpacity(0.5));
}
''';

  // Team rules normally come from .flutter-toolkit.yaml in the project root.
  final config = ToolkitConfig()
    ..bannedApis.add(BannedApi(
      r'\bprint\(',
      RegExp(r'\bprint\('),
      'Use the app logger instead of print.',
      const [],
      const ['test/'],
    ));

  for (final finding in scanSource(source, 'lib/badge.dart', config)) {
    print(finding);
  }
  // - [banned] line 4: Use the app logger instead of print.
  // - [deprecated] line 5: .withOpacity(x) is deprecated. Use .withValues(alpha: x).
}
