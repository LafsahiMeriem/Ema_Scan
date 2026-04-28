import 'package:ema_lot_scanner/models/lot_info.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/sap_service.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _lotController = TextEditingController();
  final SapService _sapService = SapService();
  LotInfo? lotDetails; // On stocke l'objet complet ici
  bool isLoading = false;

  // À ajouter dans la classe _HomeScreenState
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[800],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _recupererData() async {
    String lot = _lotController.text.trim();
    if (lot.isEmpty) return;

    setState(() => isLoading = true);

    // On utilise la méthode de notre service
    final data = await _sapService.fetchLotData(lot);

    setState(() {
      lotDetails = data;
      isLoading = false;
    });

    if (data == null) {
      _showError("Lot introuvable ou erreur de connexion.");
    }
  }

  // ... (Garder _showError)

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EMA Data Recovery'), backgroundColor: Colors.blue[900]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _lotController,
              decoration: InputDecoration(
                labelText: "Lot scanné",
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context, MaterialPageRoute(builder: (_) => const ScannerScreen()),
                    );
                    if (result != null) setState(() => _lotController.text = result);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("RÉCUPÉRER DATA"),
              onPressed: isLoading ? null : _recupererData,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 25),

            if (isLoading) const CircularProgressIndicator(),

            if (lotDetails != null && !isLoading) ...[
              _buildDetailCard("Informations Article", [
                _detailRow("Nom Article", lotDetails!.itemName),
                _detailRow("Code Article", lotDetails!.itemCode),
                _detailRow("Lot", lotDetails!.distNumber),
              ]),
              const SizedBox(height: 15),
              _buildDetailCard("Détails Techniques", [
                _detailRow("Quantité", lotDetails!.qteCarton ?? "0"),
                _detailRow("MnfSerial", lotDetails!.mnfSerial ?? "---"),
                _detailRow("Date Production", lotDetails!.inDate ?? "---"),
                _detailRow("Date Expiration", lotDetails!.expDate ?? "---"),
                _detailRow("Sys Number", lotDetails!.sysNumber ?? "---"),
              ]),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
            const Divider(),
            ...children
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }
}