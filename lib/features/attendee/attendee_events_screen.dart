import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/category_chip.dart';
import '../../shared/widgets/error_message.dart';
import '../../shared/widgets/event_card.dart';
import 'event_details_screen.dart';

class AttendeeEventsScreen extends StatefulWidget {
  final EventCategory? initialCategory;
  const AttendeeEventsScreen({super.key, this.initialCategory});

  @override
  State<AttendeeEventsScreen> createState() => _AttendeeEventsScreenState();
}

class _AttendeeEventsScreenState extends State<AttendeeEventsScreen> {
  final _searchController = TextEditingController();
  EventCategory? _selectedCategory;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<EventCategory?, String>> _categoryEntries(
          AppLocalizations l10n) =>
      [
        MapEntry(null, l10n.categoryAll),
        MapEntry(EventCategory.music, l10n.categoryMusic),
        MapEntry(EventCategory.sport, l10n.categorySport),
        MapEntry(EventCategory.business, l10n.categoryBusiness),
        MapEntry(EventCategory.art, l10n.categoryArt),
        MapEntry(EventCategory.food, l10n.categoryFood),
        MapEntry(EventCategory.tech, l10n.categoryTech),
        MapEntry(EventCategory.student, l10n.categoryStudent),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final data = context.watch<DataService>();
    final events = data.events.where((e) {
      final matchesCategory =
          _selectedCategory == null || e.category == _selectedCategory;
      final matchesQuery = _query.isEmpty ||
          [
            e.title,
            e.venue,
            e.address,
            e.city
          ].any((v) => v.toLowerCase().contains(_query.trim().toLowerCase()));
      return matchesCategory &&
          matchesQuery &&
          e.eventStatus == 'published' &&
          e.visibility == 'public';
    }).toList();

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navEvents)),
      body: RefreshIndicator(
          onRefresh: data.refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.discoverTitle,
                                style:
                                    Theme.of(context).textTheme.headlineMedium),
                            const SizedBox(height: 8),
                            Text(l10n.discoverSubtitle),
                            if (data.isLoading) const LinearProgressIndicator(),
                            if (data.errorMessage != null)
                              TextButton(
                                  onPressed: data.refresh,
                                  child: Text(
                                      '${data.errorMessage} · ${l10n.commonRetry}')),
                          ]))),
              SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                        hintText: l10n.homeSearchHint,
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.textTertiary),
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.input)))),
              )),
              SliverToBoxAdapter(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final entry in _categoryEntries(l10n))
                    CategoryChip(
                        label: entry.value,
                        selected: _selectedCategory == entry.key,
                        onTap: () =>
                            setState(() => _selectedCategory = entry.key)),
                ]),
              )),
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Row(children: [
                        Expanded(
                            child:
                                Text('${l10n.resultsLabel}: ${events.length}')),
                        if (_query.isNotEmpty || _selectedCategory != null)
                          TextButton(
                              onPressed: () => setState(() {
                                    _query = '';
                                    _selectedCategory = null;
                                    _searchController.clear();
                                  }),
                              child: Text(l10n.clearFilters)),
                      ]))),
              if (events.isEmpty && !data.isLoading)
                SliverToBoxAdapter(
                    child: AppErrorMessage(
                        message: l10n.homeNoEvents,
                        icon: Icons.event_busy_rounded))
              else
                SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    sliver: SliverList.list(children: [
                      for (final event in events)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: EventCard(
                                event: event,
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => EventDetailsScreen(
                                            event: event))))),
                    ])),
            ],
          )),
    );
  }
}
