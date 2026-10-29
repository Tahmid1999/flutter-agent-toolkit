---
name: flutter-build-fixer
description: Use when a Flutter build, run, or pub get fails - Gradle, Android Gradle Plugin, Kotlin, Java/JDK, NDK, minSdk/compileSdk, namespace, CocoaPods, Xcode, signing, Swift Package Manager, or "version solving failed" dependency errors. Diagnose from the exact error and apply a known fix instead of guessing version bumps.
---

# Flutter Build Fixer

Native build errors waste hours when fixed by guessing. Follow this process.

## Process

1. **Get the full error.** Re-run with verbose output if the message is truncated:
   - Android: `flutter build apk --debug -v` or `cd android && ./gradlew assembleDebug --stacktrace`
   - iOS: `flutter build ios --debug --no-codesign -v`
   - Find the **first** real error, not the last line. "BUILD FAILED" or "Gradle task assembleDebug failed with exit code 1" is not the error.
2. **Collect versions** (one command each, only what is relevant):
   - `flutter --version`
   - `java -version` and `flutter doctor -v` (shows which JDK Flutter uses)
   - `android/gradle/wrapper/gradle-wrapper.properties` (Gradle version)
   - `android/settings.gradle(.kts)` (AGP and Kotlin versions)
   - `ios/Podfile` (platform version), `pod --version`
3. **Match the error** in the reference file:
   - Android / Gradle / Kotlin / Java: [references/android.md](references/android.md)
   - iOS / CocoaPods / Xcode: [references/ios.md](references/ios.md)
   - pub / dependency / build_runner: [references/dependencies.md](references/dependencies.md)
4. **Apply one fix**, then rebuild. Do not stack several speculative changes.
5. **Two failed attempts on the same error → stop guessing.** Show the user the exact error, the versions, and what you tried. Ask before doing anything destructive (deleting lock files, upgrading Flutter, changing the JDK).

## Best trick: copy versions from a fresh project

Flutter's own template always has a working Android Gradle / Kotlin / Gradle combination for the installed Flutter version. When versions are the problem:

```bash
flutter create --platforms=android,ios /tmp/flutter_ref   # any temp folder
```

Then compare and copy:
- `android/settings.gradle.kts` → AGP (`com.android.application`) and Kotlin (`org.jetbrains.kotlin.android`) versions
- `android/gradle/wrapper/gradle-wrapper.properties` → `distributionUrl`
- `android/app/build.gradle.kts` → Java/`jvmTarget` level, `compileSdk`/`minSdk` style
- `ios/Podfile` → platform line

Delete the temp project afterwards.

## Safe reset (use after a fix, not instead of one)

```bash
flutter clean
flutter pub get
```

iOS only, if pods are stale:

```bash
cd ios && rm -rf Pods Podfile.lock && pod install --repo-update
```

`flutter clean` alone rarely fixes version errors. Fix the cause first.

## Never

- Never downgrade Flutter or Dart to fix one package; upgrade or replace the package instead.
- Never add `dependency_overrides` without telling the user. It hides real conflicts.
- Never commit signing keys, `key.properties`, or `local.properties`.
- Never disable the analyzer, lints, or null safety to make a build pass.
