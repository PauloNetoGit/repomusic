import 'package:flutter/material.dart';

import '../theme.dart';

/// Pedaço de fita crepe com o nome escrito a marcador, como os músicos
/// etiquetam a pedaleira no palco.
class TapeLabel extends StatelessWidget {
  const TapeLabel({super.key, required this.text, this.modified = false});

  final String text;
  final bool modified;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.014,
      child: ClipPath(
        clipper: _TornEdges(),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 8, 20, 6),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF1EBDC), AppColors.tape, Color(0xFFDDD4BF)],
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              modified ? '$text*' : text,
              maxLines: 1,
              style: const TextStyle(fontFamily: AppFonts.marker, fontSize: 24, color: AppColors.ink, height: 1.25),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bordas laterais rasgadas.
class _TornEdges extends CustomClipper<Path> {
  @override
  Path getClip(Size s) {
    const teeth = [0.0, 3.0, 1.0, 4.0, 0.5, 2.5, 0.0, 3.5, 1.5, 0.0];
    final p = Path()..moveTo(0, 0);
    p.lineTo(s.width, 0);
    for (var i = 0; i < teeth.length; i++) {
      p.lineTo(s.width - teeth[i], s.height * (i + 1) / teeth.length);
    }
    p.lineTo(0, s.height);
    for (var i = teeth.length - 1; i >= 0; i--) {
      p.lineTo(teeth[(i + 3) % teeth.length], s.height * i / teeth.length);
    }
    return p..close();
  }

  @override
  bool shouldReclip(_TornEdges old) => false;
}
