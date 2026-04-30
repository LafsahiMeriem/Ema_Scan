import 'package:flutter/material.dart';
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

  // Liste globale des magasins récupérée depuis SAP
  List<Map<String, String>> allWarehouses = [];

  @override
  void initState() {
    super.initState();
    _chargerMagasins();
  }

  // Charge les centaines de magasins une seule fois au démarrage
  Future<void> _chargerMagasins() async {
    final list = await _sapService.fetchAllWarehouses();
    if (mounted) {
      setState(() => allWarehouses = list);
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

    if (data == null) _showError("Lot introuvable ou erreur SAP.");
  }

  // Ouvre l'interface de recherche pour choisir le magasin
  Future<void> _selectionnerEtTransferer() async {
    if (allWarehouses.isEmpty) {
      await _chargerMagasins();
    }

    final selectedWhsCode = await showSearch<String>(
      context: context,
      delegate: WarehouseSearchDelegate(allWarehouses),
    );

    if (selectedWhsCode != null) {
      _executerTransfert(selectedWhsCode);
    }
  }

// Dans screens/home_screen.dart

  Future<void> _executerTransfert(String destinationWhs) async {
    setState(() => isLoading = true);

    // On récupère le résultat (soit null, soit le message d'erreur)
    String? errorMessage = await _sapService.createStockTransfer(
      itemCode: lotDetails!.itemCode,
      batchNumber: lotDetails!.distNumber,
      fromWhs: "ZPF-BC",
      toWhs: destinationWhs,
      quantity: 1.0,
    );

    setState(() => isLoading = false);

    if (errorMessage == null) {
      _showSuccess("Transfert réussi vers $destinationWhs");
      setState(() {
        lotDetails = null;
        _lotController.clear();
      });
    } else {
      // ON AFFICHE LE VRAI PROBLÈME SAP ICI
      _showError("Erreur SAP : $errorMessage");
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
                _detailRow("Code", lotDetails!.itemCode),
                _detailRow("Lot", lotDetails!.distNumber),
                _detailRow("Quantité", lotDetails!.qteCarton ?? "0"),
              ]),
              const SizedBox(height: 25),

              // BOUTON UNIQUE DE TRANSFERT AVEC RECHERCHE
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
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54)),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

// LOGIQUE DE RECHERCHE DYNAMIQUE (Pour des centaines de magasins)
class WarehouseSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, String>> warehouses;

  WarehouseSearchDelegate(this.warehouses);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, ''),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList();

  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final suggestions = warehouses.where((whs) {
      final input = query.toLowerCase();
      return whs['name']!.toLowerCase().contains(input) ||
          whs['code']!.toLowerCase().contains(input);
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.storefront),
          title: Text(suggestions[index]['name']!),
          subtitle: Text("Code: ${suggestions[index]['code']}"),
          onTap: () => close(context, suggestions[index]['code']!),
        );
      },
    );
  }
}