import 'dart:convert';
import 'dart:io';

/// Reads the hook payload Claude Code sends on stdin.
Future<Map<String, dynamic>> readPayload() async {
  try {
    final raw = await stdin.transform(utf8.decoder).join();
    return jsonDecode(raw) as Map<String, dynamic>;
  } on FormatException {
    return {};
  }
}

/// Persistent plugin data folder (survives plugin updates). Falls back to
/// the system temp folder on Claude Code versions without CLAUDE_PLUGIN_DATA.
Directory dataDir() {
  final env = Platform.environment['CLAUDE_PLUGIN_DATA'];
  final dir = Directory(
    env != null && env.isNotEmpty
        ? env
        : '${Directory.systemTemp.path}${Platform.pathSeparator}flutter-agent-toolkit',
  );
  dir.createSync(recursive: true);
  return dir;
}

/// Folder holding this plugin's files.
String pluginRoot() {
  final env = Platform.environment['CLAUDE_PLUGIN_ROOT'];
  if (env != null && env.isNotEmpty) return env;
  // Script mode: <root>/hooks/toolkit.dart
  return File.fromUri(Platform.script).parent.parent.path;
}

String join(String a, String b) => a.endsWith('/') || a.endsWith(r'\')
    ? '$a$b'
    : '$a${Platform.pathSeparator}$b';

/// Forward-slash path of [path] relative to [root], for display and rule
/// matching.
String relativePath(String path, String root) {
  final p = path.replaceAll(r'\', '/');
  final r = root.replaceAll(r'\', '/');
  final prefix = r.endsWith('/') ? r : '$r/';
  return p.toLowerCase().startsWith(prefix.toLowerCase())
      ? p.substring(prefix.length)
      : p;
}

/// Runs the dart CLI. When this tool runs as a compiled exe,
/// Platform.resolvedExecutable is the exe itself, so use `dart` from PATH.
Future<ProcessResult> runDart(List<String> args, {String? cwd}) {
  final exe = Platform.resolvedExecutable;
  final name = exe.split(RegExp(r'[\\/]')).last.toLowerCase();
  if (name == 'dart' || name == 'dart.exe') {
    return Process.run(exe, args, workingDirectory: cwd);
  }
  return Process.run(
    'dart',
    args,
    workingDirectory: cwd,
    runInShell: Platform.isWindows,
  );
}

const dartMissing = "flutter-agent-toolkit: could not run 'dart'. "
    "Add your Flutter SDK's bin folder to PATH to enable Flutter checks.";

/// Prints a message the user sees in the transcript.
void printSystemMessage(
  String message, {
  Map<String, Object?> extra = const {},
}) {
  stdout.writeln(jsonEncode({'systemMessage': message, ...extra}));
}

String plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';
