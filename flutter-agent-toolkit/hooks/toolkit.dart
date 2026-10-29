// flutter-agent-toolkit hook engine.
//
//   session-start  Detect Flutter projects, give the agent the stack, and
//                  compile this tool to a native exe for fast later runs.
//   post-edit      After each .dart edit: instant deprecated/banned API scan.
//   stop           When the agent finishes: build_runner if needed, one
//                  `dart analyze` over changed files, send problems back,
//                  format, and show a summary.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'src/analyzer.dart';
import 'src/config.dart';
import 'src/project.dart';
import 'src/rules.dart';
import 'src/session.dart';
import 'src/util.dart';

Future<void> main(List<String> args) async {
  final payload = await readPayload();
  try {
    switch (args.isEmpty ? '' : args.first) {
      case 'session-start':
        await sessionStart(payload);
      case 'post-edit':
        postEdit(payload);
      case 'stop':
        await stop(payload);
      default:
        stderr.writeln('usage: toolkit <session-start|post-edit|stop>');
        exitCode = 1;
    }
  } on ProcessException {
    stderr.writeln(dartMissing);
  } on Object catch (e) {
    // Never block the agent because of a bug in this tool.
    stderr.writeln('flutter-agent-toolkit internal error: $e');
    exitCode = 1;
  }
}

const _guidance = '''
Follow this stack. Never add a competing state management, router, HTTP or DI library.
Use the modern-flutter skill before writing Flutter code, and flutter-build-fixer for native build errors.
Automatic checks: deprecated and team-banned APIs are reported right after each Dart edit. When you finish, changed files are analyzed (build_runner runs first if needed) and any problems are sent back to you to fix.''';

Future<void> sessionStart(Map<String, dynamic> payload) async {
  SessionLog.prune();
  final cwd = payload['cwd'] as String? ?? Directory.current.path;
  final projects = findFlutterProjects(cwd);
  if (projects.isEmpty) return;

  await ensureCompiled();

  final infos = [for (final p in projects) ProjectInfo.read(p, cwd)];
  final context = StringBuffer('## Flutter (flutter-agent-toolkit)\n');
  for (final info in infos) {
    context.writeln(info.describe());
  }
  context.writeln(_guidance);

  final message = infos.length == 1
      ? 'Flutter toolkit ready · ${infos.first.headline}'
      : 'Flutter toolkit ready · ${infos.length} Flutter projects';
  stdout.writeln(
    jsonEncode({
      'systemMessage': message,
      'hookSpecificOutput': {
        'hookEventName': 'SessionStart',
        'additionalContext': context.toString(),
      },
    }),
  );
}

void postEdit(Map<String, dynamic> payload) {
  final toolInput = payload['tool_input'] as Map<String, dynamic>? ?? {};
  final path = toolInput['file_path'] as String?;
  if (path == null || !path.endsWith('.dart') || isGenerated(path)) return;
  final file = File(path);
  if (!file.existsSync()) return;

  final root = findPubspecRoot(file.parent.path);
  final config = ToolkitConfig.load(root);
  final content = file.readAsStringSync();
  final log = SessionLog(payload['session_id'] as String? ?? 'unknown');
  log.recordEdit(path);
  if (codegenMarker.hasMatch(content)) log.recordCodegen(path);

  final rel = root == null ? path : relativePath(path, root);
  final findings = scanSource(content, rel, config);
  if (findings.isEmpty) return;
  for (final kind in ['deprecated', 'banned']) {
    final n = findings.where((f) => f.kind == kind).length;
    if (n > 0) log.recordCaught(kind, n);
  }
  stderr.writeln(findingsReport(rel, findings));
  exitCode = 2;
}

Future<void> stop(Map<String, dynamic> payload) async {
  final log = SessionLog(payload['session_id'] as String? ?? 'unknown');
  if (payload['stop_hook_active'] != true) log.rounds = 0;
  final state = log.read();
  final files = state.edits
      .where((p) => !isGenerated(p) && File(p).existsSync())
      .toList();
  if (files.isEmpty) {
    log.clear();
    return;
  }

  final byRoot = <String?, List<String>>{};
  for (final f in files) {
    byRoot.putIfAbsent(findPubspecRoot(File(f).parent.path), () => []).add(f);
  }

  final report = <String, List<String>>{}; // display path -> problem lines
  final general = <String>[];
  var analyzerCount = 0;
  var buildRunnerRan = state.buildRunnerRan;
  var maxRounds = 0;

  for (final MapEntry(key: root, value: rootFiles) in byRoot.entries) {
    final config = ToolkitConfig.load(root);
    maxRounds = max(maxRounds, config.maxFixRounds);
    String display(String p) => root == null ? p : relativePath(p, root);

    if (root != null &&
        config.autoBuildRunner &&
        rootFiles.any(state.codegen.contains) &&
        readDependencies(
          File(join(root, 'pubspec.yaml')).readAsStringSync(),
        ).contains('build_runner')) {
      buildRunnerRan = true;
      log.recordBuilt();
      final r = await runDart([
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ], cwd: root);
      if (r.exitCode != 0) {
        final out = LineSplitter.split(
          '${r.stdout}\n${r.stderr}',
        ).where((l) => l.trim().isNotEmpty).toList();
        general.add(
          'build_runner failed in ${root.replaceAll(r'\', '/')}:\n'
          '${out.skip(max(0, out.length - 15)).join('\n')}',
        );
      }
    }

    final flagged = <String>{}; // "path:line" already reported by the scan
    for (final f in rootFiles) {
      final findings = scanSource(
        File(f).readAsStringSync(),
        display(f),
        config,
      );
      for (final finding in findings) {
        report.putIfAbsent(display(f), () => []).add('$finding');
        flagged.add('${_norm(f)}:${finding.line}');
      }
    }

    if (root != null) {
      for (final issue in await analyzeFiles(root, rootFiles, config)) {
        if (issue.code.startsWith('deprecated_member_use') &&
            flagged.contains('${_norm(issue.path)}:${issue.line}')) {
          continue;
        }
        analyzerCount++;
        report
            .putIfAbsent(display(issue.path), () => [])
            .add(
              '- [${issue.severity.toLowerCase()}] line ${issue.line}: '
              '${issue.message} (${issue.code})',
            );
      }
    }
  }

  final problemCount =
      report.values.fold(0, (n, l) => n + l.length) + general.length;
  final details = [
    ...general,
    for (final MapEntry(:key, :value) in report.entries)
      '$key\n${value.take(20).join('\n')}'
          '${value.length > 20 ? '\n...and ${value.length - 20} more.' : ''}',
  ].join('\n\n');

  if (problemCount > 0 && log.rounds < maxRounds) {
    log.rounds = log.rounds + 1;
    if (log.rounds == 1) log.recordCaught('analyzer', analyzerCount);
    stdout.writeln(
      jsonEncode({
        'decision': 'block',
        'reason':
            'flutter-agent-toolkit found '
            '${plural(problemCount, 'problem')} in files you changed. '
            'Fix them, then finish.\n\n$details',
        'systemMessage':
            'Flutter toolkit: ${plural(problemCount, 'problem')} '
            'in changed files, sent back to Claude '
            '(round ${log.rounds}/$maxRounds)',
      }),
    );
    return;
  }

  var formatted = 0;
  for (final MapEntry(key: root, value: rootFiles) in byRoot.entries) {
    if (!ToolkitConfig.load(root).autoFormat) continue;
    final r = await runDart(['format', ...rootFiles], cwd: root);
    final m = RegExp(r'\((\d+) changed\)').firstMatch('${r.stdout}');
    formatted += int.tryParse(m?[1] ?? '') ?? 0;
  }

  final caught = state.caught.values.fold(0, (a, b) => a + b);
  final lifetime = addToLifetimeTotal(caught);
  log.clear();

  if (problemCount > 0) {
    final firstLines = LineSplitter.split(details).take(12).join('\n');
    stdout.writeln(
      jsonEncode({
        'systemMessage':
            '⚠ Flutter toolkit: ${plural(problemCount, 'problem')} '
            'left in changed files'
            '${maxRounds > 0 ? ' after $maxRounds fix rounds' : ''}:\n$firstLines',
      }),
    );
    return;
  }
  if (!byRoot.keys.any((r) => ToolkitConfig.load(r).summary)) return;

  final parts = [
    'Flutter toolkit ✓ ${plural(files.length, 'Dart file')} checked',
  ];
  final caughtParts = [
    if ((state.caught['deprecated'] ?? 0) > 0)
      plural(state.caught['deprecated']!, 'deprecated API'),
    if ((state.caught['banned'] ?? 0) > 0)
      plural(state.caught['banned']!, 'banned API'),
    if ((state.caught['analyzer'] ?? 0) > 0)
      plural(state.caught['analyzer']!, 'analyzer issue'),
  ];
  parts.add(
    caughtParts.isEmpty
        ? 'analyzer clean'
        : 'caught ${caughtParts.join(', ')}, all fixed',
  );
  if (buildRunnerRan) parts.add('build_runner ran');
  if (formatted > 0) parts.add('${plural(formatted, 'file')} formatted');
  if (lifetime > 0) parts.add('$lifetime caught all-time');
  printSystemMessage(parts.join(' · '));
}

String _norm(String path) => path.replaceAll(r'\', '/').toLowerCase();

/// Compiles this tool to `${CLAUDE_PLUGIN_DATA}/toolkit.exe` when the
/// sources changed. Hook commands use the exe when present: ~0.2s startup
/// instead of ~1s for `dart toolkit.dart`.
Future<void> ensureCompiled() async {
  final data = Platform.environment['CLAUDE_PLUGIN_DATA'];
  if (data == null || data.isEmpty) return;
  _deleteOldExes(data);
  final hooks = Directory(join(pluginRoot(), 'hooks'));
  if (!hooks.existsSync()) return;
  final sources =
      hooks
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  var hash = 0xcbf29ce484222325; // FNV-1a
  for (final source in sources) {
    for (final byte in source.readAsBytesSync()) {
      hash = (hash ^ byte) * 0x100000001b3;
    }
  }
  final key = hash.toUnsigned(64).toRadixString(16);

  final exe = File(join(data, 'toolkit.exe'));
  final stamp = File(join(data, 'toolkit.stamp'));
  if (exe.existsSync() &&
      stamp.existsSync() &&
      stamp.readAsStringSync() == key) {
    return;
  }
  final tmp = File(join(data, 'toolkit.new.exe'));
  final result = await runDart([
    'compile',
    'exe',
    join(hooks.path, 'toolkit.dart'),
    '-o',
    tmp.path,
  ]);
  if (result.exitCode != 0 || !tmp.existsSync()) return;
  try {
    // Windows cannot delete a running exe (this process may be it), but it
    // can rename one. Move it aside and delete it on a later start.
    if (exe.existsSync()) {
      exe.renameSync(join(
          data, 'toolkit.old.${DateTime.now().millisecondsSinceEpoch}.exe'));
    }
    tmp.renameSync(exe.path);
    stamp.writeAsStringSync(key);
  } on FileSystemException {
    // Retry next session start.
  }
}

void _deleteOldExes(String data) {
  for (final f in Directory(data).listSync().whereType<File>()) {
    if (!f.uri.pathSegments.last.startsWith('toolkit.old.')) continue;
    try {
      f.deleteSync();
    } on FileSystemException {
      // Still running in another session.
    }
  }
}
