import 'package:flutter/material.dart';

import '../engine/catalog.dart';
import '../models/rig.dart';
import '../state/rig_controller.dart';
import 'theme.dart';
import 'widgets/block_card.dart';
import 'widgets/knob.dart';

Future<void> showBlockEditor(BuildContext context, RigController c, String uid) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    showDragHandle: true,
    builder: (_) => BlockEditor(controller: c, uid: uid),
  );
}

class BlockEditor extends StatefulWidget {
  const BlockEditor({super.key, required this.controller, required this.uid});
  final RigController controller;
  final String uid;

  @override
  State<BlockEditor> createState() => _BlockEditorState();
}

class _BlockEditorState extends State<BlockEditor> {
  final _taps = <DateTime>[];
  bool _loadingIr = false;

  RigController get c => widget.controller;

  void _tap(RigBlock b, BlockDef def) {
    final now = DateTime.now();
    if (_taps.isNotEmpty && now.difference(_taps.last).inMilliseconds > 2000) _taps.clear();
    _taps.add(now);
    if (_taps.length > 5) _taps.removeAt(0);
    if (_taps.length >= 2) {
      var sum = 0;
      for (var i = 1; i < _taps.length; i++) {
        sum += _taps[i].difference(_taps[i - 1]).inMilliseconds;
      }
      final ms = sum / (_taps.length - 1);
      final i = def.paramIndex('Tempo');
      if (i >= 0) c.setParam(b.uid, i, ms);
    }
    setState(() {});
  }

  Future<void> _loadIr(RigBlock b) async {
    setState(() => _loadingIr = true);
    final err = await c.pickAndLoadIr(b.uid);
    if (!mounted) return;
    setState(() => _loadingIr = false);
    if (err != null && err.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível carregar a IR: $err')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final b = c.byUid(widget.uid);
        if (b == null) return const SizedBox(height: 120);
        final def = c.defOf(b);
        final look = _FaceLook.of(def);
        final knobs = <Widget>[];
        final switches = <Widget>[];
        for (var i = 0; i < def.params.length; i++) {
          final p = def.params[i];
          if (p.isSwitch) {
            switches.add(_SwitchRow(param: p, value: b.params[i], onChanged: (v) => c.setParam(b.uid, i, v)));
          } else {
            knobs.add(
              Knob(
                value: p.toNormalized(b.params[i]),
                label: p.name,
                display: p.format(b.params[i]),
                color: look.arc,
                style: look.knob,
                labelColor: look.knobLabel,
                onChanged: (t) => c.setParam(b.uid, i, p.fromNormalized(t)),
                onReset: () => c.resetParam(b.uid, i),
              ),
            );
          }
        }
        final isCab = def.id == 'cab';
        final isIrModel = isCab && b.model == c.catalog.irModel;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Face(
                look: look,
                title: def.displayName(b.model),
                subtitle: def.hasModels ? def.name : def.group,
                on: !b.bypass,
                onToggle: (on) => c.setBypass(b.uid, !on),
                knobs: knobs,
              ),
              const SizedBox(height: 14),
              Text(def.description(b.model), style: AppText.caption.copyWith(fontSize: 13.5)),
              if (def.hasModels) ...[
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: def.category == 'cab' ? 'Caixa' : 'Modelo',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: b.model,
                      isExpanded: true,
                      dropdownColor: AppColors.surface2,
                      items: [
                        for (var m = 0; m < def.models.length; m++)
                          DropdownMenuItem(
                            value: m,
                            child: Text(def.models[m].name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (m) {
                        if (m != null) c.setModel(b.uid, m);
                      },
                    ),
                  ),
                ),
              ],
              if (switches.isNotEmpty) ...[const SizedBox(height: 16), ...switches],
              if (isCab) ...[
                const SizedBox(height: 16),
                _IrPanel(
                  block: b,
                  isIrModel: isIrModel,
                  loading: _loadingIr,
                  onLoad: () => _loadIr(b),
                  onClear: () => c.clearIr(b.uid),
                ),
              ],
              if (def.id == 'delay') ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  onPressed: () => _tap(b, def),
                  icon: const Icon(Icons.touch_app_outlined),
                  label: Text(
                    _taps.length >= 2
                        ? 'Tempo batido: ${b.params[0].round()} ms. Continue tocando para ajustar'
                        : 'Bata o tempo aqui, no ritmo da música',
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Arraste um knob para cima ou para baixo. Toque duas vezes para voltar ao valor de fábrica.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () {
                  Navigator.of(context).pop();
                  c.removeBlock(b.uid);
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Tirar da pedaleira'),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cores e estilo do "rosto" do equipamento no editor.
class _FaceLook {
  const _FaceLook({
    required this.decoration,
    required this.title,
    required this.knob,
    required this.knobLabel,
    required this.arc,
    this.panel,
  });

  /// Fundo do equipamento (gabinete, tolex, tweed, grade).
  final BoxDecoration decoration;
  final Color title;
  final KnobStyle knob;
  final Color knobLabel;
  final Color arc;

  /// Painel onde ficam os knobs (latão nos amplificadores).
  final BoxDecoration? panel;

  static _FaceLook of(BlockDef def) {
    const brassPanel = BoxDecoration(
      borderRadius: BorderRadius.all(Radius.circular(10)),
      gradient: LinearGradient(colors: [Color(0xFFD8B56E), AppColors.brass, Color(0xFFA9853F)]),
    );
    switch (def.category) {
      case 'amp':
        return const _FaceLook(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2E2E2E), AppColors.tolex],
            ),
          ),
          title: AppColors.text,
          knob: KnobStyle.chickenHead,
          knobLabel: AppColors.ink,
          arc: Color(0xFF5A3F12),
          panel: brassPanel,
        );
      case 'combo':
        return const _FaceLook(
          decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(16)), color: AppColors.tweed),
          title: Color(0xFFF6EBD0),
          knob: KnobStyle.chickenHead,
          knobLabel: AppColors.ink,
          arc: Color(0xFF5A3F12),
          panel: brassPanel,
        );
      case 'cab':
        return const _FaceLook(
          decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(16)), color: Color(0xFF17171A)),
          title: AppColors.text,
          knob: KnobStyle.pedal,
          knobLabel: AppColors.text,
          arc: AppColors.brass,
        );
      default:
        final color = Color(def.color);
        final fg = onColor(color);
        return _FaceLook(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            border: Border.all(color: Colors.black.withValues(alpha: 0.35)),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.white, 0.10)!, Color.lerp(color, Colors.black, 0.22)!],
            ),
          ),
          title: fg,
          knob: KnobStyle.pedal,
          knobLabel: fg,
          arc: fg == AppColors.ink ? AppColors.ink : AppColors.brass,
        );
    }
  }
}

/// O equipamento em tamanho grande, com os knobs no próprio gabinete.
class _Face extends StatelessWidget {
  const _Face({
    required this.look,
    required this.title,
    required this.subtitle,
    required this.on,
    required this.onToggle,
    required this.knobs,
  });

  final _FaceLook look;
  final String title;
  final String subtitle;
  final bool on;
  final ValueChanged<bool> onToggle;
  final List<Widget> knobs;

  @override
  Widget build(BuildContext context) {
    final knobArea = Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 18, children: knobs);
    return Container(
      decoration: look.decoration,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppText.gear(32, color: look.title)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: look.title.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              PilotLamp(on: on, size: 11),
              const SizedBox(width: 8),
              Switch(value: on, onChanged: onToggle),
            ],
          ),
          if (knobs.isNotEmpty) ...[
            const SizedBox(height: 16),
            if (look.panel != null)
              Container(
                decoration: look.panel,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                child: knobArea,
              )
            else
              knobArea,
          ],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.param, required this.value, required this.onChanged});
  final ParamDef param;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final sel = value.round().clamp(0, param.labels.length - 1);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(param.name, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (var i = 0; i < param.labels.length; i++) ButtonSegment(value: i, label: Text(param.labels[i])),
              ],
              selected: {sel},
              onSelectionChanged: (s) => onChanged(s.first.toDouble()),
            ),
          ),
        ],
      ),
    );
  }
}

class _IrPanel extends StatelessWidget {
  const _IrPanel({
    required this.block,
    required this.isIrModel,
    required this.loading,
    required this.onLoad,
    required this.onClear,
  });

  final RigBlock block;
  final bool isIrModel;
  final bool loading;
  final VoidCallback onLoad;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final name = isIrModel ? block.irName : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Resposta ao impulso (IR)', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            name != null
                ? 'Carregada: $name'
                : 'Carregue um arquivo .wav de IR de caixa (mono ou estéreo, qualquer taxa). '
                      'Os primeiros ~170 ms são usados.',
            style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading ? null : onLoad,
                  icon: loading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.folder_open),
                  label: Text(name == null ? 'Carregar IR' : 'Trocar IR'),
                ),
              ),
              if (name != null) ...[
                const SizedBox(width: 8),
                IconButton(tooltip: 'Remover IR', onPressed: onClear, icon: const Icon(Icons.close)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
