import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/staff_event_filter.dart';

class StaffEventStatusBadge extends StatelessWidget {
  const StaffEventStatusBadge({super.key, required this.group});
  final StaffEventFilter group;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, icon, color) = switch (group) {
      StaffEventFilter.upcoming => (
          l.organizerEventsUpcoming,
          Icons.event_outlined,
          AppColors.primaryInk
        ),
      StaffEventFilter.live => (
          l.staffEventsLive,
          Icons.sensors_rounded,
          AppColors.success
        ),
      StaffEventFilter.past => (
          l.organizerEventsPast,
          Icons.history_rounded,
          AppColors.textSecondary
        ),
      StaffEventFilter.cancelled => (
          l.eventStatusCancelled,
          Icons.event_busy_outlined,
          AppColors.error
        ),
      StaffEventFilter.all => (
          l.organizerEventsAll,
          Icons.event_note_outlined,
          AppColors.textSecondary
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          border: Border.all(color: color.withValues(alpha: .18)),
          borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
            child: Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w500))),
      ]),
    );
  }
}
