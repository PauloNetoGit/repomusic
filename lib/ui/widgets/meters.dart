import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/audio_engine.dart';
import '../../state/rig_controller.dart';
import '../theme.dart';

/// Medidor em escada de LEDs (-48..0 dBFS), como nas interfaces de áudio.
class LevelMeter extends StatelessWidget {
  const LevelMeter({super.key, required this.label, required this.level, this.segments = 16});

  final String label;
  final double level;
  final int segments;

  @override
  Widget build(BuildContext context) {
    final db = level <= 0 ? -100.0 : 20 * math.log(level) / math.ln10;
    return Semantics(
      label: '$label ${db < -60 ? 'sem sinal' : '${db.round()} dB'}',
      child: Row(
        children: [
          SizedBox(
            width: 46,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
          Expanded(
            child: SizedBox(height: 8, child: CustomPaint(painter: _LadderPainter(db, segments))),
          ),
        ],
      ),
    );
  }
}

class _LadderPainter extends CustomPainter {
  _LadderPainter(this.db, this.segments);
  final double db;
  final int segments;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 2.0;
    final w = (size.width - gap * (segments - 1)) / segments;
    for (var i = 0; i < segments; i++) {
      // cada segmento = 3 dB; o último acende ao chegar perto de 0 dBFS
      final threshold = -48 + i * 48 / segments;
      final lit = db >= threshold;
      final base = i >= segments - 1
          ? AppColors.danger
          : i >= segments - 4
          ? AppColors.warn
          : AppColors.ok;
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(i * (w + gap), 0, w, size.height), const Radius.circular(1.5));
      canvas.drawRRect(r, Paint()..color = lit ? base : base.withValues(alpha: 0.13));
    }
  }

  @override
  bool shouldRepaint(_LadderPainter old) => old.db != db;
}

class StatusStrip extends StatelessWidget {
  const StatusStrip({super.key, required this.controller});
  final RigController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EngineStatus>(
      valueListenable: controller.status,
      builder: (context, s, _) {
        final st = s.stats;
        final String info;
        if (!controller.audioOn) {
          info = 'Áudio desligado';
        } else if (st.sampleRate > 0) {
          info = '${(st.sampleRate / 1000).toStringAsFixed(1)} kHz\n${st.latencyMs.round()} ms';
        } else {
          info = 'Ligando…';
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    LevelMeter(label: 'Entrada', level: s.inLevel),
                    const SizedBox(height: 5),
                    LevelMeter(label: 'Saída', level: s.outLevel),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              SizedBox(
                width: 62,
                child: Text(
                  info,
                  textAlign: TextAlign.right,
                  style: AppText.caption.copyWith(fontSize: 11.5, height: 1.2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Controles do looper (gravar → tocar → sobrepor).
class LooperBar extends StatelessWidget {
  const LooperBar({super.key, required this.controller});
  final RigController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EngineStatus>(
      valueListenable: controller.status,
      builder: (context, s, _) {
        final st = s.looperState;
        final (IconData icon, String action, Color color) = switch (st) {
          LooperState.recording => (Icons.play_arrow_rounded, 'Tocar', AppColors.danger),
          LooperState.playing => (Icons.layers_outlined, 'Sobrepor', AppColors.ok),
          LooperState.overdub => (Icons.play_arrow_rounded, 'Tocar', AppColors.warn),
          LooperState.stopped => (Icons.play_arrow_rounded, 'Tocar', AppColors.muted),
          _ => (Icons.fiber_manual_record, 'Gravar', AppColors.danger),
        };
        final stateText = switch (st) {
          LooperState.recording => 'Gravando',
          LooperState.playing => 'Tocando',
          LooperState.overdub => 'Sobrepondo',
          LooperState.stopped => 'Loop parado',
          _ => controller.audioOn ? 'Looper vazio' : 'Looper',
        };
        final enabled = controller.audioOn;
        final hasLoop = st != LooperState.empty;
        return Row(
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.surface2,
                foregroundColor: AppColors.text,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: enabled ? () => controller.looper(LooperCmd.main) : null,
              icon: Icon(icon, color: enabled ? color : null),
              label: Text(action),
            ),
            IconButton(
              tooltip: 'Parar o loop',
              onPressed: enabled && hasLoop ? () => controller.looper(LooperCmd.stop) : null,
              icon: const Icon(Icons.stop_rounded),
            ),
            IconButton(
              tooltip: 'Apagar o loop',
              onPressed: enabled && hasLoop ? () => controller.looper(LooperCmd.clear) : null,
              icon: const Icon(Icons.delete_outline),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasLoop ? '$stateText, ${s.looperLength.toStringAsFixed(1)} s' : stateText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption.copyWith(fontSize: 12),
                  ),
                  const SizedBox(height: 5),
                  LinearProgressIndicator(
                    value: st == LooperState.recording ? null : s.looperProgress,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                    color: color,
                    backgroundColor: AppColors.line,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
