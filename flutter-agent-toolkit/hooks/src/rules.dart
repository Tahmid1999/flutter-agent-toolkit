import 'config.dart';
import 'util.dart';

/// Deprecated or removed Flutter APIs that agents often write from stale
/// training data, mapped to the modern replacement.
const deprecatedApis = <String, String>{
  r'\.withOpacity\(':
      '.withOpacity(x) is deprecated. Use .withValues(alpha: x).',
  r'\bWillPopScope\b':
      'WillPopScope is deprecated. Use PopScope(canPop: ..., '
      'onPopInvokedWithResult: (didPop, result) {...}).',
  r'\bonPopInvoked\s*:':
      'onPopInvoked is deprecated. Use onPopInvokedWithResult: '
      '(didPop, result) {...}.',
  r'\bMaterialStateProperty':
      'MaterialStateProperty* is deprecated. Use WidgetStateProperty* '
      '(same API).',
  r'\bMaterialState\.': 'MaterialState is deprecated. Use WidgetState.',
  r'\btextScaleFactor\b':
      'textScaleFactor is deprecated. Use textScaler: TextScaler.linear(x) '
      'or MediaQuery.textScalerOf(context).',
  r'colorScheme\.background\b':
      'ColorScheme.background is deprecated. Use colorScheme.surface.',
  r'colorScheme\.onBackground\b':
      'ColorScheme.onBackground is deprecated. Use colorScheme.onSurface.',
  r'colorScheme\.surfaceVariant\b':
      'ColorScheme.surfaceVariant is deprecated. Use '
      'colorScheme.surfaceContainerHighest.',
  r'textTheme\.(headline[1-6]|subtitle[12]|bodyText[12]|caption|button|overline)\b':
      'Old TextTheme names were removed. Use displayLarge/Medium/Small, '
      'headlineMedium/Small, titleLarge/Medium/Small, bodyLarge/Medium/'
      'Small, labelLarge/Small.',
  r'\b(RaisedButton|FlatButton|OutlineButton)\b':
      'Removed widget. Use ElevatedButton, TextButton or OutlinedButton.',
  r'Scaffold\.of\([^)]*\)\.showSnackBar':
      'Scaffold.of(context).showSnackBar was removed. Use '
      'ScaffoldMessenger.of(context).showSnackBar.',
  r'\bButtonBar\b': 'ButtonBar is deprecated. Use OverflowBar.',
};

final _deprecatedRegexes = {
  for (final e in deprecatedApis.entries) RegExp(e.key): e.value,
};

/// Generated files are rewritten by build_runner; never lint them.
const generatedSuffixes = [
  '.g.dart',
  '.freezed.dart',
  '.gr.dart',
  '.mocks.dart',
  '.config.dart',
];

bool isGenerated(String path) => generatedSuffixes.any(path.endsWith);

/// Source that build_runner must regenerate after it changes.
final codegenMarker = RegExp(
  r'''^part\s+['"][^'"]+\.(g|freezed|gr|config|mocks)\.dart['"]|'''
  r'@(freezed|Freezed|JsonSerializable|riverpod|Riverpod|RoutePage|'
  r'AutoRouterConfig|injectable|Injectable|DriftDatabase|DriftAccessor|'
  r'GenerateMocks|GenerateNiceMocks|HiveType|Collection|RestApi)\b',
  multiLine: true,
);

class Finding {
  Finding(this.kind, this.line, this.message);

  /// `deprecated` or `banned`.
  final String kind;
  final int line;
  final String message;

  @override
  String toString() => '- [$kind] line $line: $message';
}

/// Scans [content] for deprecated Flutter APIs and team-banned APIs.
List<Finding> scanSource(String content, String relPath, ToolkitConfig config) {
  final findings = <Finding>[];
  final banned = config.bannedApis.where((b) => b.appliesTo(relPath)).toList();
  final lines = maskNonCode(content).split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('import ')) continue;
    if (config.checkDeprecated) {
      for (final MapEntry(:key, :value) in _deprecatedRegexes.entries) {
        if (key.hasMatch(line)) {
          findings.add(Finding('deprecated', i + 1, value));
        }
      }
    }
    for (final rule in banned) {
      if (rule.pattern.hasMatch(line)) {
        findings.add(Finding('banned', i + 1, rule.message));
      }
    }
  }
  return findings;
}

/// Replaces comments and string-literal contents with spaces, keeping line
/// breaks, so rules only match real code. The quotes themselves are kept, so
/// `Text('...')` still reads as a call with a string argument.
String maskNonCode(String src) {
  final out = StringBuffer();
  var i = 0;
  void blank(int end) {
    for (; i < end && i < src.length; i++) {
      out.write(src[i] == '\n' ? '\n' : ' ');
    }
  }

  while (i < src.length) {
    final c = src[i];
    final next = i + 1 < src.length ? src[i + 1] : '';
    if (c == '/' && next == '/') {
      final end = src.indexOf('\n', i);
      blank(end == -1 ? src.length : end);
    } else if (c == '/' && next == '*') {
      final end = src.indexOf('*/', i + 2);
      blank(end == -1 ? src.length : end + 2);
    } else if (c == "'" || c == '"') {
      final raw = i > 0 && src[i - 1] == 'r';
      final triple = src.startsWith(c * 3, i);
      final quote = triple ? c * 3 : c;
      out.write(quote);
      i += quote.length;
      while (i < src.length && !src.startsWith(quote, i)) {
        if (!triple && src[i] == '\n') break;
        if (!raw && src[i] == r'\' && i + 1 < src.length) {
          out.write('  ');
          i += 2;
          continue;
        }
        out.write(src[i] == '\n' ? '\n' : ' ');
        i++;
      }
      if (src.startsWith(quote, i)) {
        out.write(quote);
        i += quote.length;
      }
    } else {
      out.write(c);
      i++;
    }
  }
  return out.toString();
}

String findingsReport(String path, List<Finding> findings, {int max = 25}) {
  final shown = findings.take(max).join('\n');
  final more = findings.length > max
      ? '\n...and ${findings.length - max} more.'
      : '';
  return 'flutter-agent-toolkit: $path has ${plural(findings.length, 'problem')}. '
      'Fix before moving on.\n$shown$more';
}
