import 'package:flutter/material.dart';
import '../../app/theme.dart';

Color supportStatusColor(String status) => switch (status) {
      'open' => AppColors.primary,
      'in_progress' => AppColors.supportBlue,
      'waiting_for_customer' => AppColors.supportAmber,
      'resolved' => AppColors.success,
      _ => AppColors.textSecondary,
    };

class SupportInboxHeader extends StatelessWidget {
  const SupportInboxHeader(
      {super.key,
      required this.title,
      required this.total,
      required this.counts});
  final String title, total;
  final List<({String label, int count, String status})> counts;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.primaryInk, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.forum_outlined,
                  color: Colors.white, size: 28)),
          const SizedBox(width: 14),
          Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 18),
        Text(total,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        LayoutBuilder(
            builder: (context, box) =>
                Wrap(spacing: 10, runSpacing: 10, children: [
                  for (final item in counts)
                    Container(
                        width: (box.maxWidth - 10) / 2,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  width: 4,
                                  height: 32,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                      color: supportStatusColor(item.status),
                                      borderRadius: BorderRadius.circular(4))),
                              Expanded(
                                  child: Text('${item.count} ${item.label}',
                                      style: TextStyle(
                                          color:
                                              supportStatusColor(item.status),
                                          fontWeight: FontWeight.w700))),
                            ])),
                ])),
      ]));
}

class SupportCaseCard extends StatelessWidget {
  const SupportCaseCard(
      {super.key,
      required this.row,
      required this.status,
      required this.category,
      required this.assignee,
      required this.onTap,
      this.compact = false});
  final Map<String, dynamic> row;
  final String status, category, assignee;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = supportStatusColor(row['status'] as String);
    return Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: color.withValues(alpha: .22))),
        child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
                child: Row(children: [
              if (!compact) Container(width: 5, color: color),
              Expanded(
                  child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                          color: color.withValues(alpha: .1),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Text(status,
                                          style: TextStyle(
                                              color: color,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700))),
                                  if (!compact)
                                    Text(category,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium),
                                ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: Text(row['subject'] as String,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700))),
                              const SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded,
                                  color: color, size: 20)
                            ]),
                            if ('${row['event_title'] ?? ''}'.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(row['event_title'] as String,
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                            if (!compact) const SizedBox(height: 12),
                            if (!compact)
                              Row(children: [
                                const Icon(Icons.person_outline,
                                    size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(assignee,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall))
                              ]),
                          ]))),
            ]))));
  }
}
