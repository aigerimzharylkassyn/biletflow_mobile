import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../l10n/loc_extensions.dart';

/// A separate route keeps the camera off when the check-in tab is hidden.
class TicketScannerScreen extends StatefulWidget {
  const TicketScannerScreen({super.key});

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen> {
  bool _detected = false;

  void _onDetect(BarcodeCapture capture) {
    if (_detected || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (barcode.format != BarcodeFormat.qrCode ||
          value == null ||
          value.isEmpty) {
        continue;
      }
      _detected = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.checkinScan)),
      body: Column(children: [
        Expanded(
            child: MobileScanner(
          onDetect: _onDetect,
          errorBuilder: (context, error) => SingleChildScrollView(
              child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.no_photography_outlined, size: 48),
              const SizedBox(height: 16),
              Text(l.checkinCameraError, textAlign: TextAlign.center),
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.organizerEnterCodeManually)),
            ]),
          )),
        )),
        SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child:
                  Text(l.organizerScanInstruction, textAlign: TextAlign.center),
            )),
      ]),
    );
  }
}
