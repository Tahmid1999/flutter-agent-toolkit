import 'dart:convert';
import 'dart:io';

import 'util.dart';

/// Per-session state shared between hook runs. PostToolUse hooks can run in
/// parallel, so edits are appended as single lines instead of rewriting JSON.
class SessionLog {
  SessionLog(String sessionId) {
    final id = sessionId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final dir = Directory(join(dataDir().path, 'sessions'))
      ..createSync(recursive: true);
    _log = File(join(dir.path, '$id.log'));
    _rounds = File(join(dir.path, '$id.rounds'));
  }

  late final File _log;
  late final File _rounds;

  void add(List<String> fields) => _log.writeAsStringSync(
        '${fields.join('\t')}\n',
        mode: FileMode.append,
        flush: true,
      );

  void recordEdit(String path) => add(['edit', path]);
  void recordCodegen(String path) => add(['codegen', path]);
  void recordCaught(String kind, int count) => add(['caught', kind, '$count']);
  void recordBuilt() => add(['built']);

  SessionState read() {
    final state = SessionState();
    if (!_log.existsSync()) return state;
    for (final line in _log.readAsLinesSync()) {
      final f = line.split('\t');
      switch (f) {
        case ['edit', final path]:
          state.edits.add(path);
        case ['codegen', final path]:
          state.codegen.add(path);
        case ['built']:
          // build_runner already ran for the codegen edits above.
          state.codegen.clear();
          state.buildRunnerRan = true;
        case ['caught', final kind, final n]:
          state.caught[kind] =
              (state.caught[kind] ?? 0) + (int.tryParse(n) ?? 0);
      }
    }
    return state;
  }

  int get rounds =>
      _rounds.existsSync() ? int.tryParse(_rounds.readAsStringSync()) ?? 0 : 0;
  set rounds(int value) => _rounds.writeAsStringSync('$value');

  void clear() {
    for (final f in [_log, _rounds]) {
      if (f.existsSync()) f.deleteSync();
    }
  }

  /// Removes logs of sessions older than a week.
  static void prune() {
    final dir = Directory(join(dataDir().path, 'sessions'));
    if (!dir.existsSync()) return;
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    for (final f in dir.listSync().whereType<File>()) {
      try {
        if (f.lastModifiedSync().isBefore(cutoff)) f.deleteSync();
      } on FileSystemException {
        // In use by another session; try next time.
      }
    }
  }
}

class SessionState {
  final edits = <String>{};
  final codegen = <String>{};
  final caught = <String, int>{};
  bool buildRunnerRan = false;
}

/// All-time count of problems caught, for the summary line.
int addToLifetimeTotal(int caught) {
  final file = File(join(dataDir().path, 'stats.json'));
  var total = 0;
  try {
    if (file.existsSync()) {
      total =
          (jsonDecode(file.readAsStringSync()) as Map)['caught'] as int? ?? 0;
    }
  } on Object {
    total = 0;
  }
  total += caught;
  try {
    file.writeAsStringSync(jsonEncode({'caught': total}));
  } on FileSystemException {
    // Stats are nice to have.
  }
  return total;
}
