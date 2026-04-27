import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  // On place le contrôleur ici pour pouvoir l'arrêter proprement
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates, // Évite de scanner 10 fois le même code
    formats: [BarcodeFormat.all],
  );

  bool hasScanned = false; // Sécurité pour ne faire le "pop" qu'une seule fois

  @override
  void dispose() {
    controller.dispose(); // Très important pour libérer la caméra
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner le Code-Barre'),
        backgroundColor: const Color(0xFF0056D2),
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: (capture) {
          if (hasScanned) return; // Si on a déjà scanné, on ignore la suite

          final List<Barcode> barcodes = capture.barcodes;
          if (barcodes.isNotEmpty) {
            hasScanned = true; // On verrouille
            final String code = barcodes.first.rawValue ?? "---";

            debugPrint('✅ Code trouvé : $code');

            // On arrête la caméra avant de partir
            controller.stop().then((_) {
              if (mounted) {
                Navigator.pop(context, code); // Retour à l'accueil avec le code
              }
            });
          }
        },
      ),
    );
  }
}