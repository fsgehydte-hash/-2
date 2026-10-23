import 'package:flutter/material.dart';

import '../core/theme.dart';

/// شعار مؤقت (أيقونة ورقة خضراء) إلى أن يُرفع الشعار الرسمي من الإعدادات.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 72});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Brand.green, shape: BoxShape.circle),
        child: Icon(Icons.eco, color: Brand.ivory, size: size * 0.58),
      );
}
