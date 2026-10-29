# Deprecated and removed Flutter APIs

Old API on the left. Always write the right side.

## Colors

| Old | New |
|---|---|
| `color.withOpacity(0.5)` | `color.withValues(alpha: 0.5)` |
| `color.opacity` | `color.a` (double 0.0–1.0) |
| `color.red` / `.green` / `.blue` (int 0–255) | `color.r` / `.g` / `.b` (double 0.0–1.0) |
| `color.value` | `color.toARGB32()` |

## Navigation

| Old | New |
|---|---|
| `WillPopScope(onWillPop: ...)` | `PopScope(canPop: ..., onPopInvokedWithResult: (didPop, result) {...})` |
| `PopScope(onPopInvoked: (didPop) {...})` | `PopScope(onPopInvokedWithResult: (didPop, result) {...})` |

## Widget state

| Old | New |
|---|---|
| `MaterialStateProperty.all(x)` | `WidgetStatePropertyAll(x)` |
| `MaterialStateProperty.resolveWith(...)` | `WidgetStateProperty.resolveWith(...)` |
| `MaterialState.pressed` (etc.) | `WidgetState.pressed` |
| `MaterialStateColor` / `MaterialStateBorderSide` | `WidgetStateColor` / `WidgetStateBorderSide` |

## Text

| Old | New |
|---|---|
| `textScaleFactor: 1.2` | `textScaler: TextScaler.linear(1.2)` |
| `MediaQuery.textScaleFactorOf(context)` | `MediaQuery.textScalerOf(context)` |
| `textTheme.headline1` / `headline2` / `headline3` | `displayLarge` / `displayMedium` / `displaySmall` |
| `textTheme.headline4` / `headline5` / `headline6` | `headlineMedium` / `headlineSmall` / `titleLarge` |
| `textTheme.subtitle1` / `subtitle2` | `titleMedium` / `titleSmall` |
| `textTheme.bodyText1` / `bodyText2` | `bodyLarge` / `bodyMedium` |
| `textTheme.caption` | `bodySmall` |
| `textTheme.button` / `overline` | `labelLarge` / `labelSmall` |

## Theme

| Old | New |
|---|---|
| `colorScheme.background` | `colorScheme.surface` |
| `colorScheme.onBackground` | `colorScheme.onSurface` |
| `colorScheme.surfaceVariant` | `colorScheme.surfaceContainerHighest` |
| `ThemeData(accentColor: ...)` | `colorScheme.secondary` |
| `ThemeData(useMaterial3: true)` | Not needed; Material 3 is the default |

## Widgets

| Old | New |
|---|---|
| `RaisedButton` | `ElevatedButton` |
| `FlatButton` | `TextButton` |
| `OutlineButton` | `OutlinedButton` |
| `ButtonBar` | `OverflowBar` |
| `Scaffold.of(context).showSnackBar(...)` | `ScaffoldMessenger.of(context).showSnackBar(...)` |
| `TextButton.styleFrom(primary: x)` | `TextButton.styleFrom(foregroundColor: x)` |
| `ElevatedButton.styleFrom(primary: x, onPrimary: y)` | `ElevatedButton.styleFrom(backgroundColor: x, foregroundColor: y)` |

## MediaQuery (performance, not deprecated)

| Old | Better |
|---|---|
| `MediaQuery.of(context).size` | `MediaQuery.sizeOf(context)` |
| `MediaQuery.of(context).padding` | `MediaQuery.paddingOf(context)` |
| `MediaQuery.of(context).viewInsets` | `MediaQuery.viewInsetsOf(context)` |

The `*Of` methods rebuild only when that one value changes.

## Android Gradle (Flutter 3.16+)

Old imperative `apply plugin:` / `apply from: ".../flutter.gradle"` in `android/app/build.gradle` is no longer supported. Use the declarative `plugins { }` block. See the `flutter-build-fixer` skill.
