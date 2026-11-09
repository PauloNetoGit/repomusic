import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Aparência do knob, de acordo com o equipamento onde ele está.
enum KnobStyle {
  /// Knob preto com risco branco (pedais).
  pedal,

  /// "Chicken-head" preto com ponteiro creme (painéis de amplificador).
  chickenHead,
}

const _sweepStart = math.pi * 0.75;
const _sweep = math.pi * 1.5;

/// Knob rotativo: arraste para cima/direita para aumentar, toque duplo volta ao padrão.
class Knob extends StatefulWidget {
  const Knob({
    super.key,
    required this.value,
    required this.label,
    required this.display,
    required this.onChanged,
    this.onReset,
    this.size = 68,
    this.color = AppColors.brass,
    this.style = KnobStyle.pedal,
    this.labelColor = AppColors.text,
  });

  /// Posição normalizada 0..1.
  final double value;
  final String label;
  final String display;
  final ValueChanged<double> onChanged;
  final VoidCallback? onReset;
  final double size;
  final Color color;
  final KnobStyle style;
  final Color labelColor;

  @override
  State<Knob> createState() => _KnobState();
}

class _KnobState extends State<Knob> {
  late double _v = widget.value;
  bool _dragging = false;

  @override
  void didUpdateWidget(Knob old) {
    super.didUpdateWidget(old);
    if (!_dragging) _v = widget.value;
  }

  void _update(Offset delta) {
    final nv = (_v + (delta.dx - delta.dy) / 220).clamp(0.0, 1.0);
    if (nv == _v) return;
    setState(() => _v = nv);
    widget.onChanged(nv);
  }

  @override
  Widget build(BuildContext context) {
    final lc = widget.labelColor;
    return Semantics(
      label: widget.label,
      value: widget.display,
      onIncrease: () => widget.onChanged((_v + 0.05).clamp(0.0, 1.0)),
      onDecrease: () => widget.onChanged((_v - 0.05).clamp(0.0, 1.0)),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => setState(() => _dragging = true),
        onPanUpdate: (d) => _update(d.delta),
        onPanEnd: (_) => setState(() => _dragging = false),
        onPanCancel: () => setState(() => _dragging = false),
        onDoubleTap: widget.onReset,
        child: SizedBox(
          width: widget.size + 26,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.gear(15, color: lc, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CustomPaint(
                  painter: KnobPainter(_v, color: widget.color, style: widget.style, active: _dragging, scale: lc),
                ),
              ),
              const SizedBox(height: 6),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 120),
                style: AppText.value.copyWith(color: _dragging ? widget.color : lc.withValues(alpha: 0.8)),
                child: Text(widget.display, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Desenha um knob. Usado em tamanho grande no editor e em miniatura nos cartões.
class KnobPainter extends CustomPainter {
  KnobPainter(
    this.value, {
    required this.color,
    required this.style,
    this.active = false,
    this.scale,
    this.mini = false,
  });

  final double value;
  final Color color;
  final KnobStyle style;
  final bool active;
  final bool mini;

  /// Cor da escala (marcas impressas no gabinete).
  final Color? scale;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final a = _sweepStart + _sweep * value.clamp(0.0, 1.0);
    final dir = Offset(math.cos(a), math.sin(a));

    if (!mini) {
      // Escala serigrafada: 11 marcas, como nos pedais (0 a 10).
      final tick = Paint()
        ..color = (scale ?? AppColors.text).withValues(alpha: 0.45)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i <= 10; i++) {
        final t = _sweepStart + _sweep * i / 10;
        final d = Offset(math.cos(t), math.sin(t));
        canvas.drawLine(c + d * (r - 1), c + d * (r - (i % 5 == 0 ? 7 : 4)), tick);
      }
      // Arco de valor.
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r - 11),
        _sweepStart,
        _sweep * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = active ? color : color.withValues(alpha: 0.75),
      );
    }

    final bodyR = mini ? r : r - 15;
    // Sombra projetada no gabinete.
    canvas.drawCircle(c + const Offset(0, 1.5), bodyR, Paint()..color = Colors.black.withValues(alpha: 0.35));

    if (style == KnobStyle.chickenHead) {
      // Saia redonda + "bico" longo apontando o valor.
      canvas.drawCircle(c, bodyR * 0.82, Paint()..color = const Color(0xFF161616));
      final tip = c + dir * bodyR;
      final back = c - dir * bodyR * 0.55;
      final side = Offset(-dir.dy, dir.dx) * bodyR * 0.34;
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(back.dx + side.dx, back.dy + side.dy)
        ..quadraticBezierTo(back.dx - dir.dx * 2, back.dy - dir.dy * 2, back.dx - side.dx, back.dy - side.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF1E1E1E));
      canvas.drawLine(
        c,
        tip - dir * 2,
        Paint()
          ..color = const Color(0xFFEDE3C8)
          ..strokeWidth = mini ? 1.6 : 2.6
          ..strokeCap = StrokeCap.round,
      );
    } else {
      final body = Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF4A4C52), Color(0xFF17181B)],
          center: Alignment(-0.35, -0.45),
        ).createShader(Rect.fromCircle(center: c, radius: bodyR));
      canvas.drawCircle(c, bodyR, body);
      canvas.drawCircle(
        c,
        bodyR,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: 0.08),
      );
      canvas.drawLine(
        c + dir * (bodyR * 0.2),
        c + dir * (bodyR * 0.86),
        Paint()
          ..strokeWidth = mini ? 1.8 : 3
          ..strokeCap = StrokeCap.round
          ..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(KnobPainter old) =>
      old.value != value || old.color != color || old.active != active || old.style != style || old.scale != scale;
}

/// Knob em miniatura, só para leitura (cartões da pedaleira).
class MiniKnob extends StatelessWidget {
  const MiniKnob({super.key, required this.value, required this.label, required this.style, required this.labelColor});

  final double value;
  final String label;
  final KnobStyle style;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: KnobPainter(value, color: AppColors.brass, style: style, mini: true),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            softWrap: false,
            style: AppText.gear(10.5, color: labelColor, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
