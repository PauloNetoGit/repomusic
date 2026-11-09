import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/catalog.dart';
import '../../models/rig.dart';
import '../theme.dart';
import 'knob.dart';

/// Um bloco da cadeia desenhado como o equipamento real: gabinete de pedal,
/// cabeçote com painel de latão, cubo de tweed ou caixa com tecido de grade.
/// Os mini-knobs mostram as posições reais dos parâmetros.
class BlockCard extends StatelessWidget {
  const BlockCard({
    super.key,
    required this.block,
    required this.def,
    required this.onTap,
    required this.onToggle,
    this.dragHandle,
    this.isIr = false,
  });

  final RigBlock block;
  final BlockDef def;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final Widget? dragHandle;
  final bool isIr;

  @override
  Widget build(BuildContext context) {
    final on = !block.bypass;
    final body = switch (def.category) {
      'amp' => _AmpBody(this),
      'combo' => _ComboBody(this),
      'cab' => _CabBody(this),
      _ => _PedalBody(this),
    };
    return Semantics(
      button: true,
      label: '${def.displayName(block.model)}, ${on ? 'ligado' : 'desligado'}',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: on ? 1 : 0.6,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: body),
        ),
      ),
    );
  }
}

/// Rótulo curto para o mini-knob (cabe em ~40 px).
String _short(String name) {
  const abbr = {
    'Repetições': 'Repet.',
    'Profundidade': 'Prof.',
    'Velocidade': 'Veloc.',
    'Realimentação': 'Realim.',
    'Sensibilidade': 'Sensib.',
    'Ressonância': 'Resson.',
    'Liberação': 'Liber.',
    'Decaimento': 'Decai.',
    'Pré-atraso': 'Pré',
    'Distorção': 'Dist.',
    'Presença': 'Pres.',
    'Microfone': 'Mic',
    'Corte graves': 'C. grav.',
    'Corte agudos': 'C. agud.',
    'Freq. médios': 'Freq.',
    'Oitava -1': '-1 oit.',
    'Oitava -2': '-2 oit.',
    'Limiar': 'Limiar',
  };
  final a = abbr[name];
  if (a != null) return a;
  return name.length <= 7 ? name : '${name.substring(0, 5)}.';
}

/// Mini-knobs dos parâmetros contínuos que cabem na largura disponível.
List<Widget> _miniKnobs(BlockCard c, double width, KnobStyle style, Color labelColor, {int max = 4}) {
  final idx = <int>[
    for (var i = 0; i < c.def.params.length; i++)
      if (!c.def.params[i].isSwitch) i,
  ];
  final n = math.min(idx.length, math.min(max, (width / 42).floor()));
  return [
    for (final i in idx.take(math.max(0, n)))
      MiniKnob(
        value: c.def.params[i].toNormalized(c.block.params[i]),
        label: _short(c.def.params[i].name),
        style: style,
        labelColor: labelColor,
      ),
  ];
}

String _switchSummary(BlockCard c) => [
  for (var i = 0; i < c.def.params.length; i++)
    if (c.def.params[i].isSwitch) c.def.params[i].format(c.block.params[i]),
].join(', ');

// ---------------------------------------------------------------- pedal
class _PedalBody extends StatelessWidget {
  const _PedalBody(this.c);
  final BlockCard c;

  @override
  Widget build(BuildContext context) {
    final color = Color(c.def.color);
    final fg = onColor(color);
    final sw = _switchSummary(c);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.10)!, Color.lerp(color, Colors.black, 0.22)!],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            SizedBox(
              width: math.min(150, box.maxWidth * 0.38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(c.def.name, maxLines: 2, style: AppText.gear(22, color: fg)),
                  const SizedBox(height: 3),
                  Text(
                    sw.isEmpty ? c.def.group : sw,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _miniKnobs(c, box.maxWidth - math.min(150, box.maxWidth * 0.38) - 100, KnobStyle.pedal, fg),
              ),
            ),
            _Stomp(on: !c.block.bypass, onTap: c.onToggle),
            if (c.dragHandle != null) c.dragHandle!,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- amplificador
class _AmpBody extends StatelessWidget {
  const _AmpBody(this.c);
  final BlockCard c;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2B2B2B), AppColors.tolex],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.def.displayName(c.block.model),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.gear(23),
                      ),
                      const SizedBox(height: 2),
                      Text(c.def.name, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                _Stomp(on: !c.block.bypass, onTap: c.onToggle),
                if (c.dragHandle != null) c.dragHandle!,
              ],
            ),
          ),
          _Faceplate(c: c),
        ],
      ),
    );
  }
}

/// Painel de latão com os knobs "chicken-head".
class _Faceplate extends StatelessWidget {
  const _Faceplate({required this.c});
  final BlockCard c;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(colors: [Color(0xFFD8B56E), AppColors.brass, Color(0xFFA9853F)]),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _miniKnobs(c, box.maxWidth, KnobStyle.chickenHead, AppColors.ink, max: 7),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- cubo
class _ComboBody extends StatelessWidget {
  const _ComboBody(this.c);
  final BlockCard c;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
        color: AppColors.tweed,
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _WeavePainter(const Color(0x22000000), step: 3))),
          Column(
            children: [
              _Faceplate(c: c),
              Container(
                height: 64,
                margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3A2E22),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF5C4630)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _WeavePainter(const Color(0x33E6D2A8)))),
                    Padding(
                      padding: const EdgeInsets.only(left: 12, right: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.def.displayName(c.block.model),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.gear(22, color: const Color(0xFFF1E4C6)),
                            ),
                          ),
                          _Stomp(on: !c.block.bypass, onTap: c.onToggle),
                          if (c.dragHandle != null) c.dragHandle!,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- caixa
class _CabBody extends StatelessWidget {
  const _CabBody(this.c);
  final BlockCard c;

  @override
  Widget build(BuildContext context) {
    final mic = c.def.paramIndex('Microfone');
    final detail = c.isIr
        ? 'IR: ${c.block.irName}'
        : mic >= 0
        ? 'Microfone ${c.def.params[mic].format(c.block.params[mic])} da borda'
        : c.def.name;
    return Container(
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black),
        color: const Color(0xFF17171A),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _WeavePainter(const Color(0x1FFFFFFF)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [Color(0xFFD8B56E), Color(0xFFA9853F)]),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.def.displayName(c.block.model),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.gear(18, color: AppColors.ink),
                        ),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.ink, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _Stomp(on: !c.block.bypass, onTap: c.onToggle),
                if (c.dragHandle != null) c.dragHandle!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- peças comuns
/// Footswitch de metal com a lâmpada piloto logo acima.
class _Stomp extends StatelessWidget {
  const _Stomp({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: on ? 'Desligar' : 'Ligar',
      child: InkResponse(
        onTap: onTap,
        radius: 30,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PilotLamp(on: on),
              const SizedBox(height: 6),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0xFFF2F2F4), Color(0xFF9A9AA2), Color(0xFF55555C)],
                    stops: [0.0, 0.55, 1.0],
                    center: Alignment(-0.3, -0.35),
                  ),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                ),
                child: Center(
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black.withValues(alpha: 0.18)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lâmpada piloto vermelha.
class PilotLamp extends StatelessWidget {
  const PilotLamp({super.key, required this.on, this.size = 9});
  final bool on;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? AppColors.led : const Color(0xFF3B1714),
        boxShadow: on
            ? [BoxShadow(color: AppColors.led.withValues(alpha: 0.75), blurRadius: 8, spreadRadius: 1)]
            : null,
      ),
    );
  }
}

/// Cabo de patch entre dois blocos: o sinal passa por ele, de cima para baixo.
class PatchCable extends StatelessWidget {
  const PatchCable({super.key, this.height = 22});
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _CablePainter()),
  );
}

class _CablePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * 0.5;
    final path = Path()
      ..moveTo(x, 0)
      ..cubicTo(x + 10, size.height * 0.35, x - 10, size.height * 0.65, x, size.height);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF0C0C0E),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF3E4149),
    );
  }

  @override
  bool shouldRepaint(_CablePainter old) => false;
}

/// Ponta da cadeia: entrada da guitarra ou saída para os fones/interface.
class JackLabel extends StatelessWidget {
  const JackLabel({super.key, required this.text, required this.icon});
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0C0C0E),
            border: Border.all(color: const Color(0xFF8E8E96), width: 3),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      ],
    );
  }
}

/// Trama de tecido (grade de caixa, tweed).
class _WeavePainter extends CustomPainter {
  _WeavePainter(this.color, {this.step = 5});
  final Color color;
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), p);
    }
  }

  @override
  bool shouldRepaint(_WeavePainter old) => old.color != color || old.step != step;
}
