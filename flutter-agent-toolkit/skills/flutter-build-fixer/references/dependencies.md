# pub / dependency / code generation errors

## "Because X depends on Y ^1.0.0 and Z depends on Y ^2.0.0, version solving failed."

1. See what is outdated: `flutter pub outdated`.
2. Try upgrading within constraints: `flutter pub upgrade`.
3. Try major upgrades: `flutter pub upgrade --major-versions`. Then run `dart analyze` and fix breaking changes.
4. If one package is abandoned and blocks the others, find a maintained replacement on pub.dev.
5. Last resort, and tell the user: `dependency_overrides:` in `pubspec.yaml` with a comment explaining why.

## "The current Dart SDK version is X. Because app depends on Y >=Z which requires SDK version >=W, version solving failed."

The package needs a newer Dart. Either pin an older package version that supports Dart X (check its changelog on pub.dev), or ask the user before upgrading Flutter (`flutter upgrade`).

## "Error: Couldn't resolve the package 'X' in 'package:X/X.dart'" / "Target of URI doesn't exist"

- Run `flutter pub get`.
- If the package is missing from `pubspec.yaml`, add it with `flutter pub add X`.
- For generated files (`*.g.dart`, `*.freezed.dart`), run build_runner (below).

## build_runner

```bash
dart run build_runner build --delete-conflicting-outputs
```

- "Conflicting outputs were detected" → the `--delete-conflicting-outputs` flag fixes it.
- Missing `part 'file.g.dart';` / `part 'file.freezed.dart';` → add the `part` directive to the source file. The file name must match.
- Errors after upgrading freezed / json_serializable / riverpod_generator → read the package changelog for migration steps. Do not downgrade without asking.
- Slow builds → narrow inputs with a `build.yaml` `generate_for` list, or run `dart run build_runner watch --delete-conflicting-outputs` during development.

## "flutter pub get" hangs or fails with network errors

Network or proxy issue. Check `PUB_HOSTED_URL` (mirrors) and proxy settings. Retry. Do not change versions for this.

## Pub cache corruption: strange errors in files under `.pub-cache`

```bash
dart pub cache repair
```

Takes a while; tell the user first.
