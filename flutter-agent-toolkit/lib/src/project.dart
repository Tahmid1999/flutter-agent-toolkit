import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'util.dart';

/// Walks up from [dir] to the nearest folder containing pubspec.yaml.
String? findPubspecRoot(String dir) {
  var current = Directory(dir).absolute;
  while (true) {
    if (File(join(current.path, 'pubspec.yaml')).existsSync()) {
      return current.path;
    }
    final parent = current.parent;
    if (parent.path == current.path) return null;
    current = parent;
  }
}

bool isFlutterPubspec(String pubspec) =>
    RegExp(r'^\s+sdk:\s*flutter\b', multiLine: true).hasMatch(pubspec);

/// Flutter projects at [cwd] or up to two folders below it (monorepos,
/// `app/` or `flutter/` subfolders).
List<String> findFlutterProjects(String cwd) {
  const skip = {
    'build',
    'node_modules',
    'android',
    'ios',
    'web',
    'macos',
    'windows',
    'linux',
    'test',
    'lib',
    'assets',
  };
  final found = <String>[];
  void visit(Directory dir, int depth) {
    if (found.length >= 5) return;
    final pubspec = File(join(dir.path, 'pubspec.yaml'));
    if (pubspec.existsSync() && isFlutterPubspec(pubspec.readAsStringSync())) {
      found.add(dir.path);
    }
    if (depth == 0) return;
    final List<FileSystemEntity> children;
    try {
      children = dir.listSync();
    } on FileSystemException {
      return;
    }
    for (final child in children.whereType<Directory>()) {
      final name = child.uri.pathSegments.where((s) => s.isNotEmpty).last;
      if (name.startsWith('.') || skip.contains(name)) continue;
      visit(child, depth - 1);
    }
  }

  visit(Directory(cwd), 2);
  return found;
}

/// Dependency names from the `dependencies` and `dev_dependencies` sections.
Set<String> readDependencies(String pubspec) {
  final deps = <String>{};
  var inDeps = false;
  for (final line in LineSplitter.split(pubspec)) {
    if (line.trim().isEmpty || line.trimLeft().startsWith('#')) continue;
    if (!line.startsWith(' ')) {
      inDeps = line.startsWith('dependencies:') ||
          line.startsWith('dev_dependencies:');
      continue;
    }
    final m = RegExp(r'^  ([a-z0-9_]+):').firstMatch(line);
    if (inDeps && m != null) deps.add(m[1]!);
  }
  return deps;
}

const stackCategories = <String, List<String>>{
  'State management': [
    'flutter_riverpod',
    'hooks_riverpod',
    'riverpod',
    'flutter_bloc',
    'bloc',
    'provider',
    'get',
    'flutter_mobx',
    'signals',
    'stacked',
    'flutter_redux',
  ],
  'Navigation': ['go_router', 'auto_route', 'beamer'],
  'Code generation': [
    'freezed',
    'json_serializable',
    'riverpod_generator',
    'auto_route_generator',
    'injectable_generator',
    'drift_dev',
    'retrofit_generator',
    'hive_ce_generator',
    'mockito',
  ],
  'Networking': ['dio', 'http', 'retrofit', 'chopper', 'graphql_flutter'],
  'Local storage': [
    'shared_preferences',
    'flutter_secure_storage',
    'hive',
    'hive_ce',
    'isar',
    'drift',
    'sqflite',
    'objectbox',
  ],
  'Dependency injection': ['get_it', 'injectable'],
  'Backend': [
    'firebase_core',
    'supabase_flutter',
    'amplify_flutter',
    'appwrite',
  ],
  'Localization': ['flutter_localizations', 'easy_localization', 'slang'],
  'Testing': ['mocktail', 'mockito', 'bloc_test', 'patrol', 'alchemist'],
  'Lints': ['very_good_analysis', 'flutter_lints', 'lints', 'lint'],
};

/// Short facts about a Flutter project, for the agent's context.
class ProjectInfo {
  ProjectInfo(this.root, this.cwd);
  final String root;
  final String cwd;
  String name = '';
  final stack = <String, List<String>>{};
  final platforms = <String>[];
  final libFolders = <String>[];
  String? fvmVersion;
  bool usesBuildRunner = false;
  bool hasL10nYaml = false;
  bool isWorkspace = false;
  late final ToolkitConfig config = ToolkitConfig.load(root);

  static ProjectInfo read(String root, String cwd) {
    final info = ProjectInfo(root, cwd);
    final pubspec = File(join(root, 'pubspec.yaml')).readAsStringSync();
    info.name =
        RegExp(r'^name:\s*(\S+)', multiLine: true).firstMatch(pubspec)?[1] ??
            '';
    final deps = readDependencies(pubspec);
    for (final MapEntry(:key, :value) in stackCategories.entries) {
      final hits = value.where(deps.contains).toList();
      if (hits.isNotEmpty) info.stack[key] = hits;
    }
    info.usesBuildRunner = deps.contains('build_runner');
    info.isWorkspace =
        RegExp(r'^workspace:', multiLine: true).hasMatch(pubspec) ||
            File(join(root, 'melos.yaml')).existsSync();
    for (final p in ['android', 'ios', 'web', 'macos', 'windows', 'linux']) {
      if (Directory(join(root, p)).existsSync()) info.platforms.add(p);
    }
    final lib = Directory(join(root, 'lib'));
    if (lib.existsSync()) {
      info.libFolders.addAll(
        lib
            .listSync()
            .whereType<Directory>()
            .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
            .take(12),
      );
    }
    info.hasL10nYaml = File(join(root, 'l10n.yaml')).existsSync();
    final fvmrc = File(join(root, '.fvmrc'));
    if (fvmrc.existsSync()) {
      try {
        info.fvmVersion =
            (jsonDecode(fvmrc.readAsStringSync()) as Map)['flutter'] as String?;
      } on Object {
        info.fvmVersion = '?';
      }
    }
    return info;
  }

  String get displayPath {
    final rel = relativePath(root, cwd);
    return rel == root.replaceAll(r'\', '/')
        ? root
        : (rel.isEmpty ? './' : '$rel/');
  }

  /// One-line status for the user.
  String get headline {
    final parts = [name];
    final sdk = sdkVersions();
    if (fvmVersion != null) {
      parts.add('Flutter $fvmVersion (FVM)');
    } else if (sdk.flutter != null) {
      parts.add('Flutter ${sdk.flutter}');
    }
    for (final key in ['State management', 'Navigation']) {
      if (stack[key] case final hits?) parts.add(hits.first);
    }
    return parts.join(' · ');
  }

  String describe() {
    final sdk = sdkVersions();
    final b = StringBuffer('Flutter project: $displayPath ($name)\n');
    if (fvmVersion != null) {
      b.writeln(
        '- SDK: FVM pins Flutter $fvmVersion. Run Flutter commands as '
        '`fvm flutter ...` and `fvm dart ...`.',
      );
    } else if (sdk.flutter != null) {
      b.writeln(
        '- SDK: Flutter ${sdk.flutter} · Dart ${sdk.dart ?? '?'}. Write '
        'code for this version.',
      );
    }
    if (platforms.isNotEmpty) b.writeln('- Platforms: ${platforms.join(', ')}');
    for (final MapEntry(:key, :value) in stack.entries) {
      b.writeln('- $key: ${value.join(', ')}');
    }
    if (hasL10nYaml) b.writeln('- Localization: gen-l10n (l10n.yaml)');
    if (libFolders.isNotEmpty) {
      final featureFirst = libFolders.contains('features');
      b.writeln(
        '- lib/ layout: ${libFolders.map((f) => '$f/').join(', ')}'
        '${featureFirst ? ' (feature-first)' : ''}',
      );
    }
    if (isWorkspace) {
      b.writeln(
        '- Monorepo / pub workspace: run commands in the right package.',
      );
    }
    if (config.exists) {
      b.writeln(
        '- Team rules (${ToolkitConfig.fileName}): strictness '
        '${config.strictness.name}.',
      );
      for (final rule in config.bannedApis) {
        final scope =
            rule.paths.isEmpty ? '' : ' (in ${rule.paths.join(', ')})';
        b.writeln('  - Banned `${rule.source}`$scope: ${rule.message}');
      }
      for (final error in config.errors) {
        b.writeln('  - Config problem: $error');
      }
    }
    return b.toString();
  }
}

/// Flutter and Dart versions of the Flutter SDK on PATH, read from files so
/// no slow `flutter --version` call is needed.
({String? flutter, String? dart}) sdkVersions() {
  final path = Platform.environment['PATH'] ?? '';
  final names = Platform.isWindows ? ['flutter.bat', 'flutter'] : ['flutter'];
  for (final dir in path.split(Platform.isWindows ? ';' : ':')) {
    if (dir.isEmpty) continue;
    if (!names.any((n) => File(join(dir, n)).existsSync())) continue;
    final root = Directory(dir).parent.path;
    String? flutter;
    final versionJson = File(join(root, 'bin/cache/flutter.version.json'));
    if (versionJson.existsSync()) {
      try {
        flutter = (jsonDecode(versionJson.readAsStringSync())
            as Map)['frameworkVersion'] as String?;
      } on Object {
        flutter = null;
      }
    }
    final legacy = File(join(root, 'version'));
    if (flutter == null && legacy.existsSync()) {
      flutter = legacy.readAsStringSync().trim();
    }
    final dartFile = File(join(root, 'bin/cache/dart-sdk/version'));
    final dart =
        dartFile.existsSync() ? dartFile.readAsStringSync().trim() : null;
    return (flutter: flutter, dart: dart);
  }
  return (flutter: null, dart: null);
}
