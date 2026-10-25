import 'package:flutter/material.dart';
import '../../l10n/loc_extensions.dart';

class EventStatusBadge extends StatelessWidget {
  const EventStatusBadge({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, color) = switch (status) {
      'draft' => (l.eventStatusDraft, const Color(0xFF865500)),
      'published' => (l.eventStatusPublished, const Color(0xFF237642)),
      'completed' => (l.eventStatusCompleted, const Color(0xFF425D9B)),
      'cancelled' => (l.eventStatusCancelled, const Color(0xFFB52C2C)),
      _ => (status.replaceAll('_', ' '), Colors.blueGrey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(16)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
