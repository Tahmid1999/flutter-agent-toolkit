import 'dart:io';

import 'package:flutter_agent_toolkit/flutter_agent_toolkit.dart';

const _usage = '''
flutter_agent_toolkit $packageVersion
Makes AI coding agents write modern, analyzer-clean Flutter.

Usage: flutter_agent_toolkit <command> [path]

Commands:
  install          Install the Claude Code plugin (needs the `claude` CLI).
  check [path]     Scan Dart files for deprecated and team-banned Flutter APIs,
                   then run `dart analyze`. Exits 1 if problems are found,
                   so it works in CI and with any AI agent.
                   --no-analyze   Only run the fast API scan.
  init [path]      Create .flutter-toolkit.yaml (team rules) in the project.
  info [path]      Show the detected Flutter stack.
  help             Show this help.
  --version        Print the version.
''';

const _marketplace = 'Tahmid1999/flutter-agent-toolkit';
const _plugin = 'flutter-agent-toolkit@flutter-agent-plugins';

Future<void> main(List<String> arguments) async {
  final args = [...arguments];
  final command = args.isEmpty ? 'help' : args.removeAt(0);
  exitCode = switch (command) {
    'install' => await _install(),
    'check' => await _check(args),
    'init' => _init(args),
    'info' => _info(args),
    '--version' || '-v' || 'version' => _print(packageVersion),
    'help' || '--help' || '-h' => _print(_usage),
    _ => _fail('Unknown command "$command".\n\n$_usage'),
  };
}

int _print(String text) {
  stdout.writeln(text.trimRight());
  return 0;
}

int _fail(String text) {
  stderr.writeln(text.trimRight());
  return 64;
}

String _dir(List<String> args) =>
    args.where((a) => !a.startsWith('-')).firstOrNull ?? Directory.current.path;

Future<int> _install() async {
  Future<ProcessResult?> claude(List<String> args) async {
    try {
      return await Process.run('claude', args, runInShell: Platform.isWindows);
    } on ProcessException {
      return null;
    }
  }

  stdout.writeln('Adding marketplace $_marketplace...');
  final add = await claude(['plugin', 'marketplace', 'add', _marketplace]);
  if (add == null) {
    stderr.writeln('''
The `claude` CLI was not found. Install Claude Code (https://claude.com/claude-code),
or run these inside Claude Code:

  /plugin marketplace add $_marketplace
  /plugin install $_plugin''');
    return 1;
  }
  stdout.write(add.stdout);

  stdout.writeln('Installing $_plugin...');
  final install = await claude(['plugin', 'install', _plugin]);
  stdout.write(install?.stdout ?? '');
  if (install == null || install.exitCode != 0) {
    stderr.write(install?.stderr ?? '');
    stderr.writeln(
        'Install failed. Inside Claude Code, run: /plugin install $_plugin');
    return 1;
  }
  stdout.writeln('''

Done. Start a new Claude Code session in your Flutter project, then run
/flutter-init once to set up team rules.''');
  return 0;
}

Future<int> _check(List<String> args) async {
  final analyze = !args.contains('--no-analyze');
  final root = findPubspecRoot(_dir(args));
  if (root == null)
    return _fail('No pubspec.yaml found at or above ${_dir(args)}.');
  final config = ToolkitConfig.load(root);
  for (final error in config.errors) {
    stderr.writeln('${ToolkitConfig.fileName}: $error');
  }

  final problems = <String, List<String>>{}; // relative path -> lines
  final flagged = <String>{};
  final files = _dartFiles(root);
  for (final file in files) {
    final rel = relativePath(file.path, root);
    for (final f in scanSource(file.readAsStringSync(), rel, config)) {
      problems
          .putIfAbsent(rel, () => [])
          .add('  line ${f.line}  [${f.kind}] ${f.message}');
      flagged.add('$rel:${f.line}');
    }
  }

  if (analyze) {
    stdout.writeln('Analyzing ${files.length} Dart files...');
    for (final issue in await analyzeFiles(root, ['.'], config)) {
      final rel = relativePath(issue.path, root);
      if (isGenerated(rel)) continue;
      if (issue.code.startsWith('deprecated_member_use') &&
          flagged.contains('$rel:${issue.line}')) {
        continue;
      }
      problems
          .putIfAbsent(rel, () => [])
          .add('  line ${issue.line}  [${issue.severity.toLowerCase()}] '
              '${issue.message} (${issue.code})');
    }
  }

  if (problems.isEmpty) {
    stdout.writeln('✓ No problems in ${files.length} Dart files.');
    return 0;
  }
  final count = problems.values.fold(0, (n, l) => n + l.length);
  for (final MapEntry(:key, :value) in problems.entries) {
    stdout.writeln('\n$key');
    value.forEach(stdout.writeln);
  }
  stdout.writeln('\n$count problem${count == 1 ? '' : 's'} in '
      '${problems.length} file${problems.length == 1 ? '' : 's'}.');
  return 1;
}

int _init(List<String> args) {
  final root = findPubspecRoot(_dir(args));
  if (root == null)
    return _fail('No pubspec.yaml found at or above ${_dir(args)}.');
  final file = File('$root${Platform.pathSeparator}${ToolkitConfig.fileName}');
  if (file.existsSync()) {
    stdout
        .writeln('${ToolkitConfig.fileName} already exists. Nothing changed.');
    return 0;
  }
  file.writeAsStringSync(defaultConfigYaml);
  stdout.writeln('''
Created ${file.path}
Edit banned_apis for your team, then commit it. In Claude Code, /flutter-init
proposes rules that fit your stack.''');
  return 0;
}

int _info(List<String> args) {
  final dir = _dir(args);
  final projects = findFlutterProjects(dir);
  if (projects.isEmpty) return _fail('No Flutter project found in $dir.');
  for (final root in projects) {
    stdout.writeln(ProjectInfo.read(root, dir).describe());
  }
  return 0;
}

/// Dart sources in the usual package folders, without generated files.
List<File> _dartFiles(String root) => [
      for (final name in ['lib', 'bin', 'test', 'integration_test', 'tool'])
        if (Directory('$root/$name').existsSync())
          ...Directory('$root/$name')
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.dart') && !isGenerated(f.path)),
    ];
