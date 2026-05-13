import 'package:flutter/material.dart';
import '../services/sap_service.dart';

class WarehouseLotsScreen extends StatefulWidget {
  final String whsCode;
  final String whsName;

  const WarehouseLotsScreen({super.key, required this.whsCode, required this.whsName});

  @override
  State<WarehouseLotsScreen> createState() => _WarehouseLotsScreenState();
}

class _WarehouseLotsScreenState extends State<WarehouseLotsScreen> {
  final SapService _sapService = SapService();
  List<Map<String, dynamic>> lots = [];
  bool isLoading = true;

  // Couleurs du thème EMA
  final Color primaryColor = const Color(0xFF0D47A1);

  @override
  void initState() {
    super.initState();
    _loadLots();
  }

  void _loadLots() async {
    setState(() => isLoading = true);
    // Appel à votre service SAP pour récupérer les stocks du magasin
    final data = await _sapService.fetchLotsByWarehouse(widget.whsCode);
    setState(() {
      lots = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Lots : ${widget.whsCode}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(widget.whsName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLots,
          )
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : lots.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        itemCount: lots.length,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        itemBuilder: (context, index) {
          final lot = lots[index];
          return _buildLotCard(lot);
        },
      ),
    );
  }

  Widget _buildLotCard(Map<String, dynamic> lot) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.03),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)),
            ),
            child: Row(
              children: [
                Icon(Icons.inventory_2, size: 20, color: primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "${lot['itemName']}",
                    style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                _buildInfoRow(Icons.qr_code, "Code Article", "${lot['itemCode']}"),
                _buildInfoRow(Icons.layers, "N° Lot / Palette", "${lot['distNumber']}"),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDateColumn("Production", "${lot['mfrDate'] ?? '-'}"),
                    _buildDateColumn("Expiration", "${lot['expDate'] ?? '-'}"),
                    _buildQuantityBadge("${lot['quantity']}"),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDateColumn(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(date, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildQuantityBadge(String quantity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          const Text("TOTAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue)),
          Text(
            quantity,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Aucun lot disponible", style: TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}