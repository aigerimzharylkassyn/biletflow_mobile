import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/responsive_cards.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/theme.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/data_service.dart';
import '../attendee/attendee_ui.dart';
import '../organizer/event_management_screen.dart';

class AdminOperationsScreen extends StatefulWidget {
  const AdminOperationsScreen({super.key});
  @override
  State<AdminOperationsScreen> createState() => _AdminOperationsScreenState();
}

class _AdminOperationsScreenState extends State<AdminOperationsScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  String _query = '', _status = '';
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _loading = true, _exporting = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await context
          .read<DataService>()
          .api
          .request('GET', '/admin/operations/orders');
      if (mounted) {
        setState(() => _data = Map<String, dynamic>.from(result as Map));
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export(List<dynamic> rows) async {
    setState(() => _exporting = true);
    try {
      String cell(Object? value) {
        var text = '$value';
        // Prevent spreadsheet formula execution from attendee-controlled fields.
        if (RegExp(r'^\s*[=+@\-]|^[\t\r\n]').hasMatch(text)) text = "'$text";
        return '"${text.replaceAll('"', '""')}"';
      }

      final csv = [
        'order_id,event,attendee,email,status,total_minor,currency,created_at',
        for (final r in rows)
          [
            r['id'],
            r['event_title'],
            r['attendee_name'],
            r['attendee_email'],
            r['status'],
            r['total_minor'],
            r['currency'],
            r['created_at']
          ].map(cell).join(',')
      ].join('\r\n');
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
          files: [
            XFile.fromData(Uint8List.fromList(utf8.encode('\uFEFF$csv')),
                mimeType: 'text/csv')
          ],
          fileNameOverrides: [
            'biletflow-orders.csv'
          ],
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Widget _panel(Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: AppColors.divider)),
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: const EdgeInsets.all(20), child: child)));

  Widget _metric(String label, int count, IconData icon, Color color) =>
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text('$count',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]));

  Widget _transaction(Map payment, {bool refund = false}) {
    final l = context.l10n;
    final failed = payment['status'] == 'failed';
    final color = failed
        ? AppColors.error
        : refund
            ? AppColors.primaryInk
            : AppColors.success;
    return Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(12)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                refund
                    ? Icons.undo_rounded
                    : failed
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                color: color,
                size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Text(refund ? l.managementRefunds : l.managementPayment,
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 8),
          Text(money(payment['amount_minor']),
              style: Theme.of(context).textTheme.titleMedium),
          Text(statusLabel(context, payment['status'])),
          const SizedBox(height: 8),
          SelectableText(
              (refund ? payment['reason'] : payment['reference']) ?? '',
              style: Theme.of(context).textTheme.bodySmall),
        ]));
  }

  Widget _order(Map r) {
    final l = context.l10n;
    final date = DateTime.tryParse(r['created_at']?.toString() ?? '');
    return _panel(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.receipt_long_outlined,
                color: AppColors.primaryInk)),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(r['event_title'],
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          StatusBadge(r['status']),
        ])),
      ]),
      const SizedBox(height: 20),
      Text(r['attendee_name'], style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 4),
      Text(r['attendee_email'], style: Theme.of(context).textTheme.bodySmall),
      if (date != null) ...[
        const SizedBox(height: 8),
        Text(
            DateFormat.yMMMd(Localizations.localeOf(context).toString())
                .add_Hm()
                .format(date.toLocal()),
            style: Theme.of(context).textTheme.bodySmall)
      ],
      const SizedBox(height: 16),
      Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.caseBackground,
              borderRadius: BorderRadius.circular(12)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.totalLabel, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(money(r['total_minor']),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.primaryInk)),
          ])),
      const SizedBox(height: 8),
      Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: Text(l.operationsDetails,
                  style: Theme.of(context).textTheme.titleSmall),
              children: [
                Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText('${l.orderLabel}: ${r['id']}',
                        style: Theme.of(context).textTheme.bodySmall)),
                for (final p in r['payments'] as List) _transaction(p as Map),
                for (final f in r['refunds'] as List)
                  _transaction(f as Map, refund: true),
              ])),
      const SizedBox(height: 8),
      OutlinedButton.icon(
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EventManagementScreen(
                      eventId: r['event_id'], title: r['event_title']))),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: Text(l.managementTitle)),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final orders = _data?['orders'] as List? ?? [];
    final rows = orders
        .where((r) =>
            (_status.isEmpty || r['status'] == _status) &&
            '${r['id']} ${r['event_title']} ${r['attendee_name']} ${r['attendee_email']} ${r['payments']}'
                .toLowerCase()
                .contains(_query))
        .toList();
    return Scaffold(
        backgroundColor: AppColors.caseBackground,
        appBar: AppBar(title: Text(l.managementMonitor), actions: [
          IconButton(
              tooltip: l.refreshStatus,
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                    margin: const EdgeInsets.only(bottom: 20),
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                        color: AppColors.primarySoft,
                                        borderRadius:
                                            BorderRadius.circular(24)),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(l.adminOverview,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                      color:
                                                          AppColors.primaryInk,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                          const SizedBox(height: 16),
                                          if (_loading && _data == null)
                                            const LinearProgressIndicator()
                                          else if (_data != null)
                                            ResponsiveCards(
                                                minimumWidth: 140,
                                                children: [
                                                  _metric(
                                                      l.attendeeAllOrders,
                                                      orders.length,
                                                      Icons
                                                          .receipt_long_outlined,
                                                      AppColors.primaryInk),
                                                  _metric(
                                                      l.statusPending,
                                                      orders
                                                          .where((r) =>
                                                              r['status'] ==
                                                              'pending')
                                                          .length,
                                                      Icons.schedule,
                                                      AppColors.textSecondary),
                                                  _metric(
                                                      l.statusFailed,
                                                      orders
                                                          .where((r) =>
                                                              r['status'] ==
                                                              'payment_failed')
                                                          .length,
                                                      Icons.error_outline,
                                                      AppColors.error),
                                                  _metric(
                                                      l.statusRefunded,
                                                      orders
                                                          .where((r) =>
                                                              r['status'] ==
                                                              'refunded')
                                                          .length,
                                                      Icons.undo_rounded,
                                                      AppColors.primaryInk),
                                                ]),
                                          const SizedBox(height: 16),
                                          Text(l.managementSimulation,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                      color: AppColors
                                                          .primaryInk)),
                                        ])),
                                _panel(Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                          controller: _search,
                                          decoration: InputDecoration(
                                              labelText: l.operationsSearch,
                                              prefixIcon:
                                                  const Icon(Icons.search),
                                              suffixIcon: _search.text.isEmpty
                                                  ? null
                                                  : IconButton(
                                                      tooltip: l.clearFilters,
                                                      icon: const Icon(
                                                          Icons.close),
                                                      onPressed: () {
                                                        _search.clear();
                                                        setState(
                                                            () => _query = '');
                                                      })),
                                          onChanged: (v) => setState(() =>
                                              _query = v.trim().toLowerCase())),
                                      const SizedBox(height: 8),
                                      Text(l.managementSearch,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                      const SizedBox(height: 20),
                                      DropdownButtonFormField<String>(
                                          key: ValueKey(_status),
                                          initialValue: _status,
                                          isExpanded: true,
                                          decoration: InputDecoration(
                                              labelText: l.attendeeOrderStatus),
                                          items: [
                                            for (final s in [
                                              '',
                                              'confirmed',
                                              'pending',
                                              'payment_failed',
                                              'refunded',
                                              'cancelled',
                                              'expired'
                                            ])
                                              DropdownMenuItem(
                                                  value: s,
                                                  child: Text(s.isEmpty
                                                      ? l.attendeeAllOrders
                                                      : statusLabel(
                                                          context, s)))
                                          ],
                                          onChanged: (v) =>
                                              setState(() => _status = v!)),
                                      const SizedBox(height: 16),
                                      Wrap(
                                          spacing: 12,
                                          runSpacing: 8,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            OutlinedButton.icon(
                                                onPressed: _loading ||
                                                        _error != null ||
                                                        _exporting ||
                                                        rows.isEmpty
                                                    ? null
                                                    : () => _export(rows),
                                                icon: _exporting
                                                    ? const SizedBox(
                                                        width: 18,
                                                        height: 18,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2))
                                                    : const Icon(
                                                        Icons.ios_share,
                                                        size: 18),
                                                label:
                                                    Text(l.managementExport)),
                                            if (_query.isNotEmpty ||
                                                _status.isNotEmpty)
                                              TextButton(
                                                  onPressed: () {
                                                    _search.clear();
                                                    setState(() {
                                                      _query = '';
                                                      _status = '';
                                                    });
                                                  },
                                                  child: Text(l.clearFilters)),
                                          ]),
                                    ])),
                                if (_loading && _data != null)
                                  const Padding(
                                      padding: EdgeInsets.only(bottom: 16),
                                      child: LinearProgressIndicator()),
                                if (_error != null)
                                  _panel(Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const Icon(Icons.cloud_off_outlined,
                                            color: AppColors.error),
                                        const SizedBox(height: 12),
                                        Text(_error!,
                                            textAlign: TextAlign.center),
                                        TextButton(
                                            onPressed: _load,
                                            child: Text(l.commonRetry))
                                      ])),
                                if (!_loading && _error == null) ...[
                                  if (_data != null)
                                    _panel(Theme(
                                        data: Theme.of(context).copyWith(
                                            dividerColor: Colors.transparent),
                                        child: ExpansionTile(
                                            tilePadding: EdgeInsets.zero,
                                            leading: const Icon(
                                                Icons.tune_rounded,
                                                color: AppColors.primaryInk),
                                            title: Text(
                                                l.managementFeeConfiguration,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleSmall),
                                            children: [
                                              const SizedBox(height: 8),
                                              ResponsiveCards(children: [
                                                Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(l.managementActivationFee,
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                          money(_data![
                                                                  'activation_fee_minor']
                                                              as num),
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleMedium)
                                                    ]),
                                                Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(l.managementFees,
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .bodySmall),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                          '${(_data!['processing_fee_bps'] as num) / 100}%',
                                                          style:
                                                              Theme.of(context)
                                                                  .textTheme
                                                                  .titleMedium)
                                                    ]),
                                              ]),
                                              const SizedBox(height: 8),
                                            ]))),
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: Text(
                                          '${l.attendeeMatchingOrders}: ${rows.length}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall)),
                                  if (rows.isEmpty)
                                    _panel(Column(children: [
                                      const Icon(Icons.search_off_rounded,
                                          size: 36,
                                          color: AppColors.primaryInk),
                                      const SizedBox(height: 12),
                                      Text(l.managementNoData,
                                          textAlign: TextAlign.center)
                                    ])),
                                  for (final r in rows) _order(r as Map),
                                ],
                              ]))),
                ])));
  }
}
