import 'package:flutter/material.dart';
import '../../core/constants/app_text_styles.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding ?? const EdgeInsets.fromLTRB(16, 20, 16, 10),
    child: Text(text.toUpperCase(), style: AppTextStyles.section),
  );
}

/// Точка статуса со счётчиком: «● Свободно 93».
class StatusCount extends StatelessWidget {
  const StatusCount({
    super.key,
    required this.color,
    required this.label,
    required this.count,
  });

  final Color color;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 11.5, color: Color(0xFF5B6778)),
      ),
      const SizedBox(width: 4),
      Text(
        '$count',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    ],
  );
}
