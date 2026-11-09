// Catálogo de blocos. A fonte da verdade é o motor nativo (ae_catalog_json);
// esta camada só interpreta o JSON e formata valores para a interface.
import 'dart:convert';
import 'dart:math' as math;

class ParamDef {
  const ParamDef({
    required this.name,
    required this.min,
    required this.max,
    required this.def,
    required this.unit,
    required this.steps,
    required this.labels,
  });

  factory ParamDef.fromJson(Map<String, dynamic> j) => ParamDef(
    name: j['name'] as String,
    min: (j['min'] as num).toDouble(),
    max: (j['max'] as num).toDouble(),
    def: (j['def'] as num).toDouble(),
    unit: (j['unit'] as String?) ?? '',
    steps: (j['steps'] as num?)?.toInt() ?? 0,
    labels: ((j['labels'] as List?) ?? const []).cast<String>(),
  );

  final String name;
  final double min;
  final double max;
  final double def;
  final String unit;
  final int steps;
  final List<String> labels;

  bool get isSwitch => steps > 0;

  /// Parâmetros de frequência usam escala logarítmica no knob.
  bool get isLog => unit == 'Hz' || (unit == 'ms' && max / math.max(min, 0.001) >= 50);

  double clamp(double v) => v.clamp(min, max).toDouble();

  /// Valor -> posição 0..1 do knob.
  double toNormalized(double v) {
    final c = clamp(v);
    if (isLog && min > 0) return math.log(c / min) / math.log(max / min);
    return max == min ? 0 : (c - min) / (max - min);
  }

  /// Posição 0..1 do knob -> valor.
  double fromNormalized(double t) {
    final n = t.clamp(0.0, 1.0);
    if (isLog && min > 0) return min * math.pow(max / min, n).toDouble();
    return min + (max - min) * n;
  }

  String format(double v) {
    if (isSwitch) {
      final i = v.round().clamp(0, labels.length - 1);
      return labels.isEmpty ? '$i' : labels[i];
    }
    switch (unit) {
      case '%':
        return '${(v * 100).round()}%';
      case 'Hz':
        return v >= 1000 ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)}k Hz' : '${v.round()} Hz';
      case 'ms':
        return v < 10 ? '${v.toStringAsFixed(1)} ms' : '${v.round()} ms';
      case 's':
        return '${v.toStringAsFixed(1)} s';
      case 'dB':
        if (v <= -59.9 && min <= -60) return '-∞ dB';
        return '${v > 0 ? '+' : ''}${v.toStringAsFixed(1)} dB';
      case ':1':
        return '${v.toStringAsFixed(1)}:1';
      default:
        if (min == 0 && max == 10) return v.toStringAsFixed(1);
        return v.toStringAsFixed(2);
    }
  }
}

class ModelDef {
  const ModelDef(this.name, this.desc);
  final String name;
  final String desc;
}

class BlockDef {
  const BlockDef({
    required this.id,
    required this.name,
    required this.category,
    required this.group,
    required this.color,
    required this.desc,
    required this.params,
    required this.models,
  });

  factory BlockDef.fromJson(Map<String, dynamic> j) {
    final hex = (j['color'] as String? ?? '#444444').replaceFirst('#', '');
    return BlockDef(
      id: j['id'] as String,
      name: j['name'] as String,
      category: j['category'] as String,
      group: (j['group'] as String?) ?? '',
      color: 0xFF000000 | (int.tryParse(hex, radix: 16) ?? 0x444444),
      desc: (j['desc'] as String?) ?? '',
      params: [for (final p in (j['params'] as List)) ParamDef.fromJson(p as Map<String, dynamic>)],
      models: [
        for (final m in ((j['models'] as List?) ?? const []))
          ModelDef((m as Map<String, dynamic>)['name'] as String, (m['desc'] as String?) ?? ''),
      ],
    );
  }

  final String id;
  final String name;
  final String category; // pedal | amp | combo | cab
  final String group;
  final int color; // ARGB
  final String desc;
  final List<ParamDef> params;
  final List<ModelDef> models;

  bool get hasModels => models.isNotEmpty;
  List<double> get defaults => [for (final p in params) p.def];

  String displayName(int model) => hasModels ? models[model.clamp(0, models.length - 1)].name : name;
  String description(int model) {
    if (!hasModels) return desc;
    final d = models[model.clamp(0, models.length - 1)].desc;
    return d.isEmpty ? desc : d;
  }

  int paramIndex(String name) => params.indexWhere((p) => p.name == name);
}

class Catalog {
  Catalog(this.blocks, {required this.irModel});

  factory Catalog.fromJsonString(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    return Catalog([
      for (final b in (j['blocks'] as List)) BlockDef.fromJson(b as Map<String, dynamic>),
    ], irModel: (j['irModel'] as num?)?.toInt() ?? -1);
  }

  final List<BlockDef> blocks;

  /// Índice do modelo de caixa "IR Personalizado".
  final int irModel;

  BlockDef? byId(String id) {
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    return null;
  }

  List<BlockDef> inCategory(String c) => [
    for (final b in blocks)
      if (b.category == c) b,
  ];

  /// Ordem sugerida no sinal: dinâmica → filtros → drives → amp → caixa → modulação → tempo.
  static int signalRank(BlockDef d) {
    switch (d.category) {
      case 'amp':
      case 'combo':
        return 30;
      case 'cab':
        return 40;
    }
    switch (d.group) {
      case 'Dinâmica':
        return d.id == 'gate' ? 0 : 5;
      case 'Filtro':
        return 10;
      case 'Drive':
        return 20;
      case 'Modulação':
        return 50;
      case 'Tempo':
        return d.id == 'reverb' ? 65 : 60;
      default:
        return 70;
    }
  }
}
