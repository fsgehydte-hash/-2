import 'package:flutter/material.dart';

import '../../core/strings.dart';

/// صفحة مؤقتة لأقسام المراحل اللاحقة؛ لا تعرض أي أرقام.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.phaseKey});
  final String phaseKey;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(context.t('coming_soon'), style: Theme.of(context).textTheme.titleMedium),
            Text(context.t(phaseKey)),
          ],
        ),
      );
}
