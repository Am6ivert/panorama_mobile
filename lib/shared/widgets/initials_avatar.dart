import 'package:flutter/material.dart';

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    required this.color,
    this.size = 42,
    this.fontSize = 14,
  });

  final String initials;
  final Color color;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * 0.31),
    ),
    child: Text(
      initials,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
  );
}
