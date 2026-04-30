import 'dart:convert';
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

  // Charge les magasins et les sélections précédentes au démarrage
  Future<void> _loadAllData() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedWhsJson = prefs.getString('all_warehouses_list');

    setState(() {
      whsSource = prefs.getString('whsSource');
      whsQuarantaine = prefs.getString('whsQuarantaine');
      whsLiberer = prefs.getString('whsLiberer');

      if (savedWhsJson != null) {
        List<dynamic> decoded = jsonDecode(savedWhsJson);
        allWarehouses = decoded.map((item) => Map<String, String>.from(item)).toList();
      }
    });
  }

  Future<void> _getDataFromSap() async {
    setState(() => isLoading = true);
    final list = await _sapService.fetchAllWarehouses();

    if (list.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('all_warehouses_list', jsonEncode(list));
      setState(() {
        allWarehouses = list;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

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
        foregroundColor: Colors.white,
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
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: isLoading ? null : _getDataFromSap,
              icon: const Icon(Icons.sync),
              label: const Text("GET DATA (MAJ DEPUIS SAP)"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhsDropdown(String label, String? currentVal, Function(String?) onChange) {
    // Vérification si la valeur existe dans la liste actuelle
    bool valueExists = allWarehouses.any((w) => w['code'] == currentVal);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: DropdownButtonFormField<String>(
        isExpanded: true, // RÉPARE L'OVERFLOW : permet au contenu de prendre toute la largeur
        value: valueExists ? currentVal : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.bold),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.blue.withOpacity(0.05),
        ),
        // Style du texte sélectionné pour éviter l'overflow
        selectedItemBuilder: (BuildContext context) {
          return allWarehouses.map<Widget>((Map<String, String> item) {
            return Text(
              "${item['code']} - ${item['name']}",
              overflow: TextOverflow.ellipsis, // Coupe le texte avec "..." s'il est trop long
              maxLines: 1,
            );
          }).toList();
        },
        items: allWarehouses.map((w) => DropdownMenuItem(
          value: w['code'],
          child: Text(
            "${w['code']} - ${w['name']}",
            style: const TextStyle(fontSize: 13), // Texte un peu plus petit pour le menu
          ),
        )).toList(),
        onChanged: onChange,
        hint: Text(currentVal ?? "Sélectionner un magasin"),
      ),
    );
  }
}