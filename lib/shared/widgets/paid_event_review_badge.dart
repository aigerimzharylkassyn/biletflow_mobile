import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';

class PaidEventReviewBadge extends StatelessWidget {
  const PaidEventReviewBadge({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (label, color, icon) = switch (status) {
      'approved' => (
          l.paidReviewReadyToPublish,
          AppColors.success,
          Icons.check_circle_outline
        ),
      'pending_review' => (
          l.paidReviewPending,
          AppColors.supportAmber,
          Icons.schedule
        ),
      'rejected' => (
          l.paidReviewRejected,
          AppColors.error,
          Icons.error_outline
        ),
      'changes_required' => (
          l.paidReviewChanges,
          AppColors.primaryInk,
          Icons.edit_note
        ),
      _ => (
          l.paidReviewNotSubmitted,
          AppColors.textSecondary,
          Icons.drafts_outlined
        ),
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w600)))
        ]));
  }
}
