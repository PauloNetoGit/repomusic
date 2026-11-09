// Persistência em JSON na pasta privada do app (sem plugins).
import 'dart:convert';
import 'dart:io';

import '../engine/catalog.dart';
import '../models/rig.dart';

class AppSettings {
  AppSettings({
    this.inputGainDb = 0,
    this.outputGainDb = 0,
    this.looperLevel = 1,
    this.inputDevice = 0,
    this.outputDevice = 0,
    this.keepScreenOn = true,
    this.tunerMute = true,
    this.a4 = 440,
  });

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
    inputGainDb: (j['inputGainDb'] as num?)?.toDouble() ?? 0,
    outputGainDb: (j['outputGainDb'] as num?)?.toDouble() ?? 0,
    looperLevel: (j['looperLevel'] as num?)?.toDouble() ?? 1,
    inputDevice: (j['inputDevice'] as num?)?.toInt() ?? 0,
    outputDevice: (j['outputDevice'] as num?)?.toInt() ?? 0,
    keepScreenOn: j['keepScreenOn'] as bool? ?? true,
    tunerMute: j['tunerMute'] as bool? ?? true,
    a4: (j['a4'] as num?)?.toDouble() ?? 440,
  );

  double inputGainDb;
  double outputGainDb;
  double looperLevel;
  int inputDevice;
  int outputDevice;
  bool keepScreenOn;
  bool tunerMute;
  double a4;

  Map<String, dynamic> toJson() => {
    'inputGainDb': inputGainDb,
    'outputGainDb': outputGainDb,
    'looperLevel': looperLevel,
    'inputDevice': inputDevice,
    'outputDevice': outputDevice,
    'keepScreenOn': keepScreenOn,
    'tunerMute': tunerMute,
    'a4': a4,
  };
}

class PresetStore {
  PresetStore(this.dir);

  final String dir;

  File get _presets => File('$dir/presets.json');
  File get _current => File('$dir/current.json');
  File get _settings => File('$dir/settings.json');

  Future<Map<String, dynamic>?> _read(File f) async {
    try {
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null; // arquivo corrompido: ignora
    }
  }

  final _pending = <String, Future<void>>{};

  /// Escritas no mesmo arquivo são enfileiradas; cada uma grava num .tmp e
  /// renomeia (atômico), então um travamento nunca deixa JSON pela metade.
  Future<void> _write(File f, Map<String, dynamic> data) {
    final text = jsonEncode(data);
    final prev = _pending[f.path] ?? Future<void>.value();
    final next = prev
        .then((_) async {
          final tmp = File('${f.path}.tmp');
          await tmp.writeAsString(text, flush: true);
          await tmp.rename(f.path);
        })
        .catchError((Object _) {});
    _pending[f.path] = next;
    return next;
  }

  Future<List<Preset>> loadUserPresets(Catalog catalog) async {
    final j = await _read(_presets);
    final list = (j?['presets'] as List?) ?? const [];
    return [for (final p in list) Preset.fromJson(p as Map<String, dynamic>, catalog)];
  }

  Future<void> saveUserPresets(List<Preset> presets) => _write(_presets, {
    'presets': [for (final p in presets) p.toJson()],
  });

  Future<Preset?> loadCurrent(Catalog catalog) async {
    final j = await _read(_current);
    return j == null ? null : Preset.fromJson(j, catalog);
  }

  Future<void> saveCurrent(Preset p) => _write(_current, p.toJson());

  Future<AppSettings> loadSettings() async {
    final j = await _read(_settings);
    return j == null ? AppSettings() : AppSettings.fromJson(j);
  }

  Future<void> saveSettings(AppSettings s) => _write(_settings, s.toJson());
}
