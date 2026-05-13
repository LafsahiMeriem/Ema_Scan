import 'package:flutter/material.dart';
import 'warehouse_lots_screen.dart'; // Importation indispensable pour la navigation

class WarehouseListScreen extends StatelessWidget {
  final List<Map<String, String>> warehouses;

  const WarehouseListScreen({super.key, required this.warehouses});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Fond gris clair pour faire ressortir les listes
      appBar: AppBar(
        title: const Text(
          "Suivi des Magasins SAP",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1), // Bleu cohérent avec EMA ChocoScan
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: warehouses.isEmpty
          ? _buildEmptyState()
          : ListView.separated(
        itemCount: warehouses.length,
        padding: const EdgeInsets.symmetric(vertical: 10),
        // Ajoute une ligne de séparation entre chaque magasin
        separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
        itemBuilder: (context, index) {
          final w = warehouses[index];
          final String code = w['code'] ?? "";
          final String name = w['name'] ?? "Inconnu";

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF0D47A1).withOpacity(0.1),
              child: const Icon(Icons.store, color: Color(0xFF0D47A1)),
            ),
            title: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              "Code: $code",
              style: TextStyle(color: Colors.grey[600]),
            ),
            // Flèche à droite pour indiquer que c'est cliquable
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),

            // --- NAVIGATION AU CLIC ---
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WarehouseLotsScreen(
                    whsCode: code,
                    whsName: name,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Widget affiché si la liste est vide
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Aucun magasin trouvé.\nVeuillez synchroniser les données dans les paramètres.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}