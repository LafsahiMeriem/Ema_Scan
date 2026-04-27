import 'package:flutter/material.dart';
import 'scanner_screen.dart';
import '../services/sap_service.dart';
import '../models/lot_info.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SapService _sapService = SapService();
  LotInfo? _lotData;
  bool _isLoading = false;

  void _scanAndFetch() async {
    // 1. Ouvre le scanner et attend le résultat
    final code = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerScreen()),
    );

    // 2. Si un code est bien récupéré, on l'affiche tout de suite
    if (code != null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _lotData = LotInfo(
          itemCode: "SCAN_DIRECT",        // Label pour indiquer le mode
          itemName: "Code détecté",       // Label pour indiquer le mode
          batchNum: code,                 // C'est ici qu'on affiche la valeur scannée !
        );
      });
    }
  }  // --- LES FONCTIONS DOIVENT ÊTRE ICI, AVANT LE BUILD ---

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMA Scan Lot'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0056D2),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : _lotData != null
                    ? _buildResultCard()
                    : _buildPlaceholder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _scanAndFetch,
              icon: const Icon(Icons.qr_code_scanner, size: 30),
              label: const Text("SCANNER UN LOT",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
                backgroundColor: const Color(0xFF0056D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2, color: Color(0xFF0056D2), size: 50),
            const Divider(height: 30),
            _infoRow("Numéro de Lot", _lotData!.batchNum),
            _infoRow("Code Article", _lotData!.itemCode),
            _infoRow("Désignation", _lotData!.itemName),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.barcode_reader, size: 100, color: Colors.grey.shade300),
        const SizedBox(height: 20),
        const Text("En attente de scan...",
            style: TextStyle(color: Colors.grey, fontSize: 16)),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}