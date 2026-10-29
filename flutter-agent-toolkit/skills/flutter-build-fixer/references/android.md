# Android / Gradle errors

Known-good combo for Flutter 3.41: AGP 8.11.1, Kotlin 2.2.20, Gradle 8.14, Java 17. For other Flutter versions, read them from a fresh `flutter create` project (see SKILL.md).

Files:
- `android/settings.gradle.kts` (or `.gradle`) → AGP + Kotlin versions in `plugins { }`
- `android/gradle/wrapper/gradle-wrapper.properties` → Gradle version
- `android/app/build.gradle.kts` (or `.gradle`) → `namespace`, `compileSdk`, `minSdk`, Java target

Groovy files (`.gradle`) use `id "x" version "y"` and `minSdkVersion 23`. Kotlin files (`.gradle.kts`) use `id("x") version "y"` and `minSdk = 23`. Match the file's style.

---

## "Your project's Android Gradle Plugin version (X) is lower than Flutter's minimum supported version" / "Flutter support for your project's Gradle version will soon be dropped"

The message states the required versions. Update:

```kotlin
// android/settings.gradle.kts
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}
```

```properties
# android/gradle/wrapper/gradle-wrapper.properties
distributionUrl=https\://services.gradle.org/distributions/gradle-8.14-all.zip
```

AGP and Gradle must be compatible: AGP 8.11 needs Gradle ≥ 8.13.

## "You are applying Flutter's main Gradle plugin imperatively" / `apply plugin: 'com.android.application'` / `apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"`

Old project layout. Migrate to declarative plugins:

1. Remove the `buildscript { }` block from `android/build.gradle`.
2. In `android/settings.gradle`, replace the old `include ':app'` + `apply from:` lines with the `pluginManagement { }` + `plugins { }` blocks from a fresh `flutter create` project.
3. In `android/app/build.gradle`, replace `apply plugin:` / `apply from:` lines with:
   ```groovy
   plugins {
       id "com.android.application"
       id "kotlin-android"
       id "dev.flutter.flutter-gradle-plugin"
   }
   ```
4. Remove the `def flutterRoot = ...` / `localProperties` loading code that only served `apply from`.

## "Unsupported class file major version N"

The JDK is newer than Gradle supports. Major version → Java: 61 = 17, 65 = 21, 66 = 22, 67 = 23, 68 = 24.

Fix one of:
- Upgrade Gradle (Java 21 needs Gradle ≥ 8.5, Java 23 ≥ 8.10, Java 24 ≥ 8.14).
- Point Flutter at a JDK 17 or 21: `flutter config --jdk-dir "<path to JDK>"`.

Check which JDK Flutter uses with `flutter doctor -v` (Android toolchain section).

## "Namespace not specified. Specify a namespace in the module's build file"

AGP 8+ needs `namespace`.
- In the **app**: add to `android { }` in `android/app/build.gradle(.kts)`: `namespace = "com.example.app"` (same as `applicationId`).
- If the error names a **plugin package**: upgrade that package (`flutter pub upgrade <pkg>` or `flutter pub add <pkg>`). If unmaintained, replace it. Do not edit files in the pub cache.

## "uses-sdk:minSdkVersion X cannot be smaller than version Y declared in library"

In `android/app/build.gradle(.kts)` `defaultConfig`:

```kotlin
minSdk = 23   // use Y from the error, replacing flutter.minSdkVersion
```

## "Dependency X requires compileSdk/compileSdkVersion N or later" / `checkDebugAarMetadata` failed

Set `compileSdk = N` (from the error) in `android { }`, or upgrade Flutter so `flutter.compileSdkVersion` is high enough. Install the SDK platform with Android Studio's SDK Manager if missing.

## "Module was compiled with an incompatible version of Kotlin. The binary version of its metadata is X, expected version is Y"

Raise the Kotlin plugin version in `android/settings.gradle(.kts)` to at least X (the newer one). Use the fresh-project version.

## "Your project is configured with Android NDK X, but the following plugin(s) depend on a different Android NDK version"

Set the version the error asks for in `android/app/build.gradle(.kts)`:

```kotlin
android {
    ndkVersion = "27.0.12077973"   // exact string from the error
}
```

## "Inconsistent JVM-target compatibility detected for tasks 'compileDebugJavaWithJavac' (X) and 'compileDebugKotlin' (Y)"

Make Java and Kotlin targets equal in `android/app/build.gradle(.kts)`:

```kotlin
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}
kotlinOptions {
    jvmTarget = JavaVersion.VERSION_17.toString()
}
```

If the error names a plugin module, upgrade that plugin.

## "Dependency ':X' requires core library desugaring to be enabled"

Common with `flutter_local_notifications`. In `android/app/build.gradle.kts`:

```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        // keep existing sourceCompatibility/targetCompatibility
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

Groovy: `coreLibraryDesugaringEnabled true` and `coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'`. Use the desugar version the plugin's README asks for if it differs.

## "Duplicate class kotlin.collections.jdk8.* found in modules kotlin-stdlib-1.8 and kotlin-stdlib-jdk8"

Kotlin plugin too old. Raise the Kotlin version in `settings.gradle(.kts)`.

## "Cannot fit requested classes in a single dex file"

Set `minSdk` ≥ 21; multidex is then built in. No extra dependency needed.

## "Could not resolve all files for configuration" / "Could not GET https://..."

Network or repository problem, not a code bug. Check internet/proxy, that `google()` and `mavenCentral()` are in `repositories`, then retry. Do not change versions for this.

## "Execution failed for task ':app:minifyReleaseWithR8'" / "Missing classes detected while running R8"

R8 prints a file `missing_rules.txt` path. Copy those `-dontwarn` lines into `android/app/proguard-rules.pro` and make sure the release build type references it. Prefer upgrading the plugin that caused it.

## Gradle daemon / out of memory: "Java heap space" / "Metaspace"

Raise memory in `android/gradle.properties`:

```properties
org.gradle.jvmargs=-Xmx4G -XX:MaxMetaspaceSize=1G
```
