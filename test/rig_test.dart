// Testes de lógica pura (não precisam do motor nativo): catálogo, presets e afinador.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pedaleira/engine/catalog.dart';
import 'package:pedaleira/models/rig.dart';
import 'package:pedaleira/state/factory_presets.dart';
import 'package:pedaleira/ui/tuner_screen.dart';

void main() {
  final catalog = Catalog.fromJsonString(File('assets/catalog.json').readAsStringSync());

  test('catálogo tem todas as categorias', () {
    expect(catalog.inCategory('pedal').length, greaterThan(10));
    expect(catalog.byId('amp')!.models.length, greaterThanOrEqualTo(8));
    expect(catalog.byId('combo')!.models, isNotEmpty);
    expect(catalog.byId('cab')!.models[catalog.irModel].name, contains('IR'));
  });

  test('knob log/linear ida e volta', () {
    for (final b in catalog.blocks) {
      for (final p in b.params.where((p) => !p.isSwitch)) {
        for (final v in [p.min, p.def, p.max]) {
          expect(p.fromNormalized(p.toNormalized(v)), closeTo(v, (p.max - p.min) * 1e-6 + 1e-9));
        }
      }
    }
  });

  test('biblioteca de fábrica sem nomes de parâmetro/modelo errados', () {
    expect(validateFactoryPresets(catalog), isEmpty);
  });

  test('presets de fábrica sobrevivem a JSON', () {
    final presets = buildFactoryPresets(catalog);
    expect(presets.length, greaterThanOrEqualTo(100));
    for (final c in factoryCategories) {
      expect(presets.where((p) => p.category == c), isNotEmpty, reason: c);
    }
    for (final p in presets) {
      final again = Preset.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>, catalog);
      expect(again.blocks.length, p.blocks.length);
      for (var i = 0; i < p.blocks.length; i++) {
        expect(again.blocks[i].params, p.blocks[i].params);
        expect(again.blocks[i].model, p.blocks[i].model);
      }
    }
  });

  test('preset com bloco desconhecido e parâmetros faltando é corrigido', () {
    final p = Preset.fromJson({
      'name': 'x',
      'blocks': [
        {'type': 'nao_existe'},
        {
          'type': 'delay',
          'params': [99999],
        },
      ],
    }, catalog);
    expect(p.blocks.length, 1);
    final def = catalog.byId('delay')!;
    expect(p.blocks.first.params.first, def.params.first.max);
    expect(p.blocks.first.params.length, def.params.length);
  });

  test('afinador converte frequência em nota', () {
    final r = TunerReading.fromFrequency(82.41, 440)!;
    expect(r.note, 'E');
    expect(r.octave, 2);
    expect(r.cents.abs(), lessThan(1));
    expect(TunerReading.fromFrequency(445, 440)!.cents, closeTo(19.6, 0.5));
  });
}
