import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class _Room {
  const _Room(this.rect, this.label, this.area);

  final Rect rect;
  final String label;
  final double area;
}

class _Layout {
  const _Layout(this.size, this.rooms, this.windows);

  final Size size;
  final List<_Room> rooms;

  /// Отрезки окон по верхней стене: (x, ширина).
  final List<(double, double)> windows;
}

/// Схемы планировок по комнатности: метраж и состав комнат.
const _layouts = <int, _Layout>{
  0: _Layout(
    Size(104, 112),
    [
      _Room(Rect.fromLTWH(8, 8, 88, 64), 'Жилая комната', 20.4),
      _Room(Rect.fromLTWH(8, 76, 52, 28), 'Кухня-ниша', 7.2),
      _Room(Rect.fromLTWH(64, 76, 32, 28), 'С/у', 3.8),
    ],
    [(8, 88)],
  ),
  1: _Layout(
    Size(104, 120),
    [
      _Room(Rect.fromLTWH(8, 8, 88, 58), 'Гостиная', 19.8),
      _Room(Rect.fromLTWH(8, 70, 50, 42), 'Кухня', 12.4),
      _Room(Rect.fromLTWH(62, 70, 34, 20), 'С/у', 4.1),
      _Room(Rect.fromLTWH(62, 94, 34, 18), 'Прихожая', 5.0),
    ],
    [(8, 88)],
  ),
  2: _Layout(
    Size(150, 120),
    [
      _Room(Rect.fromLTWH(8, 8, 66, 54), 'Гостиная', 22.5),
      _Room(Rect.fromLTWH(78, 8, 64, 54), 'Спальня', 15.8),
      _Room(Rect.fromLTWH(8, 66, 66, 46), 'Кухня-столовая', 14.8),
      _Room(Rect.fromLTWH(78, 66, 30, 46), 'С/у', 4.6),
      _Room(Rect.fromLTWH(112, 66, 30, 46), 'Холл', 6.2),
    ],
    [(8, 66), (78, 64)],
  ),
  3: _Layout(
    Size(196, 124),
    [
      _Room(Rect.fromLTWH(8, 8, 62, 54), 'Гостиная', 26.0),
      _Room(Rect.fromLTWH(74, 8, 58, 54), 'Спальня 1', 15.2),
      _Room(Rect.fromLTWH(136, 8, 52, 54), 'Спальня 2', 13.4),
      _Room(Rect.fromLTWH(8, 66, 62, 50), 'Кухня', 16.2),
      _Room(Rect.fromLTWH(74, 66, 42, 50), 'С/у', 5.1),
      _Room(Rect.fromLTWH(120, 66, 30, 50), 'С/у 2', 3.2),
      _Room(Rect.fromLTWH(154, 66, 34, 50), 'Гардероб', 4.8),
    ],
    [(8, 62), (74, 58), (136, 52)],
  ),
  4: _Layout(
    Size(206, 132),
    [
      _Room(Rect.fromLTWH(8, 8, 60, 56), 'Гостиная', 30.2),
      _Room(Rect.fromLTWH(72, 8, 58, 56), 'Спальня 1', 16.4),
      _Room(Rect.fromLTWH(134, 8, 64, 56), 'Спальня 2', 15.1),
      _Room(Rect.fromLTWH(8, 68, 60, 56), 'Спальня 3', 14.0),
      _Room(Rect.fromLTWH(72, 68, 58, 32), 'Кухня', 18.0),
      _Room(Rect.fromLTWH(72, 104, 58, 20), 'С/у', 5.2),
      _Room(Rect.fromLTWH(134, 68, 64, 32), 'Холл', 9.4),
      _Room(Rect.fromLTWH(134, 104, 64, 20), 'С/у 2', 4.0),
    ],
    [(8, 60), (72, 58), (134, 64)],
  ),
};

class UnitPlan extends StatelessWidget {
  const UnitPlan({super.key, required this.rooms, this.showLabels = true});

  final int rooms;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final layout = _layouts[rooms] ?? _layouts[1]!;
    return AspectRatio(
      aspectRatio: layout.size.width / layout.size.height,
      child: CustomPaint(
        painter: _PlanPainter(layout: layout, showLabels: showLabels),
      ),
    );
  }
}

class _PlanPainter extends CustomPainter {
  _PlanPainter({required this.layout, required this.showLabels});

  final _Layout layout;
  final bool showLabels;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / layout.size.width;
    canvas.scale(scale);

    final outer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFF94A3B8);
    final fill = Paint()..color = const Color(0xFFEEF3FB);
    final wall = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xFFB9CBE8);
    final window = Paint()
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF38BDF8);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, layout.size.width - 8, layout.size.height - 8),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white,
    );

    for (final room in layout.rooms) {
      final rect = RRect.fromRectAndRadius(
        room.rect,
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, wall);

      if (!showLabels) continue;
      _text(
        canvas,
        room.label,
        room.rect.center.translate(0, -4),
        6,
        FontWeight.w600,
        const Color(0xFF41506B),
        room.rect.width,
      );
      _text(
        canvas,
        '${room.area} м²',
        room.rect.center.translate(0, 3.5),
        5.5,
        FontWeight.w400,
        const Color(0xFF8798B4),
        room.rect.width,
      );
    }

    for (final (x, width) in layout.windows) {
      canvas.drawLine(Offset(x + 4, 4), Offset(x + width - 4, 4), window);
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 4, layout.size.width - 8, layout.size.height - 8),
        const Radius.circular(3),
      ),
      outer,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    double fontSize,
    FontWeight weight,
    Color color,
    double maxWidth,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth - 2);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_PlanPainter oldDelegate) =>
      oldDelegate.layout != layout || oldDelegate.showLabels != showLabels;
}

/// Горизонтальная лента с планировкой и видами квартиры.
class UnitGallery extends StatelessWidget {
  const UnitGallery({super.key, required this.rooms, required this.cover});

  final int rooms;
  final Gradient cover;

  static const _shots = [
    ('Вид из окна', [Color(0xFF0EA5E9), Color(0xFF67E8F9)]),
    ('Отделка', [Color(0xFF78716C), Color(0xFFD6D3D1)]),
    ('Двор', [Color(0xFF166534), Color(0xFF86EFAC)]),
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 96,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        Container(
          width: 132,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: UnitPlan(rooms: rooms, showLabels: false)),
        ),
        const SizedBox(width: 8),
        _Shot(label: 'Фасад дома', gradient: cover),
        for (final (label, colors) in _shots) ...[
          const SizedBox(width: 8),
          _Shot(
            label: label,
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ],
      ],
    ),
  );
}

class _Shot extends StatelessWidget {
  const _Shot({required this.label, required this.gradient});

  final String label;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) => Container(
    width: 132,
    padding: const EdgeInsets.all(8),
    alignment: Alignment.bottomLeft,
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        shadows: [Shadow(blurRadius: 3, color: Color(0x66000000))],
      ),
    ),
  );
}
