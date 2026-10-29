---
name: modern-flutter
description: Use before writing or modifying any Flutter or Dart code (widgets, screens, state, themes, navigation, pubspec dependencies). Gives current Flutter 3.3x+ APIs, package choices, project structure, and the verification steps required before calling Flutter work done.
---

# Modern Flutter

Your training data contains years of outdated Flutter code. Follow these rules over memory.

## 1. Check the project before writing code

1. If the session context has a "Flutter (flutter-agent-toolkit)" section, it already lists the Flutter version, stack, layout and team rules. Use it. Otherwise run `flutter --version` and read `pubspec.yaml`.
2. Write code for that Flutter version. If FVM is used, run commands as `fvm flutter` / `fvm dart`.
3. Follow the existing patterns. Never introduce a second state management, router, HTTP client or DI library next to an existing one.
4. Respect team rules in `.flutter-toolkit.yaml` (`banned_apis`). They are checked after every edit.

## 2. Dependencies: never hand-write versions

- Add packages with `flutter pub add <name>` (or `flutter pub add dev:<name>`). It picks the latest compatible version. Version numbers from memory are usually stale.
- Before adding a package, check if the project or the Flutter SDK already covers it.
- Prefer well-maintained packages (verified publisher, recent release). Defaults for new projects:

| Need | Default |
|---|---|
| Navigation / deep links | `go_router` |
| State management | Follow the project. New project: `flutter_riverpod` or `flutter_bloc` (ask the user if unclear) |
| Immutable models / unions | `freezed` + `json_serializable` |
| HTTP | `dio` (or `http` for simple apps) |
| Local key-value | `shared_preferences` |
| Secure storage | `flutter_secure_storage` |
| Images from network | `cached_network_image` |
| Lints | `flutter_lints` (already in new projects) |

## 3. Deprecated APIs

Never use the APIs in [references/deprecated-apis.md](references/deprecated-apis.md). Most common:

- `color.withOpacity(0.5)` → `color.withValues(alpha: 0.5)`
- `WillPopScope` → `PopScope(canPop: false, onPopInvokedWithResult: (didPop, result) {...})`
- `MaterialStateProperty` / `MaterialState` → `WidgetStateProperty` / `WidgetState`
- `textScaleFactor` → `textScaler: TextScaler.linear(x)`
- `colorScheme.background` → `colorScheme.surface`, `surfaceVariant` → `surfaceContainerHighest`

If the analyzer reports `deprecated_member_use`, replace the API. Do not suppress the lint.

## 4. Widget rules

- Use `const` constructors and `super.key`.
- Extract sub-widgets into `StatelessWidget`/`StatefulWidget` classes, not `Widget _buildX()` helper methods.
- Keep `build` methods short. Files over ~300 lines should be split.
- Dispose every `TextEditingController`, `AnimationController`, `ScrollController`, `FocusNode` and `StreamSubscription` in `dispose()`.
- After any `await`, check `if (!context.mounted) return;` before using `context`. In a `State`, check `mounted`.
- Use `ListView.builder` / `GridView.builder` / slivers for long or unknown-length lists.

## 5. Layout: prevent overflow

- Never give text-heavy widgets fixed widths or heights.
- Wrap flexible children of `Row`/`Column` in `Expanded` or `Flexible`. Long text in a `Row` needs `Expanded` + `overflow: TextOverflow.ellipsis` or wrapping.
- Forms and long content go in `SingleChildScrollView` or a `ListView`, so the keyboard does not cause overflow.
- Use `SafeArea` on screens without an `AppBar`.
- Use `MediaQuery.sizeOf(context)` (not `MediaQuery.of(context).size`) and `LayoutBuilder` for responsive breakpoints. Design for 360px wide phones up to desktop.

## 6. Theming

- Build themes with `ColorScheme.fromSeed(seedColor: ...)`. Material 3 is the default; do not set `useMaterial3`.
- Read colors and text styles from `Theme.of(context).colorScheme` and `Theme.of(context).textTheme`. No hardcoded `Colors.x` or font sizes in widgets.
- Support dark mode with `darkTheme:` and `ColorScheme.fromSeed(..., brightness: Brightness.dark)`.

## 7. Project structure (new code)

Feature-first:

```
lib/
  main.dart
  app/            # MaterialApp, router, theme
  core/           # shared widgets, utils, constants
  features/
    <feature>/
      data/          # repositories, API clients, DTOs
      domain/        # models, business logic
      presentation/  # screens, widgets, controllers/blocs
```

If the project already uses another structure, follow it.

## 8. Code generation

- The toolkit runs `dart run build_runner build --delete-conflicting-outputs` automatically when you finish, if you changed `@freezed`, `@JsonSerializable`, `@riverpod` or other annotated code. Run it yourself only when you need generated code mid-task.
- Never edit `*.g.dart` or `*.freezed.dart` by hand.

## 9. Native build errors

For Gradle, Android, Kotlin, Xcode or CocoaPods errors, use the `flutter-build-fixer` skill. Do not guess version bumps.

## 10. Done means verified

Before saying Flutter work is done:

1. `dart analyze` has no errors or warnings in the files you touched. (The toolkit checks this when you finish and sends problems back.)
2. `flutter test` passes (if the project has tests).
3. For new or changed screens, use the `flutter-verify` skill: screenshots at phone, tablet, desktop, dark mode and large text, with overflow detection. If you skip it, say the UI is unverified.

Never claim the app works if you have not built or run it.
