import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lot_info.dart';
import '../services/sap_service.dart';
import 'scanner_screen.dart';
import 'setting_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _lotController = TextEditingController();
  final SapService _sapService = SapService();
  LotInfo? lotDetails;
  bool isLoading = false;

  // --- LOGIQUE DE TRANSFERT ---
  Future<void> _executerTransfert(String type) async {
    if (lotDetails == null) return;
    setState(() => isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Récupération des magasins fixes selon le bouton cliqué
      String? sourceWhs = prefs.getString('whsSource');
      String? targetWhs = (type == "QUARANTAINE")
          ? prefs.getString('whsQuarantaine')
          : prefs.getString('whsLiberer');

      if (sourceWhs == null || targetWhs == null) {
        _showError("Erreur : Magasins non configurés dans les paramètres.");
        setState(() => isLoading = false);
        return;
      }

      String? error = await _sapService.createStockTransfer(
        itemCode: lotDetails!.itemCode,
        batchNumber: lotDetails!.distNumber,
        fromWhs: sourceWhs,
        toWhs: targetWhs,
        quantity: lotDetails!.totalQuantity,
      );

      setState(() => isLoading = false);

      if (error == null) {
        _showSuccess("Succès ! Transfert vers $targetWhs effectué.");
        setState(() { lotDetails = null; _lotController.clear(); });
      } else {
        _showError("SAP : $error");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError("Erreur : $e");
    }
  }

  // --- UI COMPONENTS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EMA ChocoScan'), backgroundColor: Colors.blue[900]),
      drawer: _buildDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            _buildScannerInput(),
            const SizedBox(height: 20),
            if (isLoading) const CircularProgressIndicator(),
            if (lotDetails != null && !isLoading) ...[
              _buildDataCard(),
              const SizedBox(height: 20),
              _buildActionButtons(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildScannerInput() {
    return TextField(
      controller: _lotController,
      decoration: InputDecoration(
        labelText: "Scanner Lot",
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () async {
            final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
            if (res != null) { _lotController.text = res; _fetchData(); }
          },
        ),
      ),
    );
  }

  void _fetchData() async {
    setState(() => isLoading = true);
    final data = await _sapService.fetchLotData(_lotController.text);
    setState(() { lotDetails = data; isLoading = false; });
    if (data == null) _showError("Lot introuvable.");
  }

  Widget _buildDataCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            _row("Article", lotDetails!.itemName, isBold: true),
            _row("Code", lotDetails!.itemCode),
            _row("Lot (DistNum)", lotDetails!.distNumber),
            _row("Quantité (Carton)", "${lotDetails!.qteCarton}"),
            const Divider(),
            _row("Date Production", lotDetails!.mfrDate ?? "-"),
            _row("Date Expiration", lotDetails!.expDate ?? "-"),
            _row("Mnf Serial", lotDetails!.mfrSerial ?? "-"),
            _row("Date Doc", lotDetails!.docDate ?? "-"),
            const Divider(),
            _row("TOTAL UNITÉS", "${lotDetails!.totalQuantity}", isBold: true, color: Colors.blue[900]),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    // On vérifie si on a un lot ET une quantité supérieure à 0
    bool canTransfer = lotDetails != null && lotDetails!.totalQuantity > 0;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: canTransfer ? () => _executerTransfert("QUARANTAINE") : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canTransfer ? Colors.orange[800] : Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text("QUARANTAINE"),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: canTransfer ? () => _executerTransfert("LIBERER") : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canTransfer ? Colors.green[800] : Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text("LIBÉRER"),
          ),
        ),
      ],
    );
  }
  // --- HELPER UI ---
  Widget _row(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color))),
        ],
      ),
    );
  }

  void _showError(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.red));
  void _showSuccess(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green));

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(decoration: BoxDecoration(color: Colors.blue[900]), child: const Text("EMA SCAN", style: TextStyle(color: Colors.white))),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Configuration"),
            onTap: () { Navigator.pop(context); _showLoginDialog(); },
          )
        ],
      ),
    );
  }

  void _showLoginDialog() {
    final u = TextEditingController();
    final p = TextEditingController();

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Admin"),
          content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: u, decoration: const InputDecoration(labelText: "User")),
                TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: "Pass"))
              ]
          ),
          actions: [
            ElevatedButton(
                onPressed: () {
                  // Changement du mot de passe ici
                  if(u.text.trim() == "admin" && p.text.trim() == "Bp5@maroc") {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  } else {
                    _showError("Identifiants incorrects");
                  }
                },
                child: const Text("Valider")
            )
          ],
        )
    );
  }}