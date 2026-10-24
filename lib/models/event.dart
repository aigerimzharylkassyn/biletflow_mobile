import 'package:flutter/material.dart';

enum EventCategory { music, sport, business, art, food, tech, student }

class AppEvent {
  final String id;
  final String address;
  final String refundPolicy;
  final String timeZone;
  final String eventStatus;
  final String paidSalesStatus;
  final DateTime? endsAt;
  final DateTime? registrationOpensAt;
  final DateTime? registrationClosesAt;
  final String? imageUrl;
  final String visibility;
  final String title;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String venue;
  final String city;
  final String description;
  final String organizerName;
  final double price;
  final EventCategory category;
  final Color accentColor;
  final IconData icon;
  final bool featured;

  /// Total tickets available and how many have been sold so far.
  /// Used on the organizer dashboard / event overview screens.
  final int ticketsTotal;
  final int ticketsSold;

  const AppEvent({
    required this.id,
    this.address = '',
    this.refundPolicy = '',
    this.timeZone = 'Asia/Almaty',
    this.eventStatus = 'published',
    this.paidSalesStatus = 'active',
    this.endsAt,
    this.registrationOpensAt,
    this.registrationClosesAt,
    this.imageUrl,
    this.visibility = 'public',
    required this.title,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.venue,
    required this.city,
    required this.description,
    required this.organizerName,
    required this.price,
    required this.category,
    required this.accentColor,
    required this.icon,
    this.featured = false,
    this.ticketsTotal = 100,
    this.ticketsSold = 0,
  });

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    final start = DateTime.parse(
            '${json['starts_at']}${RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(json['starts_at']) ? '' : 'Z'}')
        .toLocal();
    final end = DateTime.parse(
            '${json['ends_at']}${RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(json['ends_at']) ? '' : 'Z'}')
        .toLocal();
    final types = (json['available_ticket_types'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((t) => t['is_hidden'] != true)
        .toList();
    final category = EventCategory.values
            .where((e) =>
                e.name ==
                switch (json['category']) {
                  'concert' || 'concerts' => 'music',
                  'sports' => 'sport',
                  'technology' || 'conference' => 'tech',
                  'students' || 'education' => 'student',
                  _ => json['category']
                })
            .firstOrNull ??
        EventCategory.business;
    final venue = json['venue'] as Map<String, dynamic>? ?? {};
    String time(DateTime date) =>
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final images = json['images'] as List? ?? [];
    return AppEvent(
        address: venue['address'] ?? '',
        refundPolicy: json['refund_policy'] ?? '',
        timeZone: json['time_zone'] ?? 'Asia/Almaty',
        eventStatus: json['status'] ?? 'published',
        paidSalesStatus: json['paid_sales_status'] ?? 'not_ready',
        endsAt: end,
        registrationOpensAt: json['registration_opens_at'] == null
            ? null
            : parseApiDate(json['registration_opens_at']),
        registrationClosesAt: json['registration_closes_at'] == null
            ? null
            : parseApiDate(json['registration_closes_at']),
        visibility: json['visibility'] ?? 'public',
        imageUrl: images.isEmpty
            ? null
            : (images.first is String ? images.first : images.first['url']),
        id: json['id'],
        title: json['title'],
        date: start,
        startTime: time(start),
        endTime: time(end),
        venue: venue['name'] ?? '',
        city: venue['city'] ?? '',
        description: json['description'],
        organizerName: json['organizer_name'] ?? 'Organizer',
        price: types.isEmpty
            ? 0
            : types
                    .map((t) => (t['price_minor'] as num).toDouble())
                    .reduce((a, b) => a < b ? a : b) /
                100,
        category: category,
        accentColor: const Color(0xFF3E6AE1),
        icon: switch (category) {
          EventCategory.music => Icons.music_note_rounded,
          EventCategory.sport => Icons.directions_run_rounded,
          EventCategory.art => Icons.palette_rounded,
          EventCategory.food => Icons.ramen_dining_rounded,
          _ => Icons.event_rounded
        },
        ticketsTotal:
            types.fold<int>(0, (sum, t) => sum + (t['quantity'] as int)),
        ticketsSold:
            types.fold<int>(0, (sum, t) => sum + (t['sold_count'] as int)),
        featured: json['status'] == 'published');
  }

  bool get isFree => price == 0;
}

DateTime parseApiDate(String value) => DateTime.parse(
    RegExp(r'(Z|[+-]\d\d:\d\d)$').hasMatch(value) ? value : '${value}Z');
