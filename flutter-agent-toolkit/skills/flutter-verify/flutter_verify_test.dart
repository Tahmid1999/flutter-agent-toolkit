// Created by flutter-agent-toolkit /flutter-verify. Safe to delete.
//
// Renders one screen at several sizes, themes and text scales, saves a
// screenshot of each to goldens/, and reports layout errors such as
// "A RenderFlex overflowed by 42 pixels".
//
// Run: flutter test --update-goldens <this file>
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// VERIFY: import the screen under test (and the app theme if it has one).

/// VERIFY: short snake_case screen name. Screenshots go to
/// `goldens/<screenName>/`.
const screenName = 'screen';

/// VERIFY: build the screen with fake data. Wrap it in the providers, blocs
/// or scopes it needs. No real network or platform calls.
Widget buildScreen() => const Placeholder();

/// VERIFY: return the app's real light and dark themes if it has them.
ThemeData lightTheme() =>
    ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo));
ThemeData darkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
    );

class Shot {
  const Shot(this.name, this.size, {this.dark = false, this.textScale = 1.0});
  final String name;
  final Size size;
  final bool dark;
  final double textScale;
}

const shots = [
  Shot('phone_small', Size(360, 640)),
  Shot('phone', Size(393, 852)),
  Shot('phone_dark', Size(393, 852), dark: true),
  Shot('phone_large_text', Size(393, 852), textScale: 1.5),
  Shot('tablet', Size(820, 1180)),
  Shot('desktop', Size(1440, 900)),
];

void main() {
  setUpAll(loadRealFonts);

  for (final shot in shots) {
    testWidgets('verify ${shot.name}', (tester) async {
      tester.view.physicalSize = shot.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final errors = <String>[];
      final original = FlutterError.onError;
      FlutterError.onError = (details) =>
          errors.add(details.exceptionAsString().split('\n').first);
      try {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: lightTheme(),
            darkTheme: darkTheme(),
            themeMode: shot.dark ? ThemeMode.dark : ThemeMode.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(shot.textScale),
              ),
              child: child!,
            ),
            home: buildScreen(),
          ),
        );
        await _settle(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/$screenName/${shot.name}.png'),
        );
      } finally {
        FlutterError.onError = original;
      }

      final exception = tester.takeException();
      if (exception != null) errors.add('$exception'.split('\n').first);
      final status = errors.isEmpty ? 'OK' : errors.toSet().join(' | ');
      // ignore: avoid_print
      print('FLUTTER_VERIFY $screenName/${shot.name}: $status');
      expect(errors, isEmpty, reason: 'Layout errors on ${shot.name}');
    });
  }
}

/// Waits for animations, but gives up on endless ones (spinners).
Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
  } on FlutterError {
    await tester.pump(const Duration(seconds: 1));
  }
}

/// Tests render text as boxes by default. Load Roboto and Material Icons
/// from the Flutter SDK so screenshots are readable.
Future<void> loadRealFonts() async {
  final fonts = _materialFontsDir();
  if (fonts == null) return;
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var added = false;
    for (final name in files) {
      final file = File('${fonts.path}/$name');
      if (!file.existsSync()) continue;
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
      added = true;
    }
    if (added) await loader.load();
  }

  await load('Roboto', [
    'roboto-regular.ttf',
    'roboto-medium.ttf',
    'roboto-bold.ttf',
    'roboto-light.ttf',
  ]);
  await load('MaterialIcons', ['materialicons-regular.otf']);
  // VERIFY: load the app's own fonts here if it declares any in pubspec.yaml.
}

Directory? _materialFontsDir() {
  const sub = 'bin/cache/artifacts/material_fonts';
  final env = Platform.environment['FLUTTER_ROOT'];
  if (env != null && Directory('$env/$sub').existsSync()) {
    return Directory('$env/$sub');
  }
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.parent.path != dir.path) {
    if (Directory('${dir.path}/$sub').existsSync()) {
      return Directory('${dir.path}/$sub');
    }
    dir = dir.parent;
  }
  return null;
}
