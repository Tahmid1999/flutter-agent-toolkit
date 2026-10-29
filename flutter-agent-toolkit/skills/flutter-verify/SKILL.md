---
name: flutter-verify
description: Use after building or changing Flutter UI, or when the user runs /flutter-verify or asks to check how a screen looks. Renders the screen at small phone, phone, dark mode, large text, tablet and desktop sizes in a widget test, saves screenshots, catches overflow and layout errors, and lets you look at the result and fix it. No device or emulator needed.
argument-hint: "[screen widget or file, default: screens changed this session]"
---

# Flutter Verify

You cannot see the app. This skill gives you screenshots and layout errors so you can check UI work before calling it done.

The template [flutter_verify_test.dart](flutter_verify_test.dart) is in this skill's base directory.

## Steps

1. **Pick screens.** The ones the user named, or the screens/widgets you changed this session. At most 3 per run.

2. **Create one test per screen:** copy the template to `test/flutter_verify/<screen>_verify_test.dart` and fill every `VERIFY:` spot:
   - Import the screen and the app's theme.
   - `screenName`: short snake_case name.
   - `buildScreen()`: build the screen with **fake data**. Wrap it in what it needs:
     - Riverpod: `ProviderScope(overrides: [...], child: ...)` with fake values
     - Bloc: `BlocProvider.value(value: FakeBloc(...))` or a cubit seeded with a state
     - Provider / get_it: register fakes before `runApp`-style wrapping
     - go_router screens that read route params: pass them to the constructor directly
   - Show realistic content: long names, many list items, empty states if relevant. Overflow bugs hide behind short demo text.
   - `lightTheme()` / `darkTheme()`: return the app's real themes.
   - `google_fonts`: add `GoogleFonts.config.allowRuntimeFetching = false;` at the start of `loadRealFonts` (text falls back to Roboto). App fonts from pubspec: load with `FontLoader` from the font files.

3. **Run:**
   ```bash
   flutter test --update-goldens test/flutter_verify/<screen>_verify_test.dart
   ```
   Each shot prints `FLUTTER_VERIFY <screen>/<shot>: OK` or the layout error, for example `A RenderFlex overflowed by 42 pixels on the right.`
   If the test does not compile or the screen throws, fix the test setup (fakes, providers) first.

4. **Look at every screenshot** in `test/flutter_verify/goldens/<screen>/` with the Read tool. Check:
   - Yellow/black overflow stripes, clipped or cut-off text
   - `phone_small` (360×640): everything fits or scrolls; no keyboard-style overflow on forms
   - `phone_large_text` (1.5× text): text wraps, buttons grow, nothing overlaps
   - `phone_dark`: readable contrast, no hardcoded white/black backgrounds or text
   - `tablet` / `desktop`: content not stretched edge-to-edge. Constrain reading width (about 600–840 px) or use a multi-column layout
   - Spacing, alignment, and tap targets of at least 48×48

5. **Fix the app code, not the test**, then re-run steps 3–4. Stop after 3 rounds and report what is left.

6. **Report:**

   ```
   Flutter verify: <screen>
   | Shot             | Result | Notes |
   |------------------|--------|-------|
   | phone_small      | ✓      |       |
   | phone_large_text | fixed  | title Row overflowed, wrapped in Expanded |
   ...
   ```

7. **Clean up:** delete `test/flutter_verify/` unless the user wants to keep the screenshots as golden tests. If they keep them, rename the folder, remove the `print` line, and tell them to run `flutter test` normally (without `--update-goldens`) to catch regressions.

## Known limits of test rendering

- Shadows (elevation) render darker and harder than on a device.
- Network images do not load. Use placeholder or asset images in fakes.
- Platform views (maps, web views, video, camera) render blank.
- Animations are captured at rest. Endless animations (spinners) are captured mid-frame.

For pixel-perfect checks on a real device, the user can run the app; on an Android emulator a screenshot is `adb exec-out screencap -p > shot.png`.
