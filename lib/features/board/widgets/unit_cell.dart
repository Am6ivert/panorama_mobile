import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/unit_model.dart';

/// Клетка шахматки. Цвет = статус, инициалы в углу = кто держит квартиру.
/// «Не для продажи» рисуется штриховкой (FR-06).
class UnitCell extends StatelessWidget {
  const UnitCell({
    super.key,
    required this.unit,
    required this.width,
    required this.dimmed,
    required this.highlighted,
    required this.onTap,
  });

  final UnitModel unit;
  final double width;
  final bool dimmed;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = unit.status;
    final compact = width < 56;

    return Opacity(
      opacity: dimmed ? 0.2 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: 56,
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
          decoration: BoxDecoration(
            color: status.background,
            border: Border.all(
              color: highlighted ? AppColors.brand : status.border,
              width: highlighted ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(11),
          ),
          child: status.isOffMarket
              ? CustomPaint(
                  painter: _HatchPainter(status.border),
                  child: const Center(
                    child: Icon(
                      Icons.block,
                      size: 15,
                      color: AppColors.offMarketInk,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '№${unit.number}',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            height: 1,
                            color: status.foreground.withValues(alpha: 0.6),
                          ),
                        ),
                        if (unit.status.isTaken && unit.heldByName != null)
                          _HolderMark(name: unit.heldByName!, compact: compact),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.shortLayout,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            height: 1,
                            letterSpacing: -0.3,
                            color: status.foreground,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          compact ? '${unit.area}' : '${unit.area} м²',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            height: 1,
                            color: status.foreground.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HatchPainter extends CustomPainter {
  _HatchPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    const step = 7.0;
    for (var x = -size.height; x < size.width; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter oldDelegate) => oldDelegate.color != color;
}

class _HolderMark extends StatelessWidget {
  const _HolderMark({required this.name, required this.compact});

  final String name;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.fromSeed(name);
    final initials = name.characters.first.toUpperCase();

    if (compact) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w800,
          height: 1,
          color: Colors.white,
        ),
      ),
    );
  }
}
