import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/auth_service.dart';
import '../../models/event.dart';
import '../attendee/attendee_ui.dart';
import '../../shared/widgets/responsive_cards.dart';
import 'paid_review_widgets.dart';

String paidReviewLabel(BuildContext context, String status) => switch (status) {
      'pending_review' => context.l10n.paidReviewPending,
      'approved' => context.l10n.paidReviewApproved,
      'rejected' => context.l10n.paidReviewRejected,
      'changes_required' => context.l10n.paidReviewChanges,
      _ => status,
    };

class PaidEventApplicationsScreen extends StatefulWidget {
  const PaidEventApplicationsScreen({super.key});
  @override
  State<PaidEventApplicationsScreen> createState() =>
      _PaidEventApplicationsScreenState();
}

class _PaidEventApplicationsScreenState
    extends State<PaidEventApplicationsScreen> {
  List<Map<String, dynamic>> _rows = [];
  String _filter = 'pending_review', _query = '';
  String? _error;
  bool _loading = true;
  bool _visible = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
    _visible = visible;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<AuthService>()
          .api
          .request('GET', '/admin/paid-event-applications') as List;
      if (mounted) {
        setState(() =>
            _rows = result.map((r) => Map<String, dynamic>.from(r)).toList());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final rows = _rows
        .where((r) =>
            (_filter.isEmpty || r['status'] == _filter) &&
            '${r['event']['title']} ${r['event']['organizer_name']}'
                .toLowerCase()
                .contains(_query))
        .toList();
    return Scaffold(
        backgroundColor: AppColors.caseBackground,
        appBar: AppBar(title: Text(l.paidEventApplications), actions: [
          IconButton(
              tooltip: l.refreshStatus,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      _ApplicationSummary(rows: _rows),
                      const SizedBox(height: 20),
                      TextField(
                          key: const ValueKey('paid-application-search'),
                          decoration: InputDecoration(
                              labelText: l.adminSearchEvents,
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: Colors.white),
                          onChanged: (v) =>
                              setState(() => _query = v.trim().toLowerCase())),
                      const SizedBox(height: 16),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final status in [
                          'pending_review',
                          'approved',
                          'rejected',
                          'changes_required',
                          ''
                        ])
                          ChoiceChip(
                              label: Text(
                                  '${status.isEmpty ? l.organizerEventsAll : paidReviewLabel(context, status)} (${_rows.where((r) => status.isEmpty || r['status'] == status).length})'),
                              selected: _filter == status,
                              onSelected: (_) =>
                                  setState(() => _filter = status))
                      ]),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Text(_error!,
                            style: const TextStyle(color: AppColors.error)),
                        TextButton(onPressed: _load, child: Text(l.commonRetry))
                      ],
                      if (rows.isEmpty && _error == null)
                        PaidReviewSection(
                            title: l.paidReviewEmpty,
                            icon: Icons.inbox_outlined,
                            children: [Text(l.paidReviewQueueHelp)]),
                      for (final row in rows)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _ApplicationCard(
                                application: row,
                                onTap: () async {
                                  await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => PaidEventReviewScreen(
                                              application: row)));
                                  if (mounted) await _load();
                                })),
                    ])));
  }
}

class PaidEventReviewScreen extends StatefulWidget {
  const PaidEventReviewScreen({super.key, required this.application});
  final Map<String, dynamic> application;
  @override
  State<PaidEventReviewScreen> createState() => _PaidEventReviewScreenState();
}

class _PaidEventReviewScreenState extends State<PaidEventReviewScreen> {
  bool _busy = false;
  String? _error;
  Future<void> _decide(bool approve) async {
    if (_busy) return;
    final l = context.l10n;
    var reason = "";
    final form = GlobalKey<FormState>();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                scrollable: true,
                title: Text(approve ? l.paidReviewApprove : l.paidReviewReject),
                content: approve
                    ? Text(l.paidReviewApproveHelp)
                    : Form(
                        key: form,
                        child: TextFormField(
                            onChanged: (v) => reason = v,
                            maxLength: 2000,
                            minLines: 3,
                            maxLines: 6,
                            decoration:
                                InputDecoration(labelText: l.paidReviewReason),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? l.paidReviewReasonRequired
                                : null)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(l.commonCancel)),
                  FilledButton(
                      onPressed: () {
                        if (approve || form.currentState!.validate()) {
                          Navigator.pop(c, true);
                        }
                      },
                      child: Text(
                          approve ? l.paidReviewApprove : l.paidReviewReject))
                ]));
    final text = reason.trim();
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = widget.application['event']['id'];
      await context.read<AuthService>().api.request('POST',
          '/admin/paid-event-applications/$id/${approve ? 'approve' : 'reject'}',
          body: {'reason': text});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final a = widget.application, e = a['event'] as Map;
    final p = a['profile'] as Map?;
    final types = e['available_ticket_types'] as List? ?? [];
    final canReview = a['status'] == 'pending_review' && e['status'] == 'draft';
    return Scaffold(
        backgroundColor: AppColors.caseBackground,
        appBar: AppBar(title: Text(l.paidReviewDetails)),
        bottomNavigationBar: canReview
            ? Material(
                color: Colors.white,
                elevation: 8,
                child: SafeArea(
                    top: false,
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_error != null)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(_error!,
                                        style: const TextStyle(
                                            color: AppColors.error))),
                              ResponsiveCards(minimumWidth: 220, children: [
                                OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(
                                            color: AppColors.error)),
                                    onPressed:
                                        _busy ? null : () => _decide(false),
                                    icon: const Icon(Icons.close_rounded),
                                    label: Text(l.paidReviewReject)),
                                FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                        backgroundColor: AppColors.primaryInk,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 16)),
                                    onPressed:
                                        _busy ? null : () => _decide(true),
                                    icon: _busy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white))
                                        : const Icon(
                                            Icons.check_circle_outline_rounded),
                                    label: Text(_busy
                                        ? l.commonLoading
                                        : l.paidReviewApprove)),
                              ]),
                            ]))))
            : null,
        body: ListView(padding: const EdgeInsets.all(20), children: [
          PaidReviewSection(
              title: l.paidReviewDetails,
              icon: Icons.event_note_rounded,
              highlight: true,
              children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: PaidReviewBadge(
                        status: a['status'],
                        label: paidReviewLabel(context, a['status']))),
                const SizedBox(height: 14),
                Text(e['title'],
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text('${l.eventOrganizer}: ${e['organizer_name']}',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 14),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  Text('${l.creationCapacity}: ${e['capacity']}',
                      style: const TextStyle(
                          color: AppColors.primaryInk,
                          fontWeight: FontWeight.w600)),
                  Text('${l.paidReviewTicketTypes}: ${types.length}',
                      style: const TextStyle(
                          color: AppColors.primaryInk,
                          fontWeight: FontWeight.w600)),
                ]),
              ]),
          if (a['submitted_at'] != null ||
              a['reviewed_at'] != null ||
              '${a['reason'] ?? ''}'.isNotEmpty)
            PaidReviewSection(
                title: l.paidReviewDecision,
                icon: Icons.rate_review_outlined,
                children: [
                  if (a['submitted_at'] != null)
                    PaidReviewInfo(
                        icon: Icons.send_outlined,
                        label: l.paidReviewSubmitted,
                        value: paidReviewDate(context, a['submitted_at'])),
                  if (a['reviewed_at'] != null)
                    PaidReviewInfo(
                        icon: Icons.task_alt_outlined,
                        label: l.paidReviewReviewed,
                        value: paidReviewDate(context, a['reviewed_at'])),
                  if ('${a['reason'] ?? ''}'.isNotEmpty) Text(a['reason']),
                ]),
          PaidReviewSection(
              title: l.paidReviewScheduleVenue,
              icon: Icons.place_outlined,
              children: [
                PaidReviewInfo(
                    icon: Icons.calendar_today_outlined,
                    label: l.paidReviewStarts,
                    value: paidReviewDate(context, e['starts_at'])),
                PaidReviewInfo(
                    icon: Icons.schedule_rounded,
                    label: l.paidReviewEnds,
                    value: paidReviewDate(context, e['ends_at'])),
                PaidReviewInfo(
                    icon: Icons.location_on_outlined,
                    label: l.paidReviewVenue,
                    value:
                        '${e['venue']['name']}\n${e['venue']['address']} · ${e['venue']['city']}'),
              ]),
          PaidReviewSection(
              title: l.paidReviewEventInformation,
              icon: Icons.subject_rounded,
              children: [
                Text(parseEventCategory('${e['category']}').localizedLabel(l),
                    style: const TextStyle(
                        color: AppColors.primaryInk,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(e['description'], style: const TextStyle(height: 1.6)),
                const Divider(height: 28),
                Text(l.refundPolicy,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(e['refund_policy'], style: const TextStyle(height: 1.5)),
              ]),
          PaidReviewSection(
              title: l.paidReviewOrganizer,
              icon: Icons.badge_outlined,
              children: [
                if (p != null) ...[
                  PaidReviewInfo(
                      icon: Icons.person_outline,
                      label: l.applicationContact,
                      value: '${p['contact_name']}'),
                  if ('${p['organization_name'] ?? ''}'.isNotEmpty)
                    PaidReviewInfo(
                        icon: Icons.business_outlined,
                        label: l.paidOrganization,
                        value: p['organization_name']),
                  if ('${p['contact_phone'] ?? ''}'.isNotEmpty)
                    PaidReviewInfo(
                        icon: Icons.phone_outlined,
                        label: l.paidPhone,
                        value: p['contact_phone']),
                  PaidReviewInfo(
                      icon: Icons.account_balance_outlined,
                      label: l.paidPayoutReady,
                      value:
                          '${p['payout_account_masked'] ?? l.statusPending}'),
                ] else
                  Text(l.statusPending),
              ]),
          PaidReviewSection(
              title: l.paidChecklist,
              icon: Icons.verified_user_outlined,
              children: [
                PaidReviewCheck(
                    label: l.paidFeeReady,
                    complete: a['activation_fee_paid'] == true),
                PaidReviewCheck(
                    label: l.paidTermsReady,
                    complete: a['terms_accepted'] == true),
                PaidReviewCheck(
                    label: l.paidIdentityReady,
                    complete: p?['verification_status'] == 'verified'),
                PaidReviewCheck(
                    label: l.paidPayoutReady,
                    complete: p?['payout_verified'] == true),
                const SizedBox(height: 12),
                Text(l.paidSandboxHelp,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ]),
          PaidReviewSection(
              title: l.paidReviewTicketTypes,
              icon: Icons.confirmation_number_outlined,
              children: [
                for (final t in types)
                  Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: AppColors.caseBackground,
                          borderRadius: BorderRadius.circular(14)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(t['name'],
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Text(money(t['price_minor'] as num),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        color: AppColors.primaryInk,
                                        fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text('${l.creationCapacity}: ${t['quantity']}'),
                            const Divider(height: 24),
                            Text(l.paidReviewSalesWindow,
                                style: Theme.of(context).textTheme.labelMedium),
                            const SizedBox(height: 6),
                            Text(
                                '${paidReviewDate(context, t['sales_start'])} – ${paidReviewDate(context, t['sales_end'])}'),
                          ])),
              ]),
          if (canReview)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(l.paidReviewApproveHelp,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary))),
        ]));
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onTap});
  final Map<String, dynamic> application;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n, a = application, e = a['event'] as Map;
    return Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.divider)),
        child: InkWell(
            onTap: onTap,
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PaidReviewBadge(
                          status: a['status'],
                          label: paidReviewLabel(context, a['status'])),
                      const SizedBox(height: 14),
                      Text(e['title'],
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(e['organizer_name'] as String? ?? '',
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 14),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.calendar_today_outlined,
                                size: 16, color: AppColors.primaryInk),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    paidReviewDate(context, e['starts_at']),
                                    style:
                                        Theme.of(context).textTheme.bodySmall))
                          ]),
                      const SizedBox(height: 8),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 17, color: AppColors.primaryInk),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    '${e['venue']['name']} · ${e['venue']['city']}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall))
                          ]),
                      const Divider(height: 28),
                      Row(children: [
                        Expanded(
                            child: Text(l.paidReviewOpenApplication,
                                style: const TextStyle(
                                    color: AppColors.primaryInk,
                                    fontWeight: FontWeight.w600))),
                        const Icon(Icons.arrow_forward_rounded,
                            color: AppColors.primaryInk, size: 20)
                      ]),
                    ]))));
  }
}

class _ApplicationSummary extends StatelessWidget {
  const _ApplicationSummary({required this.rows});
  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final statuses = [
      ('pending_review', l.paidReviewSummaryPending),
      ('approved', l.paidReviewApproved),
      ('rejected', l.paidReviewRejected),
      ('changes_required', l.paidReviewChanges),
    ];
    Widget metric((String, String) status) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: .16)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${rows.where((r) => r['status'] == status.$1).length}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(status.$2,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4)),
          ]),
        );
    return Container(
      key: const ValueKey('paid-applications-summary'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.primaryInk, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(22)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.fact_check_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
              child: Text(l.paidReviewTotalApplications,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500))),
        ]),
        const SizedBox(height: 8),
        Text('${rows.length}',
            key: const ValueKey('paid-applications-total'),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        for (var i = 0; i < statuses.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          IntrinsicHeight(
              child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: metric(statuses[i])),
              const SizedBox(width: 10),
              Expanded(child: metric(statuses[i + 1])),
            ],
          )),
        ],
      ]),
    );
  }
}
