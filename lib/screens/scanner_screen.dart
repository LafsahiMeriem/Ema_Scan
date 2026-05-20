import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.all],
  );

  bool hasScanned = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner un Code-Barre'),
        backgroundColor: const Color(0xFF0F172A),
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (hasScanned) return;

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            hasScanned = true;
            final String codeScanne = barcodes.first.rawValue ?? "";

            controller.stop().then((_) {
              if (mounted) {
                Navigator.pop(context, codeScanne);
              }
            });
          }
        },
      ),
    );
  }
}