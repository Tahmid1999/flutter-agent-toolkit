# Flutter Agent Toolkit

A Claude Code plugin that makes AI agents build Flutter apps the way a senior Flutter dev would: modern APIs, analyzer-clean code, generated code kept in sync, UI checked at every screen size, and native build errors fixed on the first try.

Install it once. It works automatically in every Flutter project, and stays silent everywhere else.

## What you get

| | What happens |
|---|---|
| **Knows your project** | When a session starts, the agent is told your Flutter version, state management, router, codegen, folder layout, platforms, FVM pin and team rules. It follows your stack from the first message. |
| **Instant API check** | After every `.dart` edit (about 0.2 s), deprecated Flutter APIs and your team's banned APIs are sent back to the agent with the exact replacement. |
| **Clean before "done"** | When the agent finishes, one `dart analyze` runs over the files it changed. Problems go back to the agent to fix, up to 3 rounds. |
| **Auto build_runner** | Edited a `@freezed`, `@JsonSerializable`, `@riverpod` or `part '*.g.dart'` file? Code is regenerated before analysis. Nobody forgets again. |
| **Auto format** | Changed files are formatted once at the end, not on every edit. |
| **See the value** | A one-line summary after each turn: `Flutter toolkit ✓ 4 Dart files checked · caught 2 deprecated APIs, 1 analyzer issue, all fixed · build_runner ran · 57 caught all-time` |
| **UI screenshots** | The `flutter-verify` skill renders a screen at small phone, phone, dark mode, 1.5× text, tablet and desktop sizes, catches overflow errors, and the agent looks at the screenshots and fixes the layout. No emulator needed. |
| **Build-error playbook** | Known Gradle, AGP, Kotlin, JDK, NDK, CocoaPods, Xcode and pub errors mapped to exact fixes. No more guessing loops. |
| **Team rules** | `.flutter-toolkit.yaml` in your repo: strictness, auto-format, auto build_runner, and your own banned APIs. Commit it and the whole team's agents follow the same rules. |

## Commands and skills

| Name | Type | Use |
|---|---|---|
| `/flutter-init` | Command | Set up the project: creates `.flutter-toolkit.yaml` with rules for your stack and adds Flutter conventions to `CLAUDE.md`. |
| `/flutter-check` | Command | Full health check: format, analyze, test, fix, report. |
| `flutter-verify` | Skill | Screenshots and layout check of a screen. The agent uses it after UI work, or run `/flutter-verify`. |
| `modern-flutter` | Skill | Current Flutter rules: API replacements, packages, layout, theming, structure. |
| `flutter-build-fixer` | Skill | Diagnose and fix native build and dependency errors. |

## Team config: `.flutter-toolkit.yaml`

Optional. Put it in the project root (next to `pubspec.yaml`). Every key is optional.

```yaml
strictness: warnings      # errors | warnings | all
auto_format: true         # format changed files when the agent finishes
auto_build_runner: true   # regenerate code when annotated files change
check_deprecated: true    # flag deprecated Flutter APIs after each edit
max_fix_rounds: 3         # times the agent is sent back to fix problems (0 = report only)
summary: true             # show the summary line after each turn
ignore_codes: [todo]      # analyzer codes to ignore

banned_apis:
  - pattern: '\bprint\('
    message: Use the app logger instead of print.
    exclude: [test/, tool/]
  - pattern: 'Colors\.\w+'
    message: Use Theme.of(context).colorScheme instead of hardcoded colors.
    paths: [lib/features/]
```

- `pattern` is a regular expression. It is matched against code only, not strings or comments.
- `paths` / `exclude` are path prefixes relative to the project root.
- Strictness `warnings` reports errors, warnings, deprecations, `use_build_context_synchronously` and unused imports. `all` adds every lint.

## Requirements

- [Claude Code](https://claude.com/claude-code)
- Flutter SDK with `dart` on your `PATH`
- Git Bash on Windows (installed with Git for Windows; Claude Code uses it for hooks)

## Install

```
/plugin marketplace add Tahmid1999/flutter-agent-toolkit
/plugin install flutter-agent-toolkit@flutter-agent-plugins
```

Then start a new session in a Flutter project. Run `/flutter-init` once per project.

## How it stays fast

The hook engine is written in Dart. On the first session it compiles itself to a native executable in the plugin data folder, so every later hook starts in about 0.2 s. If compiling is not possible, it falls back to running the Dart script (about 1 s). The expensive work (`dart analyze`, `build_runner`, `dart format`) runs once per turn, not once per edit.

## Privacy

Everything runs locally. The plugin sends nothing anywhere.

## Changelog

**0.2.1** (fixes from the first live agent-session test)
- Hook messages are short: the launcher moved to `hooks/run.sh`
- `/flutter-init` marks recommended vs optional rules and writes a folder-structure template for fresh apps
- `flutter-verify` reads fewer screenshots (failing shots plus phone and desktop), so it uses fewer tokens
- The verify template uses `debugPrint`, so team `print` rules don't flag it

**0.2.0**
- Project autodetect at session start
- Per-edit check is now instant; analysis runs once when the agent finishes, with up to 3 automatic fix rounds
- Auto build_runner and auto format
- Team config file with banned APIs and strictness
- Summary line with an all-time counter
- `flutter-verify` skill: screenshots and overflow detection
- `/flutter-init` command
- Deprecated-API scan ignores strings and comments
- Clear message when `dart` is not on PATH

**0.1.0**
- First release: post-edit analyze hook, modern-flutter and flutter-build-fixer skills, `/flutter-check`
