import 'package:ema_lot_scanner/screens/setting_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lot_info.dart';
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
  LotInfo? lotDetails;
  bool isLoading = false;

  // Liste globale pour la recherche manuelle si besoin
  List<Map<String, String>> allWarehouses = [];

  @override
  void initState() {
    super.initState();
    _chargerMagasins();
  }

  Future<void> _chargerMagasins() async {
    final list = await _sapService.fetchAllWarehouses();
    if (mounted) {
      setState(() => allWarehouses = list);
    }
  }

  // --- LOGIQUE DE LOGIN POUR LA CONFIG ---
  void _showLoginDialog() {
    final TextEditingController userCtrl = TextEditingController();
    final TextEditingController passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Accès Configuration"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: userCtrl, decoration: const InputDecoration(labelText: "Utilisateur")),
            TextField(controller: passCtrl, decoration: const InputDecoration(labelText: "Mot de passe"), obscureText: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              // Login forcé dans le code
              if (userCtrl.text == "admin" && passCtrl.text == "1234") {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              } else {
                _showError("Identifiants incorrects");
              }
            },
            child: const Text("Valider"),
          ),
        ],
      ),
    );
  }

  // --- FONCTION DE TRANSFERT COMPLETE ---
  Future<void> _executerTransfert(String destinationWhs) async {
    if (lotDetails == null) return;

    setState(() => isLoading = true);

    try {
      // 1. Récupérer le magasin SOURCE depuis la configuration sauvegardée
      final prefs = await SharedPreferences.getInstance();
      String sourceWhs = prefs.getString('whsSource') ?? "ZPF-BC"; // "ZPF-BC" par défaut si vide

      // 2. Calculer la quantité totale (QteCarton * NumInCnt)
      double quantiteTotale = lotDetails!.totalQuantity;

      // 3. Envoyer à SAP
      String? errorMessage = await _sapService.createStockTransfer(
        itemCode: lotDetails!.itemCode,
        batchNumber: lotDetails!.distNumber,
        fromWhs: sourceWhs,
        toWhs: destinationWhs,
        quantity: quantiteTotale,
      );

      setState(() => isLoading = false);

      if (errorMessage == null) {
        _showSuccess("Transfert de $quantiteTotale unités réussi ! ($sourceWhs -> $destinationWhs)");
        setState(() {
          lotDetails = null;
          _lotController.clear();
        });
      } else {
        _showError("Erreur SAP : $errorMessage");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError("Erreur locale : $e");
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[800], behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green[800], behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _recupererData() async {
    String lot = _lotController.text.trim();
    if (lot.isEmpty) return;
    setState(() => isLoading = true);
    final data = await _sapService.fetchLotData(lot);
    setState(() {
      lotDetails = data;
      isLoading = false;
    });
    if (data == null) _showError("Lot introuvable dans SAP.");
  }

  Future<void> _selectionnerEtTransferer() async {
    if (allWarehouses.isEmpty) await _chargerMagasins();

    final selectedWhsCode = await showSearch<String>(
      context: context,
      delegate: WarehouseSearchDelegate(allWarehouses),
    );

    if (selectedWhsCode != null) {
      _executerTransfert(selectedWhsCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EMA ChocoScan'),
        backgroundColor: Colors.blue[900],
        foregroundColor: Colors.white,
      ),
      // --- MENU TIRETS (DRAWER) ---
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue[900]),
              child: const Text("PARAMÈTRES", style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text("Configuration Magasins"),
              onTap: () {
                Navigator.pop(context); // Ferme le menu
                _showLoginDialog();
              },
            ),
          ],
        ),
      ),
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
                    if (result != null) {
                      setState(() => _lotController.text = result);
                      _recupererData();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("RÉCUPÉRER DATA"),
              onPressed: isLoading ? null : _recupererData,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 25),

            if (isLoading) const CircularProgressIndicator(),

            if (lotDetails != null && !isLoading) ...[
              _buildDetailCard("Informations Article", [
                _detailRow("Article", lotDetails!.itemName),
                _detailRow("Lot", lotDetails!.distNumber),
                _detailRow("Code Article", lotDetails!.itemCode),
                const Divider(),
                _detailRow("Qte Carton", "${lotDetails!.qteCarton}"),
                _detailRow("Unités/Carton", "${lotDetails!.numInCnt}"),
                _detailRow("TOTAL UNITÉS", "${lotDetails!.totalQuantity}", isBold: true),
              ]),
              const SizedBox(height: 25),
              ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: const Text("CHOISIR DESTINATION & TRANSFÉRER"),
                onPressed: _selectionnerEtTransferer,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  backgroundColor: Colors.orange[900],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(15.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
        const Divider(),
        ...children
      ])),
    );
  }

  Widget _detailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: isBold ? Colors.blue[900] : Colors.black54)),
          Flexible(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isBold ? 16 : 14, color: isBold ? Colors.blue[900] : Colors.black), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

// Delegate pour la recherche des magasins
class WarehouseSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, String>> warehouses;
  WarehouseSearchDelegate(this.warehouses);

  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final suggestions = warehouses.where((whs) {
      final input = query.toLowerCase();
      return whs['name']!.toLowerCase().contains(input) || whs['code']!.toLowerCase().contains(input);
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) => ListTile(
        leading: const Icon(Icons.storefront),
        title: Text(suggestions[index]['name']!),
        subtitle: Text("Code: ${suggestions[index]['code']}"),
        onTap: () => close(context, suggestions[index]['code']!),
      ),
    );
  }
}