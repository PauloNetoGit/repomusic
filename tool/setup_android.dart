// Integra o motor nativo ao projeto Android gerado pelo `flutter create`.
//
// Uso (na raiz do projeto):
//   flutter create --platforms=android --org com.seudominio --project-name pedaleira .
//   dart tool/setup_android.dart
//
// O script é idempotente: pode ser executado de novo sem duplicar nada.
import 'dart:io';

const _marker = 'pedaleira-setup';
const _appLabel = 'PedalFX';

/// Identificador do app na Play Store (o mesmo cadastrado na Play Console).
/// Não pode mudar depois de publicado.
const _applicationId = 'com.uchord.pedalfx';

void main(List<String> args) {
  final root = Directory.current.path;
  final androidDir = Directory('$root/android');
  if (!androidDir.existsSync()) {
    _fail(
      'Pasta android/ não encontrada. Rode antes:\n'
      '  flutter create --platforms=android --org com.seudominio --project-name pedaleira .',
    );
  }
  final kts = File('$root/android/app/build.gradle.kts');
  final groovy = File('$root/android/app/build.gradle');
  if (kts.existsSync()) {
    _patchKts(kts);
  } else if (groovy.existsSync()) {
    _patchGroovy(groovy);
  } else {
    _fail('android/app/build.gradle(.kts) não encontrado.');
  }
  _setApplicationId(kts.existsSync() ? kts : groovy);
  _patchManifest(File('$root/android/app/src/main/AndroidManifest.xml'));
  _installActivity(root);
  _installResources(root);
  stdout.writeln('''

Pronto! Próximos passos:
  flutter run                 # testar num aparelho Android (USB/Wi-Fi)
  flutter build appbundle     # gerar o .aab para a Play Store
Veja o README.md para assinatura (android/key.properties) e publicação.''');
}

Never _fail(String msg) {
  stderr.writeln('ERRO: $msg');
  exit(1);
}

void _ok(String msg) => stdout.writeln('  ✓ $msg');

String _insertAfterLine(String src, RegExp anchor, String block) {
  final m = anchor.firstMatch(src);
  if (m == null) return src;
  final eol = src.indexOf('\n', m.end);
  final at = eol < 0 ? src.length : eol + 1;
  return src.substring(0, at) + block + src.substring(at);
}

String _insertBeforeLine(String src, RegExp anchor, String block) {
  final m = anchor.firstMatch(src);
  if (m == null) return src;
  final start = src.lastIndexOf('\n', m.start) + 1;
  return src.substring(0, start) + block + src.substring(start);
}

void _patchKts(File f) {
  var s = f.readAsStringSync();
  if (s.contains(_marker)) {
    _ok('${f.path} já configurado');
    return;
  }
  // minSdk 28: AAudio com presets de entrada (Android 9+).
  final minRe = RegExp(r'minSdk\s*=\s*[^\n]+');
  if (!minRe.hasMatch(s)) _fail('minSdk não encontrado em ${f.path}');
  s = s.replaceFirst(minRe, 'minSdk = 28 // $_marker: o motor usa AAudio (Android 9+)');

  // CMake do motor nativo.
  const cmake =
      '''
    // $_marker: motor de áudio nativo (C++)
    externalNativeBuild {
        cmake {
            path = file("../../native/CMakeLists.txt")
        }
    }
''';
  final ndk = RegExp(r'^\s*ndkVersion\s*=.*$', multiLine: true);
  s = ndk.hasMatch(s)
      ? _insertAfterLine(s, ndk, cmake)
      : _insertAfterLine(s, RegExp(r'^android\s*\{', multiLine: true), cmake);

  // Assinatura de release via android/key.properties (se existir).
  s = 'import java.io.FileInputStream\nimport java.util.Properties\n\n$s';
  const props =
      '''

// $_marker: assinatura de release lida de android/key.properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
''';
  final pluginsEnd = RegExp(r'^plugins\s*\{[\s\S]*?^\}', multiLine: true).firstMatch(s);
  if (pluginsEnd == null) _fail('bloco plugins {} não encontrado');
  s = s.substring(0, pluginsEnd.end) + props + s.substring(pluginsEnd.end);

  const signing = '''
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

''';
  final buildTypes = RegExp(r'^\s*buildTypes\s*\{', multiLine: true);
  if (!buildTypes.hasMatch(s)) _fail('bloco buildTypes {} não encontrado');
  s = _insertBeforeLine(s, buildTypes, signing);
  s = s.replaceFirst(
    RegExp(r'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)'),
    'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") '
    'else signingConfigs.getByName("debug")',
  );
  f.writeAsStringSync(s);
  _ok('${f.path}: minSdk 28, CMake do motor e assinatura de release');
}

void _patchGroovy(File f) {
  var s = f.readAsStringSync();
  if (s.contains(_marker)) {
    _ok('${f.path} já configurado');
    return;
  }
  s = s.replaceFirst(RegExp(r'minSdk(Version)?\s*=?\s*[^\n]+'), 'minSdk = 28 // $_marker');
  const cmake =
      '''
    // $_marker: motor de áudio nativo (C++)
    externalNativeBuild {
        cmake {
            path "../../native/CMakeLists.txt"
        }
    }
''';
  s = _insertAfterLine(s, RegExp(r'^android\s*\{', multiLine: true), cmake);
  f.writeAsStringSync(s);
  _ok('${f.path}: minSdk 28 e CMake (configure a assinatura manualmente, veja o README)');
}

void _patchManifest(File f) {
  if (!f.existsSync()) _fail('AndroidManifest.xml não encontrado');
  var s = f.readAsStringSync();
  if (!s.contains('android.permission.RECORD_AUDIO')) {
    const perms =
        '''
    <!-- $_marker: captura da guitarra e recursos de áudio -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-feature android:name="android.hardware.microphone" android:required="false" />
    <uses-feature android:name="android.hardware.audio.low_latency" android:required="false" />
    <uses-feature android:name="android.hardware.audio.pro" android:required="false" />
''';
    s = _insertAfterLine(s, RegExp(r'<manifest[^>]*>'), perms);
  }
  s = s.replaceFirst(RegExp(r'android:label="[^"]*"'), 'android:label="$_appLabel"');
  f.writeAsStringSync(s);
  _ok('AndroidManifest.xml: permissão de microfone e nome "$_appLabel"');
}

void _installActivity(String root) {
  final src = File('$root/android_overlay/MainActivity.kt');
  if (!src.existsSync()) _fail('android_overlay/MainActivity.kt não encontrado');
  final candidates = <File>[];
  for (final base in ['kotlin', 'java']) {
    final d = Directory('$root/android/app/src/main/$base');
    if (!d.existsSync()) continue;
    for (final e in d.listSync(recursive: true)) {
      if (e is File && (e.path.endsWith('MainActivity.kt') || e.path.endsWith('MainActivity.java'))) candidates.add(e);
    }
  }
  if (candidates.isEmpty) _fail('MainActivity gerada pelo flutter create não encontrada');
  final existing = candidates.first;
  if (existing.path.endsWith('.java')) {
    _fail(
      'O projeto Android foi gerado em Java. Apague a pasta android/ e rode:\n'
      '  flutter create --platforms=android -a kotlin --org com.seudominio --project-name pedaleira .',
    );
  }
  final current = existing.readAsStringSync();
  final pkg = RegExp(r'^package\s+([\w.]+)', multiLine: true).firstMatch(current)?.group(1);
  if (pkg == null) _fail('pacote não encontrado em ${existing.path}');
  existing.writeAsStringSync(src.readAsStringSync().replaceFirst('__PACKAGE__', pkg));
  _ok('MainActivity.kt instalada (pacote $pkg)');
}

/// Copia os ícones (android_overlay/res) por cima dos ícones padrão do Flutter.
void _installResources(String root) {
  final src = Directory('$root/android_overlay/res');
  if (!src.existsSync()) return;
  final dest = '$root/android/app/src/main/res';
  var n = 0;
  for (final e in src.listSync(recursive: true)) {
    if (e is! File) continue;
    final rel = e.path.substring(src.path.length + 1);
    final out = File('$dest/$rel');
    out.parent.createSync(recursive: true);
    e.copySync(out.path);
    n++;
  }
  _ok('Ícone do app instalado ($n arquivos)');
}

/// Define o applicationId (pode ser diferente do namespace/pacote do código).
void _setApplicationId(File f) {
  var s = f.readAsStringSync();
  final kts = RegExp(r'applicationId\s*=\s*"[^"]*"');
  final groovy = RegExp(r'''applicationId\s+['"][^'"]*['"]''');
  if (kts.hasMatch(s)) {
    s = s.replaceFirst(kts, 'applicationId = "$_applicationId"');
  } else if (groovy.hasMatch(s)) {
    s = s.replaceFirst(groovy, 'applicationId "$_applicationId"');
  } else {
    _fail('applicationId não encontrado em ${f.path}');
  }
  f.writeAsStringSync(s);
  _ok('Identificador do app: $_applicationId');
}
