import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// A shared surface for case information, actions and the reply composer.
class SupportCasePanel extends StatelessWidget {
  const SupportCasePanel(
      {super.key, required this.child, this.highlight = false});
  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: highlight ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: highlight
                  ? AppColors.primary.withValues(alpha: .25)
                  : AppColors.divider),
        ),
        child: child,
      );
}

class SupportCaseHeading extends StatelessWidget {
  const SupportCaseHeading(
      {super.key,
      required this.flow,
      required this.number,
      required this.status,
      required this.category,
      required this.assignee,
      this.compact = false});
  final String flow, number, status, category, assignee;
  final bool compact;

  @override
  Widget build(BuildContext context) => SupportCasePanel(
      highlight: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!compact)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.support_agent_rounded,
                    color: Colors.white, size: 26)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(flow,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primaryInk,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SelectableText(number,
                      style: Theme.of(context).textTheme.bodySmall),
                ])),
          ]),
        if (!compact) const SizedBox(height: 18),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Semantics(
              liveRegion: true,
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                      color: AppColors.primaryInk,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(status,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)))),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Text(category,
                  style: const TextStyle(
                      color: AppColors.primaryInk,
                      fontWeight: FontWeight.w600,
                      fontSize: 12))),
        ]),
        if (!compact) const SizedBox(height: 16),
        if (!compact)
          Row(children: [
            const Icon(Icons.person_outline_rounded,
                size: 18, color: AppColors.primaryInk),
            const SizedBox(width: 8),
            Expanded(
                child: Text(assignee,
                    style: Theme.of(context).textTheme.bodySmall))
          ]),
      ]));
}

class SupportMessageBubble extends StatelessWidget {
  const SupportMessageBubble(
      {super.key,
      required this.own,
      required this.sender,
      required this.timestamp,
      required this.body});
  final bool own;
  final String sender, timestamp, body;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Align(
          alignment: own ? Alignment.centerRight : Alignment.centerLeft,
          child: FractionallySizedBox(
              widthFactor: .92,
              child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: own ? AppColors.primarySoft : Colors.white,
                      border: Border.all(
                          color: own
                              ? AppColors.primary.withValues(alpha: .22)
                              : AppColors.divider),
                      borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(own ? 18 : 4),
                          bottomRight: Radius.circular(own ? 4 : 18))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sender,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                    color: own
                                        ? AppColors.primaryInk
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        SelectableText(body,
                            style: const TextStyle(
                                color: AppColors.textPrimary, height: 1.5)),
                        if (timestamp.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(timestamp,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: AppColors.textSecondary)),
                        ],
                      ])))));
}

class SupportCaseDetails extends StatelessWidget {
  const SupportCaseDetails(
      {super.key,
      required this.simple,
      required this.title,
      required this.child});
  final bool simple;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => simple
      ? Material(
          color: Colors.transparent,
          child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(title),
              children: [child]))
      : child;
}
