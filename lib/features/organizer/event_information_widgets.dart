import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Shared visual structure for the organizer's editor, preview and overview.
class EventInfoSection extends StatelessWidget {
  const EventInfoSection(
      {super.key,
      required this.title,
      required this.icon,
      required this.children,
      this.highlight = false});
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: highlight ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: highlight
                  ? AppColors.primary.withValues(alpha: .18)
                  : AppColors.divider),
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: AppColors.primaryInk, size: 22),
            const SizedBox(width: 10),
            Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 20),
          ...children,
        ]),
      );
}

class EventInfoRow extends StatelessWidget {
  const EventInfoRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 18, color: AppColors.primaryInk)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(value,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ])),
        ]),
      );
}

class EventCover extends StatelessWidget {
  const EventCover({super.key, required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Image.network(url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const ColoredBox(
                      color: AppColors.primarySoft,
                      child: Center(
                          child: Icon(Icons.image_outlined,
                              size: 40, color: AppColors.primaryInk)))))));
}
