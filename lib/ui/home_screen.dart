import 'package:flutter/material.dart';

import '../state/rig_controller.dart';
import 'block_editor.dart';
import 'catalog_sheet.dart';
import 'presets_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'tuner_screen.dart';
import 'widgets/block_card.dart';
import 'widgets/meters.dart';
import 'widgets/tape_label.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});
  final RigController controller;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _add(BuildContext context) async {
    final uid = await showCatalog(context, controller);
    if (uid != null && context.mounted) await showBlockEditor(context, controller, uid);
  }

  Future<void> _step(BuildContext context, int delta) async {
    if (controller.modified) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Trocar de preset?'),
          content: const Text('Os ajustes que você fez neste preset ainda não foram salvos.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Continuar aqui')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Trocar')),
          ],
        ),
      );
      if (ok != true) return;
    }
    await controller.stepPreset(delta);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  controller: c,
                  onPresets: () => _open(context, PresetsScreen(controller: c)),
                  onTuner: () => _open(context, TunerScreen(controller: c)),
                  onSettings: () => _open(context, SettingsScreen(controller: c)),
                  onStep: (d) => _step(context, d),
                ),
                StatusStrip(controller: c),
                if (c.audioError != null)
                  _Notice(
                    text: c.audioError!,
                    action: 'Abrir ajustes',
                    onAction: () => _open(context, SettingsScreen(controller: c)),
                  ),
                if (!c.hasNativeEngine)
                  const _Notice(
                    text: 'Sem o motor de áudio nesta plataforma: a interface funciona, mas o som só sai no Android.',
                  ),
                const Divider(height: 1),
                Expanded(
                  child: c.blocks.isEmpty ? _Empty(onAdd: () => _add(context)) : _Board(controller: c),
                ),
              ],
            ),
          ),
          floatingActionButton: c.blocks.isEmpty
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: AppColors.brass,
                  foregroundColor: AppColors.ink,
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  _PowerSwitch(controller: c),
                  const SizedBox(width: 12),
                  Expanded(child: LooperBar(controller: c)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onPresets,
    required this.onTuner,
    required this.onSettings,
    required this.onStep,
  });

  final RigController controller;
  final VoidCallback onPresets;
  final VoidCallback onTuner;
  final VoidCallback onSettings;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final p = controller.currentPreset;
    final String sub;
    if (p?.inspiration != null) {
      sub = 'Inspirado em ${formatInspiration(p!.inspiration!)}';
    } else if (p?.category != null) {
      sub = p!.category!;
    } else {
      sub = 'Toque na fita para escolher outro preset';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'Preset ${controller.presetName}. Abrir lista de presets',
                  child: GestureDetector(
                    onTap: onPresets,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TapeLabel(text: controller.presetName, modified: controller.modified),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(tooltip: 'Afinador', icon: const Icon(Icons.tune), onPressed: onTuner),
              IconButton(tooltip: 'Ajustes', icon: const Icon(Icons.settings_outlined), onPressed: onSettings),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                tooltip: 'Preset anterior',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onStep(-1),
              ),
              Expanded(
                child: Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppText.caption,
                ),
              ),
              IconButton(
                tooltip: 'Próximo preset',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onStep(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Board extends StatelessWidget {
  const _Board({required this.controller});
  final RigController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 110),
      header: const Column(
        children: [
          JackLabel(text: 'Guitarra', icon: Icons.music_note),
          PatchCable(),
        ],
      ),
      footer: const Padding(
        padding: EdgeInsets.only(top: 2),
        child: JackLabel(text: 'Fones ou interface', icon: Icons.headphones),
      ),
      itemCount: c.blocks.length,
      // onReorder funciona em todas as versões 3.x do Flutter (onReorderItem só existe a partir da 3.41).
      // ignore: deprecated_member_use
      onReorder: c.reorder,
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) => Material(
        color: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
      itemBuilder: (context, i) {
        final b = c.blocks[i];
        final def = c.defOf(b);
        return Column(
          key: ValueKey(b.uid),
          children: [
            BlockCard(
              block: b,
              def: def,
              isIr: def.id == 'cab' && b.model == c.catalog.irModel && b.irName != null,
              onTap: () => showBlockEditor(context, c, b.uid),
              onToggle: () => c.toggleBypass(b.uid),
              dragHandle: ReorderableDragStartListener(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                  child: Icon(
                    Icons.drag_indicator,
                    color: (def.category == 'pedal' ? onColor(Color(def.color)) : AppColors.text).withValues(
                      alpha: 0.55,
                    ),
                    semanticLabel: 'Arrastar para reordenar',
                  ),
                ),
              ),
            ),
            const PatchCable(),
          ],
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF3A2321),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// O footswitch principal: liga e desliga o áudio.
class _PowerSwitch extends StatelessWidget {
  const _PowerSwitch({required this.controller});
  final RigController controller;

  @override
  Widget build(BuildContext context) {
    final on = controller.audioOn;
    return Semantics(
      button: true,
      toggled: on,
      label: on ? 'Desligar o áudio' : 'Ligar o áudio',
      child: InkResponse(
        onTap: controller.starting ? null : controller.toggleAudio,
        radius: 36,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: on ? AppColors.led : AppColors.line, width: 2),
                boxShadow: on ? [BoxShadow(color: AppColors.led.withValues(alpha: 0.45), blurRadius: 14)] : null,
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFFF2F2F4), Color(0xFF9A9AA2), Color(0xFF55555C)],
                    stops: [0.0, 0.55, 1.0],
                    center: Alignment(-0.3, -0.35),
                  ),
                ),
                child: controller.starting
                    ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(Icons.power_settings_new, size: 22, color: on ? AppColors.led : const Color(0xFF3A3A40)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const JackLabel(text: 'Guitarra', icon: Icons.music_note),
            const PatchCable(height: 40),
            Text('A pedaleira está vazia', style: AppText.gear(28)),
            const SizedBox(height: 8),
            const Text(
              'Escolha um preset tocando na fita lá em cima, ou monte o seu: pedais, um amplificador ou cubo e uma caixa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Adicionar equipamento'),
            ),
          ],
        ),
      ),
    );
  }
}
