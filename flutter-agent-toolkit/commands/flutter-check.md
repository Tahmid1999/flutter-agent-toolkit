---
description: Run a full Flutter health check (format, analyze, tests, deprecated APIs) and fix what it finds
argument-hint: "[path, default: whole project]"
---

Run a full health check on this Flutter project (scope: `$ARGUMENTS`, or the whole project if empty). Use the `modern-flutter` skill for fixes.

1. Confirm this is a Flutter project (`pubspec.yaml` with a `flutter` dependency). Run `flutter --version`.
2. `flutter pub get`
3. `dart format .` (or the given path). Report how many files changed.
4. `dart analyze` (or the given path). Fix every error and warning. Fix `deprecated_member_use` infos with the modern API. Leave other style infos unless trivial.
5. If a `test/` folder exists: `flutter test`. Fix failures caused by code, not by changing test expectations, unless the test is clearly outdated; say which.
6. Re-run `dart analyze` and `flutter test` until clean, at most 3 rounds. If something still fails, stop and explain.
7. Report in this format:

```
Flutter check
- Format:   N files changed
- Analyze:  X errors, Y warnings fixed (Z left)
- Tests:    P passed, F failed
- Fixed:    short list of what changed
- Left:     anything you could not fix, and why
```

Do not upgrade Flutter, change the JDK, or add `dependency_overrides` during this check. If the problem is a native build error, use the `flutter-build-fixer` skill and ask before larger changes.
