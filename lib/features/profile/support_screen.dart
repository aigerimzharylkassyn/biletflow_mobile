import 'dart:async';
import '../../app/theme.dart';
import 'support_inbox_widgets.dart';
import 'support_case_widgets.dart';
import 'support_destination_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/data_service.dart';
import '../../services/support_service.dart';
import 'support_staff_dialog.dart';
import 'package:intl/intl.dart';
import '../attendee/attendee_ui.dart';

const supportStatuses = [
  'open',
  'in_progress',
  'waiting_for_customer',
  'resolved'
];
const supportCategories = [
  'report_event',
  'ticket_delivery',
  'payment',
  'refund',
  'seating',
  'event_information',
  'check_in',
  'account',
  'technical'
];
const platformSupportCategories = [
  'account',
  'activation',
  'payment',
  'technical'
];

String supportStatusLabel(BuildContext c, String status) => switch (status) {
      'open' => c.l10n.supportOpen,
      'in_progress' => c.l10n.supportInProgress,
      'waiting_for_customer' => c.l10n.supportWaiting,
      'resolved' => c.l10n.supportSolved,
      _ => status,
    };
String supportCategoryLabel(BuildContext c, String category) =>
    switch (category) {
      'report_event' => c.l10n.opsReportEvent,
      'ticket_delivery' => c.l10n.supportTicket,
      'payment' => c.l10n.supportPayment,
      'refund' => c.l10n.supportRefund,
      'seating' => c.l10n.supportSeating,
      'event_information' => c.l10n.supportEventInformation,
      'check_in' => c.l10n.navCheckin,
      'account' => c.l10n.supportAccount,
      'technical' => c.l10n.supportTechnical,
      'activation' => c.l10n.supportActivation,
      _ => category,
    };

class SupportScreen extends StatefulWidget {
  const SupportScreen(
      {super.key,
      this.caseId,
      this.subject,
      this.eventId,
      this.orderId,
      this.ticketId,
      this.initialCategory,
      this.startNew = false,
      this.flow = 'attendee',
      this.view});
  final String? caseId, subject, eventId, orderId, ticketId, initialCategory;
  final bool startNew;
  final String flow;
  final String? view;
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController(), _message = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic>? _case;
  Timer? _poll;
  late final SupportService _support;
  List<Map<String, dynamic>> _history = [], _assignees = [];
  String _assigneeFilter = '';
  String? _contextEvent, _contextOrder;
  bool _foreground = true;
  int _loadId = 0;
  String get _view =>
      widget.view ??
      ((context.read<AuthService>().currentUser?.role == UserRole.organizer ||
              context.read<AuthService>().currentUser?.role == UserRole.admin ||
              context.read<AuthService>().currentUser?.supportAccess == true)
          ? 'inbox'
          : 'mine');
  List<String> get _categories => widget.flow == 'organizer_platform'
      ? (_view == 'inbox' &&
              context.read<AuthService>().currentUser?.isAdmin == true
          ? {...platformSupportCategories, ...supportCategories}.toList()
          : platformSupportCategories)
      : supportCategories
          .where((category) =>
              category != 'report_event' ||
              (context.read<AuthService>().currentUser?.role ==
                      UserRole.attendee &&
                  (!_creating ||
                      (widget.eventId != null &&
                          widget.orderId == null &&
                          widget.ticketId == null))))
          .toList();
  bool _loading = true, _busy = false, _creating = false;
  String? _error;
  String _category = 'ticket_delivery',
      _query = '',
      _status = '',
      _eventFilter = '',
      _categoryFilter = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _support = SupportService(context.read<AuthService>().api);
    _creating = widget.startNew;
    _contextEvent = widget.eventId;
    _contextOrder = widget.orderId;
    _category = widget.initialCategory ??
        (widget.flow == 'organizer_platform' ? 'account' : 'ticket_delivery');
    _subject.text = widget.caseId == null ? widget.subject ?? '' : '';
    _load();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted &&
          _foreground &&
          TickerMode.valuesOf(context).enabled &&
          !_loading &&
          !_busy &&
          !_creating &&
          _message.text.isEmpty &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        _load(silent: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
  }

  Future<void> _load({bool silent = false}) async {
    final loadId = ++_loadId;
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      if (auth.currentUser?.role == UserRole.staff) {
        await auth.refreshUser();
        if (!mounted) return;
        if (widget.flow == 'attendee' &&
            _view == 'inbox' &&
            auth.currentUser?.supportAccess != true) {
          setState(() {
            _rows = [];
            _case = null;
          });
          return;
        }
      }
      final api = auth.api;
      final result = await api.request(
          'GET',
          widget.caseId == null
              ? '/support/cases?flow=${widget.flow}&view=$_view'
              : '/support/cases/${widget.caseId}/messages') as List;
      if (widget.caseId == null &&
          widget.flow == 'organizer_platform' &&
          _view == 'inbox' &&
          auth.currentUser?.isAdmin == true) {
        final general = await api.request(
            'GET', '/support/cases?flow=attendee&view=inbox') as List;
        result.addAll(general.where((r) => r['routing'] == 'platform'));
        result.sort((a, b) =>
            '${b['updated_at'] ?? ''}'.compareTo('${a['updated_at'] ?? ''}'));
      }
      Map<String, dynamic>? detail;
      var changes = <Map<String, dynamic>>[],
          assignees = <Map<String, dynamic>>[];
      if (widget.caseId != null) {
        detail = Map<String, dynamic>.from(
            await api.request('GET', '/support/cases/${widget.caseId}'));
        changes = (await api.request(
                'GET', '/support/cases/${widget.caseId}/history') as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (detail['can_manage'] == true) {
          assignees = (await api.request(
                  'GET', '/support/cases/${widget.caseId}/assignees') as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
      if (mounted && loadId == _loadId) {
        setState(() {
          _rows = result.map((r) => Map<String, dynamic>.from(r)).toList();
          _case = detail;
          _history = changes;
          _assignees = assignees;
        });
      }
    } catch (e) {
      if (mounted && loadId == _loadId) {
        setState(() {
          _error = e.toString();
          _rows = [];
          _case = null;
        });
      }
    } finally {
      if (mounted && loadId == _loadId) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.caseId != null) {
        await _support.reply(widget.caseId!, _message.text.trim());
      } else {
        final result = await _support.create({
          'flow': widget.flow,
          'subject': _subject.text.trim().isEmpty
              ? supportCategoryLabel(context, _category)
              : _subject.text.trim(),
          'category': _category,
          'message': _message.text.trim(),
          if (_contextEvent != null) 'event_id': _contextEvent,
          if (_contextOrder != null) 'order_id': _contextOrder,
          if (widget.ticketId != null) 'ticket_id': widget.ticketId,
        });
        if (!mounted) return;
        _message.clear();
        _subject.clear();
        setState(() => _creating = false);
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SupportScreen(
                    caseId: result['id'],
                    subject: result['subject'],
                    flow: widget.flow,
                    view: _view)));
      }
      if (!mounted) return;
      _message.clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeStatus(String value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().api.request('PATCH',
          '/support/cases/${widget.caseId}/status?status=${Uri.encodeQueryComponent(value)}');
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve() async {
    if (_busy) return;
    final l = context.l10n;
    final approved = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                scrollable: true,
                title: Text(l.supportApproveRefund),
                content: Text(l.supportRefundApprovalHelp),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: Text(l.commonCancel)),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(l.supportApproveRefund))
                ]));
    if (approved != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context
          .read<AuthService>()
          .api
          .request('POST', '/support/cases/${widget.caseId}/refund');
      if (mounted) {
        await _load();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assign(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().api.request(
          'PATCH', '/support/cases/${widget.caseId}/assignee',
          body: {'user_id': id.isEmpty ? null : id});
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _timestamp(dynamic value) {
    final date = DateTime.tryParse('$value');
    return date == null
        ? ''
        : DateFormat.yMd(Localizations.localeOf(context).languageCode)
            .add_Hm()
            .format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final auth = context.watch<AuthService>();
    final organizer = auth.currentUser?.role == UserRole.organizer;
    final own = auth.currentUser?.id;
    final attendeeChat = auth.currentUser?.role == UserRole.attendee &&
        widget.flow == 'attendee' &&
        _view == 'mine';
    final rows = _rows
        .where((r) =>
            widget.caseId != null ||
            ((auth.currentUser?.role != UserRole.staff ||
                    _view != 'inbox' ||
                    r['assigned_to'] == own) &&
                (_status.isEmpty || r['status'] == _status) &&
                (_eventFilter.isEmpty || r['event_id'] == _eventFilter) &&
                (_categoryFilter.isEmpty || r['category'] == _categoryFilter) &&
                (_assigneeFilter.isEmpty ||
                    (_assigneeFilter == 'unassigned'
                        ? r['assigned_to'] == null
                        : r['assigned_to'] == _assigneeFilter)) &&
                ['subject', 'category', 'id'].any(
                    (key) => '${r[key] ?? ''}'.toLowerCase().contains(_query))))
        .toList();
    final events = <String, String>{
      if (organizer)
        for (final event in context.watch<DataService>().events)
          event.id: event.title,
      for (final r in _rows)
        if (r['event_id'] != null)
          r['event_id'] as String:
              (r['event_title'] ?? r['event_id']) as String,
    };
    final solved = _case?['status'] == 'resolved';
    final screenTitle = widget.caseId != null
        ? ((_case?['subject'] as String?) ??
            widget.subject ??
            l.profileContactUs)
        : (widget.flow == 'organizer_platform'
            ? l.supportPlatformFlow
            : (_view == 'inbox' ? l.supportAttendeeInbox : l.profileContactUs));
    final inboxRows = _rows
        .where((r) =>
            auth.currentUser?.role != UserRole.staff ||
            _view != 'inbox' ||
            r['assigned_to'] == own)
        .toList();
    return Scaffold(
        backgroundColor: widget.caseId == null && !attendeeChat
            ? AppColors.supportBackground
            : AppColors.caseBackground,
        appBar: AppBar(title: Text(screenTitle), actions: [
          if (widget.caseId == null &&
              widget.flow == 'attendee' &&
              _view == 'inbox' &&
              auth.currentUser?.isOrganizer == true)
            IconButton(
                tooltip: l.supportAuthorizeStaff,
                icon: const Icon(Icons.manage_accounts_outlined),
                onPressed: () => showDialog(
                    context: context,
                    builder: (_) => const SupportStaffDialog())),
          IconButton(
              tooltip: l.refreshStatus,
              onPressed: _loading || _busy ? null : _load,
              icon: const Icon(Icons.refresh)),
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_error != null) ...[
                        Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        TextButton(
                            onPressed: _busy ? null : _load,
                            child: Text(l.commonRetry))
                      ],
                      if (widget.caseId == null && !_creating) ...[
                        if (attendeeChat)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(l.supportChatHint,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          color: AppColors.textSecondary)))
                        else
                          SupportInboxHeader(
                            title: widget.flow == 'organizer_platform'
                                ? l.supportPlatformFlow
                                : l.supportAttendeeFlow,
                            total: '${l.supportCases}: ${inboxRows.length}',
                            counts: [
                              for (final status in supportStatuses)
                                (
                                  label: supportStatusLabel(context, status),
                                  status: status,
                                  count: inboxRows
                                      .where((r) => r['status'] == status)
                                      .length
                                )
                            ],
                          ),
                        const SizedBox(height: 20),
                        if (_view == 'mine')
                          FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryInk,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(16)),
                              onPressed: () => setState(() => _creating = true),
                              icon: const Icon(Icons.add),
                              label: Text(attendeeChat
                                  ? l.supportNewChat
                                  : l.supportNew)),
                        const SizedBox(height: 16),
                        if (!attendeeChat || _rows.length > 5)
                          TextField(
                              key: const ValueKey('support-search'),
                              decoration: InputDecoration(
                                  labelText: l.supportSearch,
                                  hintText: l.supportSearchHint,
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide.none),
                                  prefixIcon: const Icon(Icons.search)),
                              onChanged: (v) => setState(
                                  () => _query = v.trim().toLowerCase())),
                        const SizedBox(height: 12),
                        if (!attendeeChat)
                          Card(
                            color: Colors.white,
                            child: ExpansionTile(
                              key: const ValueKey('support-filters'),
                              leading: const Icon(Icons.tune_rounded,
                                  color: AppColors.supportBlue),
                              title: Text(l.supportFilters),
                              subtitle: Text(
                                  '${_status.isEmpty ? l.supportAllStatuses : supportStatusLabel(context, _status)} · ${l.supportCategory}'),
                              childrenPadding: const EdgeInsets.all(16),
                              children: [
                                DropdownButtonFormField<String>(
                                    key:
                                        const ValueKey('support-status-filter'),
                                    initialValue: _status,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                        labelText: l.supportStatusFilter),
                                    items: [
                                      DropdownMenuItem(
                                          value: '',
                                          child: Text(l.supportAllStatuses)),
                                      for (final s in supportStatuses)
                                        DropdownMenuItem(
                                            value: s,
                                            child: Text(
                                                supportStatusLabel(context, s)))
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _status = v!)),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                    key: const ValueKey('support-event-filter'),
                                    initialValue:
                                        events.containsKey(_eventFilter)
                                            ? _eventFilter
                                            : '',
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                        labelText: l.supportEventFilter),
                                    items: [
                                      DropdownMenuItem(
                                          value: '',
                                          child: Text(l.supportAllEvents)),
                                      for (final e in events.entries)
                                        DropdownMenuItem(
                                            value: e.key,
                                            child: Text(e.value,
                                                overflow:
                                                    TextOverflow.ellipsis))
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _eventFilter = v!)),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                    key: const ValueKey(
                                        'support-category-filter'),
                                    initialValue: _categoryFilter,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                        labelText: l.supportCategory),
                                    items: [
                                      DropdownMenuItem(
                                          value: '',
                                          child: Text(l.supportAllCategories)),
                                      for (final category in _categories)
                                        DropdownMenuItem(
                                            value: category,
                                            child: Text(supportCategoryLabel(
                                                context, category)))
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _categoryFilter = v!)),
                                const SizedBox(height: 16),
                                if (_view == 'inbox') ...[
                                  DropdownButtonFormField<String>(
                                      key: const ValueKey(
                                          'support-assignee-filter'),
                                      initialValue: _assigneeFilter,
                                      isExpanded: true,
                                      decoration: InputDecoration(
                                          labelText: l.supportAssignee),
                                      items: [
                                        DropdownMenuItem(
                                            value: '',
                                            child: Text(l.supportAllAssignees)),
                                        DropdownMenuItem(
                                            value: 'unassigned',
                                            child: Text(l.supportUnassigned)),
                                        for (final entry in {
                                          for (final r in _rows)
                                            if (r['assigned_to'] != null)
                                              r['assigned_to'] as String:
                                                  (r['assignee_name'] ??
                                                          r['assigned_to'])
                                                      as String
                                        }.entries)
                                          DropdownMenuItem(
                                              value: entry.key,
                                              child: Text(entry.value,
                                                  overflow:
                                                      TextOverflow.ellipsis))
                                      ],
                                      onChanged: (v) =>
                                          setState(() => _assigneeFilter = v!)),
                                  const SizedBox(height: 16),
                                ],
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        if (!attendeeChat)
                          Text('${l.supportCases}: ${rows.length}',
                              style: Theme.of(context).textTheme.titleMedium),
                        if (rows.isEmpty && !_creating)
                          Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(18)),
                              child: Column(children: [
                                const Icon(Icons.mark_chat_read_outlined,
                                    size: 40, color: AppColors.primaryInk),
                                const SizedBox(height: 12),
                                Text(
                                    auth.currentUser?.role == UserRole.staff &&
                                            auth.currentUser?.supportAccess !=
                                                true
                                        ? l.supportStaffDenied
                                        : attendeeChat
                                            ? l.supportNoChats
                                            : l.supportEmpty,
                                    textAlign: TextAlign.center),
                              ])),
                        for (final row in rows)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: SupportCaseCard(
                                  compact: attendeeChat,
                                  row: row,
                                  status: supportStatusLabel(
                                      context, row['status']),
                                  category: supportCategoryLabel(
                                      context, row['category']),
                                  assignee: row['assignee_name'] as String? ??
                                      l.supportUnassigned,
                                  onTap: () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => SupportScreen(
                                                caseId: row['id'],
                                                subject: row['subject'],
                                                flow: widget.flow,
                                                view: _view)));
                                    if (mounted) await _load();
                                  })),
                      ] else if (widget.caseId != null) ...[
                        if (_case != null) ...[
                          SupportCaseHeading(
                            compact: attendeeChat,
                            flow: _case!['flow'] == 'organizer_platform'
                                ? l.supportPlatformFlow
                                : l.supportAttendeeFlow,
                            number:
                                '${l.supportCaseNumber}: ${_case!['number'] ?? _case!['id']}',
                            status:
                                supportStatusLabel(context, _case!['status']),
                            category: supportCategoryLabel(
                                context, _case!['category']),
                            assignee:
                                '${l.supportAssignee}: ${_case!['assignee_name'] ?? l.supportUnassigned}',
                          ),
                          if (_case!['event_title'] != null ||
                              _case!['order_id'] != null ||
                              _case!['ticket_id'] != null ||
                              _case!['category'] == 'refund' ||
                              (_case!['routing'] == 'platform' &&
                                  _case!['flow'] != 'organizer_platform') ||
                              _case!['refund_policy'] != null ||
                              _case!['order_total_minor'] != null)
                            SupportCasePanel(
                                child: SupportCaseDetails(
                                    simple: attendeeChat,
                                    title: l.supportCaseDetails,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        spacing: 10,
                                        children: [
                                          if (!attendeeChat)
                                            Text(l.supportCaseDetails,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall
                                                    ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700)),
                                          if (_case!['routing'] == 'platform' &&
                                              _case!['flow'] !=
                                                  'organizer_platform')
                                            Text(_case!['category'] ==
                                                    'report_event'
                                                ? l.supportReportDestination
                                                : l.supportFallback),
                                          if (_case!['event_title'] != null)
                                            Text(_case!['event_title']),
                                          if (_case!['order_id'] != null)
                                            SelectableText(
                                                '${l.orderLabel}: ${_case!['order_id']}'),
                                          if (_case!['category'] ==
                                              'refund') ...[
                                            Text(l.supportRefundSeparate),
                                            Text(
                                                '${l.supportRefundState}: ${_case!['refund_status'] == null ? l.supportNoRefund : _case!['refund_status'] == 'succeeded' ? l.statusRefunded : _case!['refund_status'] == 'failed' ? l.statusFailed : l.statusPending}'),
                                            if (_case![
                                                    'refund_is_simulation'] ==
                                                true)
                                              Text(l.supportDemoRefund),
                                          ],
                                          if (_case!['ticket_id'] != null)
                                            SelectableText(
                                                '${l.attendanceTicketId}: ${_case!['ticket_id']}'),
                                          if (_case!['order_status'] != null)
                                            Text(
                                                '${l.orderLabel}: ${statusLabel(context, _case!['order_status'])}'),
                                          if (_case!['ticket_status'] != null)
                                            Text(
                                                '${l.eventTicketInfo}: ${statusLabel(context, _case!['ticket_status'])}'),
                                          if (_case!['refund_policy'] != null &&
                                              '${_case!['refund_policy']}'
                                                  .isNotEmpty)
                                            Text(
                                                '${l.refundPolicy}: ${_case!['refund_policy']}'),
                                          if (_case!['order_total_minor'] !=
                                              null)
                                            Text(
                                                '${l.totalLabel}: ${money(_case!['order_total_minor'] as num)}'),
                                        ]))),
                          if (_case!['can_refund'] == true ||
                              _case!['can_manage'] == true)
                            SupportCasePanel(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                  Text(l.supportManageCase,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                  if (_case!['can_refund'] == true) ...[
                                    const SizedBox(height: 16),
                                    Text(l.supportRefundApprovalHelp),
                                    const SizedBox(height: 12),
                                    FilledButton.icon(
                                        onPressed: _busy ? null : _approve,
                                        icon:
                                            const Icon(Icons.currency_exchange),
                                        label: Text(_busy
                                            ? l.commonLoading
                                            : l.supportApproveRefund)),
                                  ],
                                  if (_case!['can_manage'] == true) ...[
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                        key: ValueKey(
                                            'case-assignee-${_case!['assigned_to']}'),
                                        initialValue: _assignees.any((a) =>
                                                a['id'] ==
                                                _case!['assigned_to'])
                                            ? _case!['assigned_to'] as String
                                            : '',
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                            labelText: l.supportAssignee),
                                        items: [
                                          DropdownMenuItem(
                                              value: '',
                                              child: Text(l.supportUnassigned)),
                                          for (final a in _assignees)
                                            DropdownMenuItem(
                                                value: a['id'] as String,
                                                child: Text(a['name'],
                                                    overflow:
                                                        TextOverflow.ellipsis))
                                        ],
                                        onChanged: _busy
                                            ? null
                                            : (id) => _assign(id!)),
                                  ],
                                  if (_case!['can_manage'] == true &&
                                      !(_case!['category'] == 'refund' &&
                                          _case!['order_status'] ==
                                              'refunded')) ...[
                                    const SizedBox(height: 16),
                                    DropdownButtonFormField<String>(
                                        key: ValueKey(
                                            'case-status-${_case!['status']}'),
                                        initialValue: _case!['status'],
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                            labelText: l.supportStatusFilter),
                                        items: [
                                          for (final s in supportStatuses)
                                            DropdownMenuItem(
                                                value: s,
                                                child: Text(supportStatusLabel(
                                                    context, s)))
                                        ],
                                        onChanged: _busy
                                            ? null
                                            : (v) => _changeStatus(v!)),
                                  ],
                                ])),
                        ],
                        const SizedBox(height: 20),
                        Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(children: [
                              const Icon(Icons.forum_outlined,
                                  color: AppColors.primaryInk, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(l.supportConversation,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700))),
                            ])),
                        for (final row in _rows)
                          SupportMessageBubble(
                            own: row['sender_id'] == own,
                            sender: '${row['sender_name'] ?? row['sender_id']}',
                            timestamp: _timestamp(row['created_at']),
                            body: row['body'] as String,
                          ),
                        if (_history.isNotEmpty && !attendeeChat)
                          ExpansionTile(
                              title: Text(l.supportHistory),
                              children: [
                                for (final change in _history)
                                  ListTile(
                                      title: Text(
                                          '${change['actor_name']} · ${_timestamp(change['created_at'])}'),
                                      subtitle: Text(
                                          '${change['kind'] == 'status' ? l.supportStatusFilter : change['kind'] == 'assignment' ? l.supportAssignee : l.supportOpen}: ${change['kind'] == 'status' ? supportStatusLabel(context, change['new_value'] ?? '') : change['new_name'] ?? change['new_value'] ?? l.supportUnassigned}')),
                              ]),
                        if (solved)
                          SupportCasePanel(
                              highlight: true,
                              child: Row(children: [
                                const Icon(Icons.check_circle_outline,
                                    color: AppColors.primaryInk),
                                const SizedBox(width: 12),
                                Expanded(child: Text(l.supportResolvedHelp)),
                              ])),
                      ],
                      if ((widget.caseId != null && _case != null && !solved) ||
                          _creating)
                        SupportCasePanel(
                            child: Form(
                                key: _form,
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                          widget.caseId == null
                                              ? l.supportNew
                                              : l.supportReply,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 12),
                                      if (widget.caseId == null) ...[
                                        if (attendeeChat &&
                                            widget.eventId == null &&
                                            widget.orderId == null &&
                                            widget.ticketId == null)
                                          SupportDestinationPicker(
                                              onChanged: (eventId, orderId) {
                                            _contextEvent = eventId;
                                            _contextOrder = orderId;
                                          })
                                        else
                                          Text(attendeeChat
                                              ? (_category == 'report_event'
                                                  ? l.supportReportDestination
                                                  : l.supportSentToOrganizer)
                                              : widget.flow ==
                                                      'organizer_platform'
                                                  ? l.supportPlatformFlow
                                                  : l.supportAttendeeFlow),
                                        if (widget.flow ==
                                                'organizer_platform' &&
                                            widget.eventId == null) ...[
                                          DropdownButtonFormField<String>(
                                              initialValue: _contextEvent ?? '',
                                              isExpanded: true,
                                              decoration: InputDecoration(
                                                  labelText:
                                                      l.supportEventFilter),
                                              items: [
                                                DropdownMenuItem(
                                                    value: '',
                                                    child:
                                                        Text(l.supportNoEvent)),
                                                for (final e in context
                                                    .watch<DataService>()
                                                    .eventsByOrganizer(auth
                                                            .currentUser
                                                            ?.name ??
                                                        ''))
                                                  DropdownMenuItem(
                                                      value: e.id,
                                                      child: Text(e.title,
                                                          overflow: TextOverflow
                                                              .ellipsis))
                                              ],
                                              onChanged: _busy
                                                  ? null
                                                  : (v) => setState(() =>
                                                      _contextEvent = v!.isEmpty
                                                          ? null
                                                          : v)),
                                          const SizedBox(height: 12),
                                        ],
                                        if (widget.eventId != null)
                                          SelectableText(
                                              '${l.supportEventFilter}: ${_category == 'report_event' ? widget.subject ?? widget.eventId : widget.eventId}'),
                                        if (_category == 'refund') ...[
                                          Text(l.supportRefundRequestHelp),
                                          const SizedBox(height: 12)
                                        ],
                                        if (!attendeeChat)
                                          TextFormField(
                                              controller: _subject,
                                              enabled: !_busy,
                                              maxLength: 200,
                                              decoration: InputDecoration(
                                                  labelText: l.supportSubject),
                                              validator: (v) => (v ?? '')
                                                          .trim()
                                                          .isNotEmpty &&
                                                      (v ?? '').trim().length <
                                                          3
                                                  ? l.applicationInvalid
                                                  : null),
                                        const SizedBox(height: 12),
                                        DropdownButtonFormField<String>(
                                            initialValue: _category,
                                            isExpanded: true,
                                            decoration: InputDecoration(
                                                labelText: l.supportCategory),
                                            items: [
                                              for (final category
                                                  in _categories)
                                                DropdownMenuItem(
                                                    value: category,
                                                    child: Text(
                                                        supportCategoryLabel(
                                                            context, category)))
                                            ],
                                            onChanged: _busy
                                                ? null
                                                : (v) => setState(
                                                    () => _category = v!)),
                                      ],
                                      const SizedBox(height: 16),
                                      TextFormField(
                                          controller: _message,
                                          enabled: !_busy,
                                          maxLength: 10000,
                                          minLines: 3,
                                          maxLines: 6,
                                          decoration: InputDecoration(
                                              labelText: l.supportMessage),
                                          validator: (v) =>
                                              (v ?? '').trim().isEmpty
                                                  ? l.applicationInvalid
                                                  : null),
                                      const SizedBox(height: 16),
                                      FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  AppColors.primaryInk,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12))),
                                          icon: const Icon(Icons.send_rounded,
                                              size: 18),
                                          onPressed: _busy ? null : _send,
                                          label: Text(_busy
                                              ? l.commonLoading
                                              : l.supportSend)),
                                      if (widget.caseId == null)
                                        TextButton(
                                            onPressed: _busy
                                                ? null
                                                : () => setState(
                                                    () => _creating = false),
                                            child: Text(l.commonCancel)),
                                    ]))),
                    ])));
  }
}
