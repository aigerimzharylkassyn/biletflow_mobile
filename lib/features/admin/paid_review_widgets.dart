import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app/theme.dart';

Color paidReviewColor(String status) => switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      'pending_review' => AppColors.supportAmber,
      _ => AppColors.primaryInk,
    };
IconData paidReviewIcon(String status) => switch (status) {
      'approved' => Icons.check_circle_outline_rounded,
      'rejected' => Icons.cancel_outlined,
      'pending_review' => Icons.schedule_rounded,
      _ => Icons.edit_note_rounded,
    };
String paidReviewDate(BuildContext context, dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '—';
  return '${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).add_Hm().format(date)} (${date.timeZoneName})';
}

class PaidReviewBadge extends StatelessWidget {
  const PaidReviewBadge({super.key, required this.status, required this.label});
  final String status, label;
  @override
  Widget build(BuildContext context) {
    final color = paidReviewColor(status);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(paidReviewIcon(status), size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label,
                  style: TextStyle(
                      color: color, fontSize: 12, fontWeight: FontWeight.w700)))
        ]));
  }
}

class PaidReviewSection extends StatelessWidget {
  const PaidReviewSection(
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
          color: highlight ? AppColors.primarySoft : Colors.white,
          border: Border.all(
              color: highlight
                  ? AppColors.primary.withValues(alpha: .2)
                  : AppColors.divider),
          borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: highlight ? Colors.white : AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: AppColors.primaryInk, size: 20)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)))
        ]),
        const SizedBox(height: 16),
        ...children,
      ]));
}

class PaidReviewInfo extends StatelessWidget {
  const PaidReviewInfo(
      {super.key,
      required this.icon,
      required this.label,
      required this.value});
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 3),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
        ])),
      ]));
}

class PaidReviewCheck extends StatelessWidget {
  const PaidReviewCheck(
      {super.key, required this.label, required this.complete});
  final String label;
  final bool complete;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(complete ? Icons.check_circle_rounded : Icons.pending_outlined,
            size: 21,
            color: complete ? AppColors.success : AppColors.supportAmber),
        const SizedBox(width: 12),
        Expanded(child: Text(label))
      ]));
}
