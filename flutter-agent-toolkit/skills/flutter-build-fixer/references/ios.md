# iOS / CocoaPods / Xcode errors

iOS builds need macOS with Xcode. On Windows or Linux, say so and stop; do not try to fix iOS builds there.

Files:
- `ios/Podfile` → `platform :ios, 'X'`
- `ios/Runner.xcodeproj` → open `ios/Runner.xcworkspace` in Xcode, never the `.xcodeproj`
- `ios/Runner/Info.plist` → permissions, URL schemes

---

## "CocoaPods could not find compatible versions for pod X" / "required a higher minimum deployment target"

1. Raise the platform in `ios/Podfile` to what the pod needs (the error states it):
   ```ruby
   platform :ios, '13.0'
   ```
   Uncomment the line if it is commented out.
2. Update specs and reinstall:
   ```bash
   cd ios && pod install --repo-update
   ```
3. Still failing: `cd ios && rm -rf Pods Podfile.lock && pod install --repo-update`.

Also set the same "iOS Deployment Target" in Xcode (Runner target → General → Minimum Deployments) if it is lower.

## "CocoaPods not installed or not in valid state"

Ask the user to install it (it needs their shell and maybe a password): `brew install cocoapods` (recommended) or `sudo gem install cocoapods`. Then `pod setup`.

## "Module 'X' not found" (in GeneratedPluginRegistrant.m or Swift files)

```bash
flutter clean
flutter pub get
cd ios && pod install
```

When building in Xcode, open `Runner.xcworkspace`, not `Runner.xcodeproj`.

## "Sandbox: rsync(...) deny(1) file-write-create" (Xcode 15+)

In Xcode: Runner target → Build Settings → search "User Script Sandboxing" → set **No** (`ENABLE_USER_SCRIPT_SANDBOXING = NO`) for Runner, then rebuild.

## "DT_TOOLCHAIN_DIR cannot be used to evaluate LIBRARY_SEARCH_PATHS"

CocoaPods older than 1.13 with Xcode 15+. Upgrade CocoaPods (`brew upgrade cocoapods` or `sudo gem install cocoapods`), then `cd ios && pod install`.

## "No profiles for 'com.x.y' were found" / "Signing for 'Runner' requires a development team"

Signing is the user's decision. Tell them: open `ios/Runner.xcworkspace` → Runner target → Signing & Capabilities → choose their Team and a unique Bundle Identifier. For CI or compile checks only, use `flutter build ios --no-codesign`.

## "Your app is missing usage description" / app crashes when requesting camera, photos, location

Add the key to `ios/Runner/Info.plist`, for example:

```xml
<key>NSCameraUsageDescription</key>
<string>This app uses the camera to take profile photos.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo access to choose a profile picture.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app uses your location to show nearby places.</string>
```

Write a real reason; App Store review rejects vague text. If the app uses `permission_handler`, also enable the matching macro in the Podfile `post_install` block as its README describes.

## Swift Package Manager

Flutter can use Swift Package Manager instead of CocoaPods for plugins that support it. Enable with `flutter config --enable-swift-package-manager`. Plugins without SPM support still use CocoaPods, so keep the Podfile. If an SPM migration breaks the build, `flutter config --no-enable-swift-package-manager` reverts it.

## Apple Silicon: "ffi_c.bundle ... incompatible architecture" during pod install

CocoaPods installed with system Ruby. Reinstall with Homebrew: `brew install cocoapods`.
