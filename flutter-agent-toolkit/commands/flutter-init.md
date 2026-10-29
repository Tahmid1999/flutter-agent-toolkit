---
description: Set up flutter-agent-toolkit for this project - team rules file and CLAUDE.md conventions
---

Set up flutter-agent-toolkit for this Flutter project. Keep it quick and ask at most one question.

1. **Detect the stack.** Use the "Flutter (flutter-agent-toolkit)" context from session start if present; otherwise read `pubspec.yaml`, `analysis_options.yaml`, `l10n.yaml`, `.fvmrc` and the folders in `lib/`. Note state management, router, codegen, networking, storage, DI, lints, platforms and folder structure.

2. **Create `.flutter-toolkit.yaml`** in the project root (skip if it exists; offer to update it instead). Start from this, and fill `banned_apis` with rules that fit the detected stack:

   ```yaml
   # flutter-agent-toolkit settings. All keys are optional.
   strictness: warnings      # errors | warnings | all
   auto_format: true         # dart format changed files when Claude finishes
   auto_build_runner: true   # run build_runner when annotated files change
   check_deprecated: true    # flag deprecated Flutter APIs after each edit
   max_fix_rounds: 3         # times Claude is sent back to fix problems (0 = report only)
   summary: true             # show the "Flutter toolkit ✓" line after each turn
   ignore_codes: []          # analyzer codes to ignore, e.g. [todo]

   # Team rules. pattern is a regex matched against code (not strings or comments).
   banned_apis:
     - pattern: '\bprint\('
       message: Use the app logger instead of print.
       exclude: [test/, tool/]
   ```

   Rule ideas by stack (suggest only those that fit):
   - Any app: `\bprint\(` → use a logger; `Colors\.\w+` in `lib/features/` → use `Theme.of(context).colorScheme`
   - go_router: `Navigator\.(of\(context\)\.)?push(Named)?\(` → use `context.push` / `context.go`
   - Riverpod: `\bChangeNotifierProvider\b` → use Notifier / AsyncNotifier
   - Bloc: `\bsetState\(` in `lib/features/` → move state into a Cubit/Bloc
   - dio: `\bhttp\.(get|post|put|delete)\(` → use the shared Dio client
   - gen-l10n: `Text\('` in `lib/features/` → use `AppLocalizations.of(context)` strings

   Show the user the proposed rules and ask once which to keep before writing the file.

3. **Add a "Flutter conventions" section to `CLAUDE.md`** (create the file if missing; update the section if it exists, never duplicate). Keep it under 30 lines:
   - Stack (one line per category) and "do not add competing libraries"
   - Folder structure and where new features go
   - Commands: run, test, build_runner, gen-l10n, flavors if any
   - Pointers: "Use the modern-flutter skill. Run /flutter-check before finishing big changes. Use flutter-verify after UI changes."

4. **Check lints.** If `analysis_options.yaml` is missing or does not include a lint package, suggest `flutter_lints` (or `very_good_analysis` for strict teams). Do not change it without asking.

5. **Report** what you created or changed, in 3–5 lines, and suggest committing `.flutter-toolkit.yaml` and `CLAUDE.md` so the whole team gets the same rules.
