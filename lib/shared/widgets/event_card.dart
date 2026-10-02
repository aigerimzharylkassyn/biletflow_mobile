import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../models/event.dart';

/// The "Event Card" component from the Figma design system.
/// Since real event photography isn't available for this prototype,
/// a colored tile with a category icon stands in for the event image
/// (see BiletFlow spec section 16 - "use placeholders if an asset is
/// unavailable").
class EventCard extends StatelessWidget {
  final AppEvent event;
  final VoidCallback? onTap;

  /// Optional widget shown in the top-right corner, e.g. a "312/500 sold"
  /// badge on the organizer's My Events screen.
  final Widget? trailingBadge;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, d MMM yyyy').format(event.date);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x1F1D1D1D),
                  blurRadius: 4,
                  offset: Offset(0, 0)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 84,
                height: 96,
                decoration: BoxDecoration(
                  color: event.accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(event.icon, color: event.accentColor, size: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateLabel,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                    if (trailingBadge != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: trailingBadge!),
                    const SizedBox(height: 2),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.access_time_rounded,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text(
                          '${event.startTime} - ${event.endTime}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        )),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${event.venue}, ${event.city}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
