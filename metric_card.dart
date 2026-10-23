import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.note,
  });
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? note;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleSmall)),
              ]),
              const SizedBox(height: 12),
              // الأرقام تُكتب دائماً من اليسار لليمين لتبقى مقروءة داخل واجهة RTL.
              Text(value,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(note!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      );
}
