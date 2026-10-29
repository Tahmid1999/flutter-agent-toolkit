## 0.3.2

- README: demo video on YouTube (https://youtu.be/GjoXf3EQJCU) with a thumbnail preview.

## 0.3.1

- README: 90-second demo video and GIF preview.
- Fixed core lint findings; added `analysis_options.yaml`.

## 0.3.0

- Published on pub.dev as `flutter_agent_toolkit`.
- New CLI (`dart pub global activate flutter_agent_toolkit`):
  - `install`: installs the Claude Code plugin
  - `check`: deprecated/banned API scan plus `dart analyze`, exits 1 on problems (CI and any AI agent)
  - `init`: creates `.flutter-toolkit.yaml`
  - `info`: shows the detected Flutter stack
- The rules engine is a public Dart library (`package:flutter_agent_toolkit`).

## 0.2.1

Fixes from the first live agent-session test:
- Hook messages are short: the launcher moved to `hooks/run.sh`.
- `/flutter-init` marks recommended vs optional rules and writes a folder-structure template for fresh apps.
- `flutter-verify` reads fewer screenshots (failing shots plus phone and desktop), so it uses fewer tokens.
- The verify template uses `debugPrint`, so team `print` rules don't flag it.

## 0.2.0

- Project autodetect at session start.
- Per-edit check is now instant; analysis runs once when the agent finishes, with up to 3 automatic fix rounds.
- Auto build_runner and auto format.
- Team config file with banned APIs and strictness.
- Summary line with an all-time counter.
- `flutter-verify` skill: screenshots and overflow detection.
- `/flutter-init` command.
- Deprecated-API scan ignores strings and comments.
- Clear message when `dart` is not on PATH.

## 0.1.0

- First release: post-edit analyze hook, `modern-flutter` and `flutter-build-fixer` skills, `/flutter-check`.
