// Estado da aplicação: cadeia de blocos, presets, áudio e sincronização com o motor.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart' show PlatformException, rootBundle;
import 'package:flutter/widgets.dart';

import '../engine/audio_engine.dart';
import '../engine/catalog.dart';
import '../models/rig.dart';
import '../services/platform_service.dart';
import '../services/preset_store.dart';
import 'factory_presets.dart';

class EngineStatus {
  const EngineStatus({
    this.inLevel = 0,
    this.outLevel = 0,
    this.looperState = LooperState.empty,
    this.looperProgress = 0,
    this.looperLength = 0,
    this.stats = const AudioStats(),
  });

  final double inLevel; // pico linear (0..1+), com decaimento para o medidor
  final double outLevel;
  final int looperState;
  final double looperProgress;
  final double looperLength;
  final AudioStats stats;
}

class RigController extends ChangeNotifier with WidgetsBindingObserver {
  RigController({AudioEngine? engine, PlatformService? platform})
    : _injected = engine,
      platform = platform ?? PlatformService();

  final AudioEngine? _injected;
  final PlatformService platform;
  late final AudioEngine engine;
  late final Catalog catalog;
  late final PresetStore _store;
  AppSettings settings = AppSettings();

  final List<RigBlock> blocks = [];
  String presetName = 'Novo rig';
  bool modified = false;
  List<Preset> factoryPresets = [];
  List<Preset> userPresets = [];

  bool audioOn = false;
  bool starting = false;
  String? audioError;
  final status = ValueNotifier<EngineStatus>(const EngineStatus());

  Timer? _poll;
  Timer? _saveTimer;
  Timer? _settingsTimer;
  int _tick = 0;
  int _notRunning = 0;
  double _inHold = 0, _outHold = 0;
  AudioStats _stats = const AudioStats();
  bool _resumeOnForeground = false;
  bool _ready = false;

  bool get ready => _ready;
  bool get hasNativeEngine => engine.isNative;

  // ------------------------------------------------------------ inicialização
  Future<void> init() async {
    engine = _injected ?? NativeEngine.tryLoad() ?? SilentEngine(await rootBundle.loadString('assets/catalog.json'));
    catalog = Catalog.fromJsonString(engine.catalogJson());
    factoryPresets = buildFactoryPresets(catalog);
    _store = PresetStore(await platform.filesDir());
    settings = await _store.loadSettings();
    userPresets = await _store.loadUserPresets(catalog);
    engine.setInputGainDb(settings.inputGainDb);
    engine.setOutputGainDb(settings.outputGainDb);
    engine.setLooperLevel(settings.looperLevel);

    final current = await _store.loadCurrent(catalog);
    if (current != null && current.blocks.isNotEmpty) {
      await _apply(current, save: false);
    } else if (factoryPresets.isNotEmpty) {
      await _apply(factoryPresets.first, save: false);
    }
    WidgetsBinding.instance.addObserver(this);
    _ready = true;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _saveTimer?.cancel();
    _settingsTimer?.cancel();
    if (audioOn) engine.stop();
    status.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // O Android não permite capturar o microfone em segundo plano sem serviço
    // em primeiro plano; paramos o áudio e retomamos ao voltar.
    if (state == AppLifecycleState.paused) {
      if (audioOn) {
        _resumeOnForeground = true;
        stopAudio();
      }
      _flushSave();
    } else if (state == AppLifecycleState.resumed && _resumeOnForeground) {
      _resumeOnForeground = false;
      startAudio();
    }
  }

  BlockDef defOf(RigBlock b) => catalog.byId(b.typeId)!;

  RigBlock? byUid(String uid) {
    for (final b in blocks) {
      if (b.uid == uid) return b;
    }
    return null;
  }

  // --------------------------------------------------------------- cadeia
  void _engineAdd(RigBlock b, int index) {
    final id = engine.addBlock(b.typeId, b.model, index);
    b.engineId = id;
    if (id <= 0) return;
    for (var i = 0; i < b.params.length; i++) {
      engine.setParam(id, i, b.params[i]);
    }
    engine.setBypass(id, b.bypass);
    if (b.typeId == 'cab' && b.model == catalog.irModel && b.irPath != null) {
      if (File(b.irPath!).existsSync()) {
        if (engine.loadIr(id, b.irPath!) < 0) b.irName = null;
      } else {
        b.irPath = null;
        b.irName = null;
      }
    }
  }

  Future<void> _apply(Preset p, {bool save = true}) async {
    // Silencia a saída durante a troca para não ouvir a cadeia montada pela metade.
    if (audioOn) {
      engine.setOutputGainDb(-60);
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    engine.clearChain();
    blocks.clear();
    for (final b in p.blocks) {
      final rb = b.copy();
      _engineAdd(rb, blocks.length);
      blocks.add(rb);
    }
    presetName = p.name;
    modified = false;
    if (audioOn) engine.setOutputGainDb(settings.outputGainDb);
    if (save) _scheduleSave();
    notifyListeners();
  }

  int suggestedIndex(BlockDef def) {
    final rank = Catalog.signalRank(def);
    for (var i = 0; i < blocks.length; i++) {
      if (Catalog.signalRank(defOf(blocks[i])) > rank) return i;
    }
    return blocks.length;
  }

  RigBlock addBlock(BlockDef def, int model, {int? index}) {
    final rb = RigBlock.create(def, model);
    final i = (index ?? suggestedIndex(def)).clamp(0, blocks.length);
    _engineAdd(rb, i);
    blocks.insert(i, rb);
    _changed();
    return rb;
  }

  void removeBlock(String uid) {
    final b = byUid(uid);
    if (b == null) return;
    engine.removeBlock(b.engineId);
    blocks.remove(b);
    _changed();
  }

  /// Semântica do ReorderableListView.onReorder.
  void reorder(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex) return;
    final b = blocks.removeAt(oldIndex);
    blocks.insert(newIndex, b);
    engine.moveBlock(b.engineId, newIndex);
    _changed();
  }

  void setParam(String uid, int index, double value) {
    final b = byUid(uid);
    if (b == null) return;
    final v = defOf(b).params[index].clamp(value);
    if (b.params[index] == v) return;
    b.params[index] = v;
    engine.setParam(b.engineId, index, v);
    _changed();
  }

  void resetParam(String uid, int index) => setParam(uid, index, defOf(byUid(uid)!).params[index].def);

  void setBypass(String uid, bool bypass) {
    final b = byUid(uid);
    if (b == null) return;
    b.bypass = bypass;
    engine.setBypass(b.engineId, bypass);
    _changed();
  }

  void toggleBypass(String uid) {
    final b = byUid(uid);
    if (b != null) setBypass(uid, !b.bypass);
  }

  void setModel(String uid, int model) {
    final b = byUid(uid);
    if (b == null || b.model == model) return;
    final index = blocks.indexOf(b);
    engine.removeBlock(b.engineId);
    b.model = model;
    _engineAdd(b, index);
    _changed();
  }

  /// Abre o seletor, copia o WAV e carrega na caixa. Retorna mensagem de erro ou null.
  Future<String?> pickAndLoadIr(String uid) async {
    final b = byUid(uid);
    if (b == null) return 'Bloco não encontrado';
    if (!engine.isNative) return engine.lastError();
    final PickedFile? picked;
    try {
      picked = await platform.pickWav();
    } on PlatformException catch (e) {
      return 'falha ao copiar o arquivo (${e.message ?? e.code})';
    }
    if (picked == null) return null;
    if (b.model != catalog.irModel) setModel(uid, catalog.irModel);
    final r = engine.loadIr(b.engineId, picked.path);
    if (r < 0) {
      try {
        File(picked.path).deleteSync();
      } catch (_) {}
      return engine.lastError();
    }
    b.irPath = picked.path;
    b.irName = picked.name;
    _changed();
    return null;
  }

  void clearIr(String uid) {
    final b = byUid(uid);
    if (b == null) return;
    engine.clearIr(b.engineId);
    b.irPath = null;
    b.irName = null;
    _changed();
  }

  void _changed() {
    modified = true;
    _scheduleSave();
    notifyListeners();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _flushSave);
  }

  void _flushSave() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_ready) return;
    _store.saveCurrent(Preset(name: presetName, blocks: blocks));
  }

  // --------------------------------------------------------------- presets
  Future<void> loadPreset(Preset p) => _apply(p);

  /// Todos os presets na ordem de navegação: os do usuário, depois os de fábrica.
  List<Preset> get allPresets => [...userPresets, ...factoryPresets];

  /// Preset (salvo ou de fábrica) que corresponde ao nome atual, se houver.
  Preset? get currentPreset {
    for (final p in allPresets) {
      if (p.name == presetName) return p;
    }
    return null;
  }

  /// Avança (+1) ou volta (-1) na lista de presets, como num footswitch de banco.
  Future<void> stepPreset(int delta) async {
    final list = allPresets;
    if (list.isEmpty) return;
    final i = list.indexWhere((p) => p.name == presetName);
    final next = i < 0 ? 0 : (i + delta) % list.length;
    await _apply(list[next < 0 ? next + list.length : next]);
  }

  Future<void> savePresetAs(String name) async {
    final n = name.trim().isEmpty ? 'Sem nome' : name.trim();
    final p = Preset(name: n, blocks: [for (final b in blocks) b.copy()]);
    final i = userPresets.indexWhere((e) => e.name == n);
    if (i >= 0) {
      userPresets[i] = p;
    } else {
      userPresets.add(p);
    }
    presetName = n;
    modified = false;
    await _store.saveUserPresets(userPresets);
    _scheduleSave();
    notifyListeners();
  }

  Future<void> deleteUserPreset(Preset p) async {
    userPresets.remove(p);
    await _store.saveUserPresets(userPresets);
    notifyListeners();
  }

  Future<void> renameUserPreset(Preset p, String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    if (presetName == p.name) presetName = n;
    p.name = n;
    await _store.saveUserPresets(userPresets);
    notifyListeners();
  }

  String exportJson(Preset p) => const JsonEncoder.withIndent('  ').convert(p.toJson());
  String exportCurrentJson() => exportJson(Preset(name: presetName, blocks: blocks));

  /// Importa um preset colado como texto. Lança FormatException se inválido.
  Future<Preset> importJson(String text) async {
    final Object? j;
    try {
      j = jsonDecode(text);
    } catch (_) {
      throw const FormatException('O texto não é um JSON válido.');
    }
    if (j is! Map<String, dynamic> || j['blocks'] is! List) {
      throw const FormatException('JSON não parece ser um preset da pedaleira.');
    }
    final p = Preset.fromJson(j, catalog);
    if (p.blocks.isEmpty) throw const FormatException('O preset não tem blocos reconhecidos.');
    var name = p.name;
    var k = 2;
    while (userPresets.any((e) => e.name == name)) {
      name = '${p.name} ($k)';
      k++;
    }
    p.name = name;
    // Caminhos de IR de outro aparelho não existem aqui.
    for (final b in p.blocks) {
      if (b.irPath != null && !File(b.irPath!).existsSync()) {
        b.irPath = null;
        b.irName = null;
      }
    }
    userPresets.add(p);
    await _store.saveUserPresets(userPresets);
    notifyListeners();
    return p;
  }

  // --------------------------------------------------------------- áudio
  Future<void> startAudio() async {
    if (audioOn || starting) return;
    starting = true;
    audioError = null;
    notifyListeners();
    final granted = await platform.requestMicPermission();
    if (!granted) {
      starting = false;
      audioError = 'Permissão de microfone negada. Ative em Configurações > Apps > Pedaleira > Permissões.';
      notifyListeners();
      return;
    }
    final r = engine.start(inputDevice: settings.inputDevice, outputDevice: settings.outputDevice);
    starting = false;
    if (r != 0) {
      audioOn = false;
      audioError = engine.lastError();
    } else {
      audioOn = true;
      _notRunning = 0;
      platform.keepScreenOn(settings.keepScreenOn);
      _startPolling();
    }
    notifyListeners();
  }

  void stopAudio() {
    engine.stop();
    audioOn = false;
    _poll?.cancel();
    _poll = null;
    platform.keepScreenOn(false);
    _inHold = _outHold = 0;
    status.value = EngineStatus(looperState: status.value.looperState, looperLength: status.value.looperLength);
    notifyListeners();
  }

  Future<void> toggleAudio() async {
    if (audioOn) {
      stopAudio();
    } else {
      await startAudio();
    }
  }

  Future<void> restartAudio() async {
    if (!audioOn) return;
    stopAudio();
    await startAudio();
  }

  void _startPolling() {
    _poll?.cancel();
    _tick = 0;
    _stats = engine.stats();
    _poll = Timer.periodic(const Duration(milliseconds: 40), (_) => _pollEngine());
  }

  void _pollEngine() {
    _inHold = math.max(engine.takeInputPeak(), _inHold * 0.82);
    _outHold = math.max(engine.takeOutputPeak(), _outHold * 0.82);
    if (++_tick % 25 == 0) {
      _stats = engine.stats();
      if (!engine.isRunning) {
        if (++_notRunning >= 3) {
          stopAudio();
          audioError = 'O áudio parou (o dispositivo foi desconectado?). Toque em ligar novamente.';
          notifyListeners();
          return;
        }
      } else {
        _notRunning = 0;
      }
    }
    status.value = EngineStatus(
      inLevel: _inHold,
      outLevel: _outHold,
      looperState: engine.looperState(),
      looperProgress: engine.looperProgress(),
      looperLength: engine.looperLength(),
      stats: _stats,
    );
  }

  // --------------------------------------------------------------- ajustes
  void _saveSettingsSoon() {
    _settingsTimer?.cancel();
    _settingsTimer = Timer(const Duration(milliseconds: 500), () => _store.saveSettings(settings));
  }

  void setInputGain(double db) {
    settings.inputGainDb = db;
    engine.setInputGainDb(db);
    _saveSettingsSoon();
    notifyListeners();
  }

  void setOutputGain(double db) {
    settings.outputGainDb = db;
    engine.setOutputGainDb(db);
    _saveSettingsSoon();
    notifyListeners();
  }

  void setLooperLevel(double level) {
    settings.looperLevel = level;
    engine.setLooperLevel(level);
    _saveSettingsSoon();
    notifyListeners();
  }

  Future<void> setDevices({int? input, int? output}) async {
    if (input != null) settings.inputDevice = input;
    if (output != null) settings.outputDevice = output;
    _saveSettingsSoon();
    notifyListeners();
    await restartAudio();
  }

  void setKeepScreenOn(bool on) {
    settings.keepScreenOn = on;
    if (audioOn) platform.keepScreenOn(on);
    _saveSettingsSoon();
    notifyListeners();
  }

  void setTunerMute(bool mute) {
    settings.tunerMute = mute;
    engine.setTuner(true, mute: mute);
    _saveSettingsSoon();
    notifyListeners();
  }

  void setA4(double hz) {
    settings.a4 = hz;
    _saveSettingsSoon();
    notifyListeners();
  }

  // --------------------------------------------------------------- afinador / looper
  void tunerOn() => engine.setTuner(true, mute: settings.tunerMute);
  void tunerOff() => engine.setTuner(false);
  double tunerFrequency() => engine.tunerFrequency();

  void looper(int cmd) => engine.looperCommand(cmd);
}
