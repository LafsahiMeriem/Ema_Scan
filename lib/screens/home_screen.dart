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

  // Palette de couleurs Pro
  final Color primaryColor = const Color(0xFF0D47A1); // Bleu SAP
  final Color backgroundColor = const Color(0xFFF4F7F9);
  final Color accentColor = const Color(0xFF1976D2);

  // --- LOGIQUE (CONCERT CONSERVÉ) ---
  Future<void> _executerTransfert(String type) async {
    if (lotDetails == null) return;
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      String? sourceWhs = prefs.getString('whsSource');
      String? targetWhs = (type == "QUARANTAINE")
          ? prefs.getString('whsQuarantaine')
          : prefs.getString('whsLiberer');

      if (sourceWhs == null || targetWhs == null) {
        _showError("Magasins non configurés");
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
        _showSuccess("Transfert réussi vers $targetWhs");
        setState(() { lotDetails = null; _lotController.clear(); });
      } else {
        _showError("SAP : $error");
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showError("Erreur : $e");
    }
  }

  void _fetchData() async {
    if (_lotController.text.isEmpty) return;
    setState(() => isLoading = true);
    final data = await _sapService.fetchLotData(_lotController.text);
    setState(() { lotDetails = data; isLoading = false; });
    if (data == null) _showError("Lot introuvable.");
  }

  // --- UI DESIGN ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('EMA ChocoScan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildSearchHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (isLoading)
                    Padding(padding: const EdgeInsets.only(top: 40), child: CircularProgressIndicator(color: primaryColor)),
                  if (lotDetails != null && !isLoading) ...[
                    _buildMainInfoCard(),
                    const SizedBox(height: 20),
                    _buildActionButtons(),
                  ] else if (!isLoading)
                    _buildEmptyState(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 25),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(25), bottomRight: Radius.circular(25)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: TextField(
          controller: _lotController,
          onSubmitted: (_) => _fetchData(),
          decoration: InputDecoration(
            hintText: "Scanner ou entrer un lot...",
            prefixIcon: Icon(Icons.search, color: primaryColor),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            suffixIcon: IconButton(
              icon: Icon(Icons.qr_code_scanner, color: primaryColor),
              onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
                if (res != null) { _lotController.text = res; _fetchData(); }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2, color: primaryColor),
                const SizedBox(width: 10),
                Expanded(child: Text(lotDetails!.itemName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(Icons.label_outline, "Code Article", lotDetails!.itemCode),
                _infoRow(Icons.tag, "Numero de palette / Lot", lotDetails!.distNumber),
                _infoRow(Icons.inventory, "Quantité (Cartons)", "${lotDetails!.qteCarton}"),
                const Divider(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _dateItem("Date Production", lotDetails!.mfrDate ?? "-"),
                    _dateItem("Date Expiration", lotDetails!.expDate ?? "-"),
                  ],
                ),
                const Divider(height: 30),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("TOTAL UNITÉS", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("${lotDetails!.totalQuantity}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _dateItem(String label, String date) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildActionButtons() {
    bool canTransfer = lotDetails != null && lotDetails!.totalQuantity > 0;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.block),
            onPressed: canTransfer ? () => _executerTransfert("QUARANTAINE") : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[900],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            label: const Text("QUARANTAINE"),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            onPressed: canTransfer ? () => _executerTransfert("LIBERER") : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[800],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            label: const Text("LIBÉRER"),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.qr_code_scanner, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("En attente de scan...", style: TextStyle(color: Colors.grey[400], fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: primaryColor),
            accountName: const Text("Utilisateur EMA", style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Text("Version 1.2.0"),
            currentAccountPicture: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40)),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text("Paramètres Magasins"),
            onTap: () { Navigator.pop(context); _showLoginDialog(); },
          ),
          const Spacer(),
          const Padding(padding: EdgeInsets.all(16), child: Text("© 2026 EMA ChocoScan", style: TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      ),
    );
  }

  // --- DIALOGS (CONCEPT CONSERVÉ) ---
  void _showLoginDialog() {
    final u = TextEditingController();
    final p = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Authentification Admin"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: u, decoration: const InputDecoration(labelText: "Utilisateur", icon: Icon(Icons.person))),
            TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: "Mot de passe", icon: Icon(Icons.lock))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () {
              if (u.text.trim() == "admin" && p.text.trim() == "Bp5@maroc") {
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

  void _showError(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
  void _showSuccess(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: Colors.green, behavior: SnackBarBehavior.floating));
}