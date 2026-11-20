import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/loc_extensions.dart';
import '../../services/data_service.dart';

class CampaignQrScreen extends StatefulWidget {
  const CampaignQrScreen(
      {super.key, required this.eventId, required this.campaign});
  final String eventId;
  final Map<String, dynamic> campaign;
  @override
  State<CampaignQrScreen> createState() => _CampaignQrScreenState();
}

class _CampaignQrScreenState extends State<CampaignQrScreen> {
  late Future<Uint8List> _png;
  bool _sharing = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _png = context.read<DataService>().api.download(
        '/events/${Uri.encodeComponent(widget.eventId)}/campaigns/${Uri.encodeComponent(widget.campaign['id'] as String)}/qr');
  }

  Future<void> _share(Uint8List bytes) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png')],
        fileNameOverrides: const ['campaign-qr.png'],
        text:
            '${context.l10n.campaignNotAdmission}\n${widget.campaign['campaign_url']}',
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
        appBar: AppBar(title: Text(l.campaignQr)),
        body: FutureBuilder<Uint8List>(
            future: _png,
            builder: (context, snapshot) => Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
                      Text(l.campaignNotAdmission,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(l.campaignHelp),
                      const SizedBox(height: 20),
                      if (snapshot.hasData) ...[
                        Image.memory(snapshot.data!,
                            semanticLabel: l.campaignQr,
                            errorBuilder: (_, __, ___) =>
                                Text(l.requestFailed)),
                        SelectableText(
                            widget.campaign['campaign_url'] as String),
                        FilledButton.icon(
                            onPressed:
                                _sharing ? null : () => _share(snapshot.data!),
                            icon: const Icon(Icons.share),
                            label: Text(l.campaignShare)),
                      ] else if (snapshot.hasError) ...[
                        Text(snapshot.error.toString()),
                        OutlinedButton(
                            onPressed: () => setState(_load),
                            child: Text(l.commonRetry)),
                      ] else
                        const Center(child: CircularProgressIndicator()),
                    ])))));
  }
}
