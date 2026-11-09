// Teste de fumaça da interface usando o motor "mudo" (não precisa da lib nativa).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedaleira/engine/audio_engine.dart';
import 'package:pedaleira/main.dart';
import 'package:pedaleira/state/rig_controller.dart';
import 'package:pedaleira/ui/widgets/tape_label.dart';

void main() {
  testWidgets('abre a pedaleira com o preset inicial', (tester) async {
    final engine = SilentEngine(File('assets/catalog.json').readAsStringSync());
    final controller = RigController(engine: engine);
    await tester.runAsync(controller.init);
    await tester.pumpWidget(PedaleiraApp(controller: controller));
    await tester.pump();

    expect(find.byType(TapeLabel), findsOneWidget);
    expect(find.text(controller.presetName), findsOneWidget);
    expect(controller.blocks, isNotEmpty);
    expect(find.byIcon(Icons.power_settings_new), findsWidgets);
  });
}
