import 'dart:convert';
import 'dart:io';

import 'util.dart';

enum Strictness { errors, warnings, all }

/// A team rule from `banned_apis` in .flutter-toolkit.yaml.
class BannedApi {
  BannedApi(this.source, this.pattern, this.message, this.paths, this.exclude);
  final String source;
  final RegExp pattern;
  final String message;
  final List<String> paths;
  final List<String> exclude;

  bool appliesTo(String relPath) =>
      (paths.isEmpty || paths.any(relPath.startsWith)) &&
      !exclude.any(relPath.startsWith);
}

/// Per-project settings from `.flutter-toolkit.yaml` at the project root.
/// Every key is optional.
class ToolkitConfig {
  static const fileName = '.flutter-toolkit.yaml';

  bool exists = false;
  Strictness strictness = Strictness.warnings;
  bool autoFormat = true;
  bool autoBuildRunner = true;
  bool checkDeprecated = true;
  bool summary = true;
  int maxFixRounds = 3;
  final ignoreCodes = <String>{};
  final bannedApis = <BannedApi>[];
  final errors = <String>[];

  static final _cache = <String, ToolkitConfig>{};

  static ToolkitConfig load(String? projectRoot) {
    if (projectRoot == null) return ToolkitConfig();
    return _cache.putIfAbsent(projectRoot, () {
      final config = ToolkitConfig();
      final file = File(join(projectRoot, fileName));
      if (!file.existsSync()) return config;
      config.exists = true;
      try {
        config._apply(parseSimpleYaml(file.readAsStringSync()));
      } on Object catch (e) {
        config.errors.add('Could not read $fileName: $e');
      }
      return config;
    });
  }

  void _apply(Map<String, Object?> yaml) {
    for (final MapEntry(:key, :value) in yaml.entries) {
      switch (key) {
        case 'strictness':
          final s = Strictness.values.where((v) => v.name == value);
          if (s.isEmpty) {
            errors.add('strictness must be errors, warnings or all');
          } else {
            strictness = s.first;
          }
        case 'auto_format':
          autoFormat = value != false;
        case 'auto_build_runner':
          autoBuildRunner = value != false;
        case 'check_deprecated':
          checkDeprecated = value != false;
        case 'summary':
          summary = value != false;
        case 'max_fix_rounds':
          if (value is int && value >= 0) maxFixRounds = value;
        case 'ignore_codes':
          if (value is List)
            ignoreCodes.addAll(value.map((v) => '$v'.toLowerCase()));
        case 'banned_apis':
          if (value is List) value.whereType<Map>().forEach(_addBanned);
        default:
          errors.add('Unknown key "$key"');
      }
    }
  }

  void _addBanned(Map item) {
    final pattern = item['pattern'];
    if (pattern is! String || pattern.isEmpty) {
      errors.add('banned_apis entry without a pattern');
      return;
    }
    final RegExp regex;
    try {
      regex = RegExp(pattern);
    } on FormatException catch (e) {
      errors.add('Invalid banned_apis pattern "$pattern": ${e.message}');
      return;
    }
    List<String> list(Object? v) => v is List
        ? v.map((e) => '$e').toList()
        : v is String
        ? [v]
        : [];
    bannedApis.add(
      BannedApi(
        pattern,
        regex,
        '${item['message'] ?? 'Banned by team rules.'}',
        list(item['paths']),
        list(item['exclude']),
      ),
    );
  }
}

/// Parses the small YAML subset used by .flutter-toolkit.yaml: top-level
/// scalars, inline lists, and a list of maps. Avoids a package dependency so
/// the hook runs with only the Dart SDK.
Map<String, Object?> parseSimpleYaml(String text) {
  final result = <String, Object?>{};
  List<Object?>? list;
  Map<String, Object?>? item;
  for (final raw in LineSplitter.split(text)) {
    final line = _stripComment(raw);
    if (line.trim().isEmpty) continue;
    final indent = line.length - line.trimLeft().length;
    final trimmed = line.trim();
    if (indent == 0) {
      final kv = _splitKeyValue(trimmed);
      if (kv == null) continue;
      if (kv.$2.isEmpty) {
        list = [];
        item = null;
        result[kv.$1] = list;
      } else {
        list = null;
        result[kv.$1] = _parseScalar(kv.$2);
      }
      continue;
    }
    if (list == null) continue;
    var body = trimmed;
    if (body == '-' || body.startsWith('- ')) {
      body = body.substring(1).trim();
      final kv = body.isEmpty ? null : _splitKeyValue(body);
      if (body.isNotEmpty && kv == null) {
        list.add(_parseScalar(body));
        item = null;
        continue;
      }
      item = {};
      list.add(item);
      if (kv == null) continue;
      item[kv.$1] = _parseScalar(kv.$2);
    } else if (item != null) {
      final kv = _splitKeyValue(body);
      if (kv != null) item[kv.$1] = _parseScalar(kv.$2);
    }
  }
  return result;
}

String _stripComment(String line) {
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quote != null) {
      if (c == quote) quote = null;
    } else if (c == "'" || c == '"') {
      quote = c;
    } else if (c == '#' &&
        (i == 0 || line[i - 1] == ' ' || line[i - 1] == '\t')) {
      return line.substring(0, i);
    }
  }
  return line;
}

(String, String)? _splitKeyValue(String s) {
  String? quote;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (quote != null) {
      if (c == quote) quote = null;
    } else if (c == "'" || c == '"') {
      quote = c;
    } else if (c == ':' && (i == s.length - 1 || s[i + 1] == ' ')) {
      return (s.substring(0, i).trim(), s.substring(i + 1).trim());
    }
  }
  return null;
}

Object? _parseScalar(String v) {
  if (v.isEmpty) return null;
  if (v.startsWith("'") && v.endsWith("'") && v.length >= 2) {
    return v.substring(1, v.length - 1).replaceAll("''", "'");
  }
  if (v.startsWith('"') && v.endsWith('"') && v.length >= 2) {
    return v
        .substring(1, v.length - 1)
        .replaceAllMapped(
          RegExp(r'\\(.)'),
          (m) => switch (m[1]) {
            'n' => '\n',
            't' => '\t',
            final c => c!,
          },
        );
  }
  if (v.startsWith('[') && v.endsWith(']')) {
    final inner = v.substring(1, v.length - 1);
    final parts = <String>[];
    String? quote;
    var start = 0;
    for (var i = 0; i < inner.length; i++) {
      final c = inner[i];
      if (quote != null) {
        if (c == quote) quote = null;
      } else if (c == "'" || c == '"') {
        quote = c;
      } else if (c == ',') {
        parts.add(inner.substring(start, i));
        start = i + 1;
      }
    }
    parts.add(inner.substring(start));
    return parts
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map(_parseScalar)
        .toList();
  }
  if (v == 'true') return true;
  if (v == 'false') return false;
  return int.tryParse(v) ?? v;
}
