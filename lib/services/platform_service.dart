// Recursos do Android implementados em MainActivity.kt (sem plugins de terceiros).
import 'dart:io';

import 'package:flutter/services.dart';

class AudioDevice {
  const AudioDevice({
    required this.id,
    required this.name,
    required this.isInput,
    required this.isOutput,
    required this.type,
  });

  final int id;
  final String name;
  final bool isInput;
  final bool isOutput;
  final int type;

  /// AudioDeviceInfo.TYPE_BLUETOOTH_A2DP / TYPE_BLUETOOTH_SCO / TYPE_BLE_*
  bool get isBluetooth => type == 7 || type == 8 || type == 26 || type == 27 || type == 30;
}

class PickedFile {
  const PickedFile(this.path, this.name);
  final String path;
  final String name;
}

class PlatformService {
  static const _ch = MethodChannel('pedaleira/platform');

  bool get _android => Platform.isAndroid;

  Future<bool> requestMicPermission() async {
    if (!_android) return true;
    try {
      return await _ch.invokeMethod<bool>('requestMicPermission') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return true;
    }
  }

  Future<String> filesDir() async {
    if (_android) {
      try {
        final d = await _ch.invokeMethod<String>('filesDir');
        if (d != null) return d;
      } on MissingPluginException {
        // cai para o diretório temporário
      }
    }
    final dir = Directory('${Directory.systemTemp.path}/pedaleira');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  /// Abre o seletor de arquivos do sistema e copia o WAV para a pasta do app.
  /// Retorna null se o usuário cancelar; lança [PlatformException] se a cópia falhar.
  Future<PickedFile?> pickWav() async {
    if (!_android) return null;
    final r = await _ch.invokeMapMethod<String, dynamic>('pickWav');
    if (r == null) return null;
    return PickedFile(r['path'] as String, r['name'] as String);
  }

  Future<List<AudioDevice>> listDevices() async {
    if (!_android) return const [];
    try {
      final r = await _ch.invokeListMethod<dynamic>('listDevices') ?? const [];
      return [
        for (final d in r)
          AudioDevice(
            id: (d['id'] as num).toInt(),
            name: d['name'] as String,
            isInput: d['input'] as bool,
            isOutput: d['output'] as bool,
            type: (d['type'] as num).toInt(),
          ),
      ];
    } on PlatformException {
      return const [];
    }
  }

  Future<void> keepScreenOn(bool on) async {
    if (!_android) return;
    try {
      await _ch.invokeMethod<void>('keepScreenOn', on);
    } on PlatformException {
      // sem efeito
    }
  }

  /// Abre um link no app correspondente (ex.: Google Play).
  Future<bool> openUrl(String url) async {
    if (!_android) return false;
    try {
      return await _ch.invokeMethod<bool>('openUrl', url) ?? false;
    } on PlatformException {
      return false;
    }
  }

  Future<Map<String, dynamic>> deviceInfo() async {
    if (!_android) return const {};
    try {
      return await _ch.invokeMapMethod<String, dynamic>('deviceInfo') ?? const {};
    } on PlatformException {
      return const {};
    }
  }
}
