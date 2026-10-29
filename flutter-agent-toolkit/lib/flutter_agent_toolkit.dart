/// The rules engine behind the flutter-agent-toolkit Claude Code plugin and
/// CLI: deprecated and team-banned Flutter API scanning, the
/// `.flutter-toolkit.yaml` team config, Flutter project detection, and
/// `dart analyze` integration.
///
/// ```dart
/// final findings = scanSource(
///   "final c = Colors.red.withOpacity(0.5);",
///   'lib/main.dart',
///   ToolkitConfig(),
/// );
/// print(findings.first); // - [deprecated] line 1: .withOpacity(x) is ...
/// ```
library;

export 'src/analyzer.dart'
    show Issue, analyzeFiles, importantInfoCodes, parseMachineLine;
export 'src/config.dart'
    show
        BannedApi,
        Strictness,
        ToolkitConfig,
        defaultConfigYaml,
        parseSimpleYaml;
export 'src/project.dart'
    show
        ProjectInfo,
        findFlutterProjects,
        findPubspecRoot,
        isFlutterPubspec,
        readDependencies,
        sdkVersions,
        stackCategories;
export 'src/rules.dart'
    show
        Finding,
        codegenMarker,
        deprecatedApis,
        generatedSuffixes,
        isGenerated,
        maskNonCode,
        scanSource;
export 'src/util.dart' show relativePath;
export 'src/version.dart';
