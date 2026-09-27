import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/app_avatar.dart';
import '../../shared/widgets/category_chip.dart';
import '../../shared/widgets/event_card.dart';
import '../profile/profile_screen.dart';
import 'attendee_events_screen.dart';
import 'event_details_screen.dart';
import 'my_tickets_screen.dart';

class AttendeeHomeScreen extends StatelessWidget {
  const AttendeeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.watch<AuthService>().currentUser;
    final data = context.watch<DataService>();
    final featured = data.featuredEvents;
    final upcoming = data.events.where((e) => !e.featured).take(4).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.homeHello(user?.name.split(' ').first ?? '')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
              child: AppAvatar(initials: user?.initials ?? '?', size: 34),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          _SearchBar(onTap: () => _openEvents(context)),
          const SizedBox(height: 24),
          _SectionHeader(title: l10n.homeCategories),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final entry in _categoryEntries(l10n))
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: CategoryChip(
                      label: entry.value,
                      selected: false,
                      onTap: () => _openEvents(context, category: entry.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: l10n.homeFeaturedEvents,
            onSeeAll: () => _openEvents(context),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 122,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: featured.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final event = featured[index];
                return SizedBox(
                  width: 300,
                  child: EventCard(event: event, onTap: () => _openDetails(context, event)),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: l10n.homeUpcomingEvents,
            onSeeAll: () => _openEvents(context),
          ),
          const SizedBox(height: 12),
          for (final event in upcoming) ...[
            EventCard(event: event, onTap: () => _openDetails(context, event)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyTicketsScreen()),
            ),
            icon: const Icon(Icons.confirmation_number_outlined, size: 18),
            label: Text(l10n.navMyTickets),
          ),
        ],
      ),
    );
  }

  List<MapEntry<EventCategory?, String>> _categoryEntries(AppLocalizations l10n) => [
        MapEntry(null, l10n.categoryAll),
        MapEntry(EventCategory.music, l10n.categoryMusic),
        MapEntry(EventCategory.sport, l10n.categorySport),
        MapEntry(EventCategory.business, l10n.categoryBusiness),
        MapEntry(EventCategory.art, l10n.categoryArt),
        MapEntry(EventCategory.food, l10n.categoryFood),
      ];

  void _openEvents(BuildContext context, {EventCategory? category}) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AttendeeEventsScreen(initialCategory: category)),
    );
  }

  void _openDetails(BuildContext context, AppEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event)),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.input),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, color: AppColors.textTertiary, size: 20),
            const SizedBox(width: 10),
            Text(context.l10n.homeSearchHint, style: const TextStyle(color: AppColors.inputHint, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        if (onSeeAll != null)
          TextButton(onPressed: onSeeAll, child: Text(context.l10n.commonSeeAll)),
      ],
    );
  }
}
