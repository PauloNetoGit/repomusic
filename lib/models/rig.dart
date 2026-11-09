// Estado serializável da pedaleira: blocos na ordem do sinal e presets.
import 'dart:math' as math;

import '../engine/catalog.dart';

String _newUid() {
  final r = math.Random();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${r.nextInt(1 << 30).toRadixString(36)}';
}

class RigBlock {
  RigBlock({
    String? uid,
    required this.typeId,
    this.model = 0,
    required this.params,
    this.bypass = false,
    this.irPath,
    this.irName,
  }) : uid = uid ?? _newUid();

  factory RigBlock.create(BlockDef def, int model) => RigBlock(typeId: def.id, model: model, params: def.defaults);

  /// Lê um bloco salvo, completando/limitando parâmetros com base no catálogo.
  /// Retorna null para tipos desconhecidos (ex.: preset de versão futura).
  static RigBlock? fromJson(Map<String, dynamic> j, Catalog catalog) {
    final def = catalog.byId(j['type'] as String? ?? '');
    if (def == null) return null;
    final saved = ((j['params'] as List?) ?? const []).map((e) => (e as num).toDouble()).toList();
    final params = <double>[
      for (var i = 0; i < def.params.length; i++) i < saved.length ? def.params[i].clamp(saved[i]) : def.params[i].def,
    ];
    final maxModel = def.hasModels ? def.models.length - 1 : 0;
    return RigBlock(
      typeId: def.id,
      model: ((j['model'] as num?)?.toInt() ?? 0).clamp(0, maxModel),
      params: params,
      bypass: j['bypass'] as bool? ?? false,
      irPath: j['irPath'] as String?,
      irName: j['irName'] as String?,
    );
  }

  final String uid;
  final String typeId;
  int model;
  List<double> params;
  bool bypass;
  String? irPath;
  String? irName;

  /// Id do bloco no motor nativo (não é salvo).
  int engineId = -1;

  Map<String, dynamic> toJson() => {
    'type': typeId,
    'model': model,
    'params': params,
    'bypass': bypass,
    if (irPath != null) 'irPath': irPath,
    if (irName != null) 'irName': irName,
  };

  RigBlock copy() =>
      RigBlock(typeId: typeId, model: model, params: List.of(params), bypass: bypass, irPath: irPath, irName: irName);
}

class Preset {
  Preset({required this.name, required this.blocks, this.factory = false, this.category, this.inspiration, this.tip});

  static Preset fromJson(Map<String, dynamic> j, Catalog catalog) => Preset(
    name: (j['name'] as String?)?.trim().isNotEmpty == true ? (j['name'] as String).trim() : 'Sem nome',
    blocks: [
      for (final b in ((j['blocks'] as List?) ?? const []))
        if (RigBlock.fromJson(b as Map<String, dynamic>, catalog) case final RigBlock rb) rb,
    ],
    category: j['category'] as String?,
    inspiration: j['inspiration'] as String?,
    tip: j['tip'] as String?,
  );

  String name;
  final List<RigBlock> blocks;
  final bool factory;

  /// Categoria na biblioteca (ex.: "Solos Lendários").
  final String? category;

  /// Música/artista que inspirou o timbre (só presets de fábrica).
  final String? inspiration;

  /// Dica de como tocar (captador, palhetada, volume da guitarra…).
  final String? tip;

  Map<String, dynamic> toJson() => {
    'format': 'pedaleira-preset',
    'version': 1,
    'name': name,
    if (category != null) 'category': category,
    if (inspiration != null) 'inspiration': inspiration,
    if (tip != null) 'tip': tip,
    'blocks': [for (final b in blocks) b.toJson()],
  };
}
