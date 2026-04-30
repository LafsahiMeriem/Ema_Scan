import 'dart:convert'; // Important pour JSON
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sap_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SapService _sapService = SapService();

  // Cette liste sera maintenant chargée depuis le téléphone
  List<Map<String, String>> allWarehouses = [];

  String? whsSource;
  String? whsQuarantaine;
  String? whsLiberer;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  // 1. Charger tout au démarrage (Magasins + Choix sélectionnés)
  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();

    // Charger la liste des magasins sauvegardée
    String? savedWhsJson = prefs.getString('all_warehouses_list');

    setState(() {
      // Charger les 3 choix
      whsSource = prefs.getString('whsSource');
      whsQuarantaine = prefs.getString('whsQuarantaine');
      whsLiberer = prefs.getString('whsLiberer');

      // Si on a une liste sauvegardée, on la décode
      if (savedWhsJson != null) {
        List<dynamic> decoded = jsonDecode(savedWhsJson);
        allWarehouses = decoded.map((item) => Map<String, String>.from(item)).toList();
      }
    });
  }

  // 2. Récupérer depuis SAP ET Sauvegarder la liste entière
  Future<void> _getDataFromSap() async {
    setState(() => isLoading = true);

    final list = await _sapService.fetchAllWarehouses();

    if (list.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      // On transforme la liste en texte JSON pour la stocker
      String encodedList = jsonEncode(list);
      await prefs.setString('all_warehouses_list', encodedList);

      setState(() {
        allWarehouses = list;
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Liste des magasins mise à jour !"))
      );
    } else {
      setState(() => isLoading = false);
    }
  }

  // Sauvegarder un choix (Source, Quarantaine ou Libéré)
  Future<void> _saveSelection(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuration Magasins"),
        backgroundColor: Colors.blue[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildWhsDropdown("Magasin Source (Départ)", whsSource, (val) {
              setState(() => whsSource = val);
              _saveSelection('whsSource', val!);
            }),
            _buildWhsDropdown("Magasin Quarantaine", whsQuarantaine, (val) {
              setState(() => whsQuarantaine = val);
              _saveSelection('whsQuarantaine', val!);
            }),
            _buildWhsDropdown("Magasin Libéré", whsLiberer, (val) {
              setState(() => whsLiberer = val);
              _saveSelection('whsLiberer', val!);
            }),

            const Spacer(),

            if (isLoading) const CircularProgressIndicator(),

            const Text(
              "Note: Appuyez sur GET DATA seulement si vous avez ajouté de nouveaux magasins dans SAP.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),

            ElevatedButton.icon(
              onPressed: isLoading ? null : _getDataFromSap,
              icon: const Icon(Icons.sync),
              label: const Text("GET DATA (MAJ DEPUIS SAP)"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhsDropdown(String label, String? currentVal, Function(String?) onChange) {
    // Vérifier si la valeur actuelle existe toujours dans la liste
    bool valueExists = allWarehouses.any((w) => w['code'] == currentVal);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: DropdownButtonFormField<String>(
        value: valueExists ? currentVal : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        items: allWarehouses.map((w) => DropdownMenuItem(
          value: w['code'],
          child: Text("${w['code']} - ${w['name']}"),
        )).toList(),
        onChanged: onChange,
        hint: Text(currentVal ?? "Sélectionner un magasin"),
      ),
    );
  }
}