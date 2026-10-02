import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/data_service.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  String _categoryLabel(AppLocalizations l10n, EventCategory category) =>
      switch (category) {
        EventCategory.music => l10n.categoryMusic,
        EventCategory.sport => l10n.categorySport,
        EventCategory.business => l10n.categoryBusiness,
        EventCategory.art => l10n.categoryArt,
        EventCategory.food => l10n.categoryFood,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final events = context.watch<DataService>().events;

    final soldByCategory = <EventCategory, int>{};
    for (final event in events) {
      soldByCategory[event.category] =
          (soldByCategory[event.category] ?? 0) + event.ticketsSold;
    }
    final maxSold = soldByCategory.values.isEmpty
        ? 1
        : soldByCategory.values.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminReports)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            l10n.adminTicketsSold,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          for (final entry in soldByCategory.entries) ...[
            Row(children: [
              Expanded(
                  child: Text(_categoryLabel(l10n, entry.key),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary))),
              const SizedBox(width: 12),
              Flexible(
                  child: Text(entry.value.toString(),
                      style: const TextStyle(fontSize: 13))),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: maxSold == 0 ? 0 : entry.value / maxSold,
                    minHeight: 18,
                    backgroundColor: AppColors.divider,
                    color: AppColors.primary)),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}
