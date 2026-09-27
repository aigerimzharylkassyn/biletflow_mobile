import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/event.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/primary_button.dart';

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({super.key});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _venueController = TextEditingController();
  final _cityController = TextEditingController(text: "Almaty");
  final _addressController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  EventCategory _category = EventCategory.music;
  DateTime _date = DateTime.now().add(const Duration(days: 7));
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _venueController.dispose();
    _priceController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _categoryLabel(AppLocalizations l10n, EventCategory category) => switch (category) {
        EventCategory.music => l10n.categoryMusic,
        EventCategory.sport => l10n.categorySport,
        EventCategory.business => l10n.categoryBusiness,
        EventCategory.art => l10n.categoryArt,
        EventCategory.food => l10n.categoryFood,
      };

  IconData _categoryIcon(EventCategory category) => switch (category) {
        EventCategory.music => Icons.music_note_rounded,
        EventCategory.sport => Icons.directions_run_rounded,
        EventCategory.business => Icons.rocket_launch_rounded,
        EventCategory.art => Icons.palette_rounded,
        EventCategory.food => Icons.ramen_dining_rounded,
      };

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _publish() async {
    final l10n = context.l10n;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);


    final organizer = context.read<AuthService>().currentUser;
    final event = AppEvent(
      id: 'ev-${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      date: _date,
      startTime: '18:00',
      endTime: '22:00',
      venue: _venueController.text.trim(),
      city: '',
      description: _descriptionController.text.trim(),
      organizerName: organizer?.name ?? '',
      price: double.tryParse(_priceController.text.trim()) ?? 0,
      category: _category,
      accentColor: AppColors.primary,
      icon: _categoryIcon(_category),
      ticketsTotal: 100,
      ticketsSold: 0,
    );
    try {
      await context.read<DataService>().createEvent(event, address: _addressController.text.trim(), city: _cityController.text.trim());
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.organizerPublished)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.organizerCreateEventTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  label: l10n.organizerEventTitleLabel,
                  hint: l10n.organizerEventTitleHint,
                  controller: _titleController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.authValidationNameRequired : null,
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: l10n.organizerVenueLabel,
                  hint: l10n.organizerVenueHint,
                  controller: _venueController,
                  validator: (v) => (v == null || v.trim().isEmpty) ? l10n.authValidationNameRequired : null,
                ),
                const SizedBox(height: 20),
                AppTextField(label: 'City', hint: 'Almaty', controller: _cityController,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter a city' : null),
                const SizedBox(height: 20),
                AppTextField(label: 'Street address', hint: 'Street and building', controller: _addressController,
                  validator: (v) => v == null || v.trim().length < 3 ? 'Enter an address' : null),
                const SizedBox(height: 20),
                const Text('Events run 18:00–22:00 with 100 tickets. Paid sales require organizer verification and activation through the backend.'),
                AppTextField(
                  label: l10n.organizerPriceLabel,
                  hint: '0',
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  validator: (v) => v != null && v.isNotEmpty && (double.tryParse(v) == null || double.parse(v) < 0) ? "Enter a non-negative price" : null,
                ),
                const SizedBox(height: 20),
                Text(l10n.organizerCategoryLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: EventCategory.values.map((category) {
                    final selected = category == _category;
                    return ChoiceChip(
                      label: Text(_categoryLabel(l10n, category)),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = category),
                      showCheckmark: false,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontSize: 13),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                Text(l10n.organizerDateLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadius.input),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.input),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(DateFormat('EEE, d MMM yyyy').format(_date), style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppTextField(
                  label: l10n.eventDescription,
                  hint: l10n.eventDescription,
                  controller: _descriptionController,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 28),
                PrimaryButton(label: l10n.organizerPublish, onPressed: _publish, isLoading: _saving),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
