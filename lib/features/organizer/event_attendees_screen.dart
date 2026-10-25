import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/data_service.dart';
import '../attendee/attendee_ui.dart';

/// Uses event orders, matching the web: one row may cover multiple admission tickets.
class EventAttendeesScreen extends StatefulWidget {
  const EventAttendeesScreen(
      {super.key, required this.eventId, required this.eventTitle});
  final String eventId;
  final String eventTitle;
  @override
  State<EventAttendeesScreen> createState() => _EventAttendeesScreenState();
}

class _EventAttendeesScreenState extends State<EventAttendeesScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _orders = [];
  bool _loading = true;
  String? _error;
  String _status = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows =
          await context.read<DataService>().listEventAttendees(widget.eventId);
      if (mounted) setState(() => _orders = rows);
    } catch (error) {
      if (mounted) {
        setState(() {
          _orders = [];
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final query = _search.text.trim().toLowerCase();
    final rows = _orders
        .where((order) =>
            (_status.isEmpty || order['status'] == _status) &&
            ['attendee_name', 'attendee_email', 'id'].any((key) =>
                (order[key] ?? '').toString().toLowerCase().contains(query)))
        .toList();
    final statuses = [
      '',
      'confirmed',
      'pending',
      'refunded',
      'partially_refunded',
      'cancelled',
      'expired',
      'payment_failed'
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.organizerViewAttendees), actions: [
        IconButton(
            tooltip: l.refreshStatus,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh)),
      ]),
      body: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(widget.eventTitle,
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            Text(l.attendeeOrdersHelp),
                            const SizedBox(height: 20),
                            TextField(
                                controller: _search,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  labelText: l.attendeeSearch,
                                  hintText: l.attendeeSearchHint,
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: _search.text.isEmpty
                                      ? null
                                      : IconButton(
                                          tooltip: l.clearFilters,
                                          icon: const Icon(Icons.clear),
                                          onPressed: () =>
                                              setState(_search.clear)),
                                )),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              isExpanded: true,
                              decoration: InputDecoration(
                                  labelText: l.attendeeOrderStatus),
                              items: [
                                for (final status in statuses)
                                  DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                          '${status.isEmpty ? l.attendeeAllOrders : statusLabel(context, status)} (${_orders.where((order) => status.isEmpty || order['status'] == status).length})'))
                              ],
                              onChanged: (value) =>
                                  setState(() => _status = value!),
                            ),
                            const SizedBox(height: 16),
                            Text('${l.attendeeMatchingOrders}: ${rows.length}'),
                            if (_loading) ...[
                              const SizedBox(height: 16),
                              const LinearProgressIndicator()
                            ],
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Text(_error!,
                                  style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error)),
                              OutlinedButton(
                                  onPressed: _load, child: Text(l.commonRetry))
                            ],
                          ]))),
              if (!_loading && _error == null && rows.isEmpty)
                SliverToBoxAdapter(
                    child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                            _orders.isEmpty
                                ? l.attendeeNoOrders
                                : l.attendeeNoMatches,
                            textAlign: TextAlign.center))),
              SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  sliver: SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final order = rows[index];
                      final items = order['items'] as List?;
                      final quantity = items?.fold<int>(
                          0, (sum, item) => sum + (item['quantity'] as int));
                      return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(order['attendee_name'] as String,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 8),
                                      SelectableText(
                                          order['attendee_email'] as String),
                                      const SizedBox(height: 12),
                                      Align(
                                          alignment: Alignment.centerLeft,
                                          child: StatusBadge(order['status'])),
                                      const SizedBox(height: 12),
                                      SelectableText(
                                          '${l.orderLabel}: ${order['id']}'),
                                      if (quantity != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                            '${l.attendeeTicketCount}: $quantity')
                                      ],
                                      const SizedBox(height: 12),
                                      Text(
                                          '${l.totalLabel}: ${money(order['total_minor'] as num)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                    ]),
                              )));
                    },
                  )),
            ],
          )),
    );
  }
}
