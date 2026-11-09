import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/rig_controller.dart';
import 'theme.dart';

const _noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

class TunerReading {
  const TunerReading(this.note, this.octave, this.cents, this.freq);
  final String note;
  final int octave;
  final double cents;
  final double freq;

  static TunerReading? fromFrequency(double f, double a4) {
    if (f <= 0 || !f.isFinite) return null;
    final midiF = 69 + 12 * math.log(f / a4) / math.ln2;
    final midi = midiF.round();
    return TunerReading(_noteNames[midi % 12], midi ~/ 12 - 1, (midiF - midi) * 100, f);
  }
}

class TunerScreen extends StatefulWidget {
  const TunerScreen({super.key, required this.controller});
  final RigController controller;

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> {
  Timer? _timer;
  final _history = <double>[];
  TunerReading? _reading;
  int _silent = 0;
  double _shownCents = 0;

  RigController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.tunerOn();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    c.tunerOff();
    super.dispose();
  }

  void _poll() {
    final f = c.tunerFrequency();
    if (f <= 0) {
      if (++_silent > 12 && _reading != null) setState(() => _reading = null);
      return;
    }
    _silent = 0;
    // Mediana das últimas leituras: descarta saltos de oitava ocasionais.
    _history.add(f);
    if (_history.length > 5) _history.removeAt(0);
    final sorted = List<double>.of(_history)..sort();
    final med = sorted[sorted.length ~/ 2];
    final r = TunerReading.fromFrequency(med, c.settings.a4);
    if (r == null) return;
    setState(() {
      _reading = r;
      _shownCents += (r.cents - _shownCents) * 0.5;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _reading;
    final inTune = r != null && r.cents.abs() < 3;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Afinador')),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                if (!c.audioOn)
                  Card(
                    color: AppColors.surface2,
                    child: ListTile(
                      leading: const Icon(Icons.power_settings_new),
                      title: const Text('Ligue o áudio para afinar'),
                      trailing: FilledButton(onPressed: c.startAudio, child: const Text('Ligar')),
                    ),
                  ),
                const Spacer(),
                Text(
                  r?.note ?? '–',
                  style: AppText.gear(
                    150,
                    color: r == null ? AppColors.line : (inTune ? AppColors.ok : AppColors.text),
                  ),
                ),
                Text(
                  r == null ? 'Toque uma corda' : '${r.note}${r.octave} · ${r.freq.toStringAsFixed(1)} Hz',
                  style: const TextStyle(color: AppColors.muted, fontSize: 16),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  height: 90,
                  width: double.infinity,
                  child: CustomPaint(painter: _NeedlePainter(r == null ? null : _shownCents, inTune)),
                ),
                const SizedBox(height: 8),
                Text(
                  r == null ? '' : '${_shownCents >= 0 ? '+' : ''}${_shownCents.toStringAsFixed(0)} cents',
                  style: TextStyle(fontSize: 18, color: inTune ? AppColors.ok : AppColors.text),
                ),
                const Spacer(),
                SwitchListTile(
                  title: const Text('Silenciar saída ao afinar'),
                  value: c.settings.tunerMute,
                  onChanged: c.setTunerMute,
                ),
                Row(
                  children: [
                    const Text('Referência A4'),
                    Expanded(
                      child: Slider(
                        min: 430,
                        max: 450,
                        divisions: 20,
                        value: c.settings.a4,
                        label: '${c.settings.a4.round()} Hz',
                        onChanged: (v) => c.setA4(v),
                      ),
                    ),
                    Text('${c.settings.a4.round()} Hz'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Escala de LEDs de -50 a +50 cents; o do centro acende verde quando afinado.
class _NeedlePainter extends CustomPainter {
  _NeedlePainter(this.cents, this.inTune);
  final double? cents;
  final bool inTune;

  static const _count = 21; // 5 cents por LED

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 5.0;
    final w = (size.width - gap * (_count - 1)) / _count;
    final ct = cents;
    final lit = ct == null ? -1 : ((ct.clamp(-50.0, 50.0) + 50) / 5).round().clamp(0, _count - 1);
    for (var i = 0; i < _count; i++) {
      final center = i == _count ~/ 2;
      final dist = (i - _count ~/ 2).abs();
      final h = size.height * (center ? 1.0 : (0.75 - dist * 0.025));
      final color = center ? AppColors.ok : (dist <= 2 ? AppColors.warn : AppColors.led);
      final on = i == lit || (inTune && center);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(i * (w + gap), (size.height - h) / 2, w, h),
        const Radius.circular(3),
      );
      canvas.drawRRect(r, Paint()..color = on ? color : color.withValues(alpha: 0.12));
      if (on) {
        canvas.drawRRect(
          r.inflate(2),
          Paint()
            ..color = color.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => old.cents != cents || old.inTune != inTune;
}
