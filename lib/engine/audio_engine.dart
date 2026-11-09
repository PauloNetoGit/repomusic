// Ponte com o motor nativo (libpedal_engine.so) via dart:ffi.
//
// Quando a biblioteca não está disponível (ex.: rodando a interface no desktop
// durante o desenvolvimento), usa SilentEngine, que mantém a interface
// funcionando sem áudio.
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

class AudioStats {
  const AudioStats({
    this.sampleRate = 0,
    this.latencyMs = 0,
    this.xruns = 0,
    this.bufferFrames = 0,
    this.burstFrames = 0,
    this.exclusive = false,
  });

  final int sampleRate;
  final double latencyMs;
  final int xruns;
  final int bufferFrames;
  final int burstFrames;
  final bool exclusive;
}

abstract class AudioEngine {
  bool get isNative;
  String catalogJson();
  String lastError();

  int start({int inputDevice = 0, int outputDevice = 0});
  void stop();
  bool get isRunning;
  AudioStats stats();

  int addBlock(String typeId, int model, int index);
  bool removeBlock(int id);
  bool moveBlock(int id, int newIndex);
  void clearChain();
  void setParam(int id, int index, double value);
  void setBypass(int id, bool bypass);
  int loadIr(int id, String path);
  void clearIr(int id);

  void setInputGainDb(double db);
  void setOutputGainDb(double db);
  double takeInputPeak();
  double takeOutputPeak();

  void setTuner(bool on, {bool mute = false});
  double tunerFrequency();

  void looperCommand(int cmd);
  int looperState();
  double looperProgress();
  double looperLength();
  void setLooperLevel(double level);
}

/// Comandos/estados do looper (iguais ao motor nativo).
class LooperCmd {
  static const main = 1, stop = 2, clear = 3, play = 4;
}

class LooperState {
  static const empty = 0, recording = 1, playing = 2, overdub = 3, stopped = 4;
}

// --------------------------------------------------------------- assinaturas C
typedef _StrC = Pointer<Utf8> Function();
typedef _IntIntC = Int32 Function(Int32, Int32);
typedef _IntIntD = int Function(int, int);
typedef _VoidC = Void Function();
typedef _VoidD = void Function();
typedef _IntC = Int32 Function();
typedef _IntD = int Function();
typedef _StatsC = Void Function(Pointer<Double>, Int32);
typedef _StatsD = void Function(Pointer<Double>, int);
typedef _AddC = Int32 Function(Pointer<Utf8>, Int32, Int32);
typedef _AddD = int Function(Pointer<Utf8>, int, int);
typedef _IdC = Int32 Function(Int32);
typedef _IdD = int Function(int);
typedef _ParamC = Void Function(Int32, Int32, Float);
typedef _ParamD = void Function(int, int, double);
typedef _IdVoidC = Void Function(Int32);
typedef _IdVoidD = void Function(int);
typedef _IdIdVoidC = Void Function(Int32, Int32);
typedef _IdIdVoidD = void Function(int, int);
typedef _IrC = Int32 Function(Int32, Pointer<Utf8>);
typedef _IrD = int Function(int, Pointer<Utf8>);
typedef _FloatInC = Void Function(Float);
typedef _FloatInD = void Function(double);
typedef _FloatOutC = Float Function();
typedef _FloatOutD = double Function();

class NativeEngine implements AudioEngine {
  NativeEngine._(DynamicLibrary l)
    : _catalog = l.lookupFunction<_StrC, _StrC>('ae_catalog_json'),
      _lastError = l.lookupFunction<_StrC, _StrC>('ae_last_error'),
      _start = l.lookupFunction<_IntIntC, _IntIntD>('ae_start'),
      _stop = l.lookupFunction<_VoidC, _VoidD>('ae_stop'),
      _isRunning = l.lookupFunction<_IntC, _IntD>('ae_is_running'),
      _stats = l.lookupFunction<_StatsC, _StatsD>('ae_get_stats'),
      _add = l.lookupFunction<_AddC, _AddD>('ae_add_block'),
      _remove = l.lookupFunction<_IdC, _IdD>('ae_remove_block'),
      _move = l.lookupFunction<_IntIntC, _IntIntD>('ae_move_block'),
      _clear = l.lookupFunction<_VoidC, _VoidD>('ae_clear_chain'),
      _setParam = l.lookupFunction<_ParamC, _ParamD>('ae_set_param'),
      _setBypass = l.lookupFunction<_IdIdVoidC, _IdIdVoidD>('ae_set_bypass'),
      _loadIr = l.lookupFunction<_IrC, _IrD>('ae_load_ir'),
      _clearIr = l.lookupFunction<_IdVoidC, _IdVoidD>('ae_clear_ir'),
      _inGain = l.lookupFunction<_FloatInC, _FloatInD>('ae_set_input_gain_db'),
      _outGain = l.lookupFunction<_FloatInC, _FloatInD>('ae_set_output_gain_db'),
      _inPeak = l.lookupFunction<_FloatOutC, _FloatOutD>('ae_take_input_peak'),
      _outPeak = l.lookupFunction<_FloatOutC, _FloatOutD>('ae_take_output_peak'),
      _tunerSet = l.lookupFunction<_IdIdVoidC, _IdIdVoidD>('ae_tuner_set'),
      _tunerFreq = l.lookupFunction<_FloatOutC, _FloatOutD>('ae_tuner_frequency'),
      _looperCmd = l.lookupFunction<_IdVoidC, _IdVoidD>('ae_looper_command'),
      _looperState = l.lookupFunction<_IntC, _IntD>('ae_looper_state'),
      _looperProgress = l.lookupFunction<_FloatOutC, _FloatOutD>('ae_looper_progress'),
      _looperLength = l.lookupFunction<_FloatOutC, _FloatOutD>('ae_looper_length'),
      _looperLevel = l.lookupFunction<_FloatInC, _FloatInD>('ae_looper_level');

  /// Retorna null se a biblioteca nativa não puder ser carregada.
  static NativeEngine? tryLoad() {
    try {
      final DynamicLibrary lib;
      if (Platform.isAndroid || Platform.isLinux) {
        lib = DynamicLibrary.open('libpedal_engine.so');
      } else if (Platform.isMacOS || Platform.isIOS) {
        lib = DynamicLibrary.process();
      } else if (Platform.isWindows) {
        lib = DynamicLibrary.open('pedal_engine.dll');
      } else {
        return null;
      }
      return NativeEngine._(lib);
    } catch (_) {
      return null;
    }
  }

  final Pointer<Utf8> Function() _catalog;
  final Pointer<Utf8> Function() _lastError;
  final _IntIntD _start;
  final _VoidD _stop;
  final _IntD _isRunning;
  final _StatsD _stats;
  final _AddD _add;
  final _IdD _remove;
  final _IntIntD _move;
  final _VoidD _clear;
  final _ParamD _setParam;
  final _IdIdVoidD _setBypass;
  final _IrD _loadIr;
  final _IdVoidD _clearIr;
  final _FloatInD _inGain;
  final _FloatInD _outGain;
  final _FloatOutD _inPeak;
  final _FloatOutD _outPeak;
  final _IdIdVoidD _tunerSet;
  final _FloatOutD _tunerFreq;
  final _IdVoidD _looperCmd;
  final _IntD _looperState;
  final _FloatOutD _looperProgress;
  final _FloatOutD _looperLength;
  final _FloatInD _looperLevel;

  final Pointer<Double> _statsBuf = calloc<Double>(6);

  @override
  bool get isNative => true;
  @override
  String catalogJson() => _catalog().toDartString();
  @override
  String lastError() => _lastError().toDartString();

  @override
  int start({int inputDevice = 0, int outputDevice = 0}) => _start(inputDevice, outputDevice);
  @override
  void stop() => _stop();
  @override
  bool get isRunning => _isRunning() != 0;
  @override
  AudioStats stats() {
    _stats(_statsBuf, 6);
    return AudioStats(
      sampleRate: _statsBuf[0].round(),
      latencyMs: _statsBuf[1],
      xruns: _statsBuf[2].round(),
      bufferFrames: _statsBuf[3].round(),
      burstFrames: _statsBuf[4].round(),
      exclusive: _statsBuf[5] > 0.5,
    );
  }

  @override
  int addBlock(String typeId, int model, int index) {
    final p = typeId.toNativeUtf8();
    try {
      return _add(p, model, index);
    } finally {
      malloc.free(p);
    }
  }

  @override
  bool removeBlock(int id) => _remove(id) != 0;
  @override
  bool moveBlock(int id, int newIndex) => _move(id, newIndex) != 0;
  @override
  void clearChain() => _clear();
  @override
  void setParam(int id, int index, double value) => _setParam(id, index, value);
  @override
  void setBypass(int id, bool bypass) => _setBypass(id, bypass ? 1 : 0);

  @override
  int loadIr(int id, String path) {
    final p = path.toNativeUtf8();
    try {
      return _loadIr(id, p);
    } finally {
      malloc.free(p);
    }
  }

  @override
  void clearIr(int id) => _clearIr(id);
  @override
  void setInputGainDb(double db) => _inGain(db);
  @override
  void setOutputGainDb(double db) => _outGain(db);
  @override
  double takeInputPeak() => _inPeak();
  @override
  double takeOutputPeak() => _outPeak();
  @override
  void setTuner(bool on, {bool mute = false}) => _tunerSet(on ? 1 : 0, mute ? 1 : 0);
  @override
  double tunerFrequency() => _tunerFreq();
  @override
  void looperCommand(int cmd) => _looperCmd(cmd);
  @override
  int looperState() => _looperState();
  @override
  double looperProgress() => _looperProgress();
  @override
  double looperLength() => _looperLength();
  @override
  void setLooperLevel(double level) => _looperLevel(level);
}

/// Motor "mudo" para rodar a interface sem a biblioteca nativa.
class SilentEngine implements AudioEngine {
  SilentEngine(this._catalogJson);

  final String _catalogJson;
  int _next = 1;

  @override
  bool get isNative => false;
  @override
  String catalogJson() => _catalogJson;
  @override
  String lastError() => 'Motor de áudio nativo indisponível nesta plataforma.';
  @override
  int start({int inputDevice = 0, int outputDevice = 0}) => -100;
  @override
  void stop() {}
  @override
  bool get isRunning => false;
  @override
  AudioStats stats() => const AudioStats();
  @override
  int addBlock(String typeId, int model, int index) => _next++;
  @override
  bool removeBlock(int id) => true;
  @override
  bool moveBlock(int id, int newIndex) => true;
  @override
  void clearChain() {}
  @override
  void setParam(int id, int index, double value) {}
  @override
  void setBypass(int id, bool bypass) {}
  @override
  int loadIr(int id, String path) => -100;
  @override
  void clearIr(int id) {}
  @override
  void setInputGainDb(double db) {}
  @override
  void setOutputGainDb(double db) {}
  @override
  double takeInputPeak() => 0;
  @override
  double takeOutputPeak() => 0;
  @override
  void setTuner(bool on, {bool mute = false}) {}
  @override
  double tunerFrequency() => 0;
  @override
  void looperCommand(int cmd) {}
  @override
  int looperState() => LooperState.empty;
  @override
  double looperProgress() => 0;
  @override
  double looperLength() => 0;
  @override
  void setLooperLevel(double level) {}
}
