import 'package:flutter/material.dart';

/// Cards keep their natural height and use fewer columns on small screens or
/// when accessibility text is enlarged.
class ResponsiveCards extends StatelessWidget {
  const ResponsiveCards(
      {super.key, required this.children, this.minimumWidth = 160});
  final List<Widget> children;
  final double minimumWidth;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final columns =
            (constraints.maxWidth / (minimumWidth * scale.clamp(1.0, 3.0)))
                .floor()
                .clamp(1, 4);
        final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          for (final child in children) SizedBox(width: width, child: child),
        ]);
      });
}
