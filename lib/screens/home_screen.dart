import 'dart:convert';
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

  // Palette Premium (Slate & Indigo Deep)
  final Color primaryDark = const Color(0xFF0F172A);
  final Color accentIndigo = const Color(0xFF6366F1);
  final Color surfaceLight = const Color(0xFFF8FAFC);
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _cartonController = TextEditingController();

  // Variables pour la gestion dynamique des magasins SAP
  String? _selectedWarehouse;
  List<Map<String, String>> _magasinsList = [];
  bool _isLoadingWarehouses = false;

  @override
  void initState() {
    super.initState();
    _loadSapWarehouses(); // Chargement des magasins dès l'ouverture
  }

  Future<void> _loadSapWarehouses() async {
    setState(() => _isLoadingWarehouses = true);
    try {
      final whs = await _sapService.fetchAllWarehouses();
      if (mounted) {
        setState(() {
          _magasinsList = whs;
          _isLoadingWarehouses = false;
        });
      }
    } catch (e) {
      print("❌ Erreur chargement magasins : $e");
      if (mounted) setState(() => _isLoadingWarehouses = false);
    }
  }

  Future<void> _executerTransfert(String type) async {
    if (lotDetails == null) return;

    final double qteSaisie = double.tryParse(_quantityController.text) ?? 0;
    if (qteSaisie <= 0) {
      _showStatusSnackBar("Veuillez saisir une quantité valide.", isError: true);
      return;
    }

    _setLoading(true);

    try {
      final prefs = await SharedPreferences.getInstance();
      String? sourceWhs;
      String? targetWhs;

      if (type == "QUARANTAINE") {
        sourceWhs = prefs.getString('whsSource');
        targetWhs = prefs.getString('whsQuarantaine');
      } else if (type == "LIBERER") {
        sourceWhs = prefs.getString('whsSourceNonConforme');
        targetWhs = prefs.getString('whsLiberer');
      }

      // Si l'utilisateur a sélectionné un magasin dans le ComboBox, il devient prioritaire
      if (_selectedWarehouse != null) {
        targetWhs = _selectedWarehouse;
      }

      if (sourceWhs == null || targetWhs == null) {
        _showStatusSnackBar("Configuration des magasins incomplète.", isError: true);
        _setLoading(false);
        return;
      }

      if (sourceWhs.trim().toUpperCase() == targetWhs.trim().toUpperCase()) {
        _showStatusSnackBar("Erreur : Le magasin de départ ($sourceWhs) et d'arrivée ($targetWhs) sont identiques.", isError: true);
        _setLoading(false);
        return;
      }

      print("🚀 Envoi SAP -> Transfert de $sourceWhs vers $targetWhs (Qté: $qteSaisie)");

      String? error = await _sapService.createStockTransfer(
        itemCode: lotDetails!.itemCode,
        batchNumber: lotDetails!.distNumber,
        fromWhs: sourceWhs,
        toWhs: targetWhs,
        quantity: qteSaisie,
      );

      _setLoading(false);

      if (error == null) {
        _showStatusSnackBar("✅ Transfert réussi de $sourceWhs vers $targetWhs !");
        setState(() {
          lotDetails = null;
          _selectedWarehouse = null; // Réinitialisation après succès
          _lotController.clear();
          _quantityController.clear();
          _cartonController.clear();
        });
      } else {
        _showStatusSnackBar("❌ Erreur SAP : $error", isError: true);
      }
    } catch (e) {
      _setLoading(false);
      _showStatusSnackBar("❌ Erreur système : $e", isError: true);
    }
  }

  void _setLoading(bool value) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => isLoading = value);
    });
  }

  @override
  void dispose() {
    _lotController.dispose();
    _quantityController.dispose();
    _cartonController.dispose();
    super.dispose();
  }

  void _fetchData() async {
    if (_lotController.text.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => isLoading = true);
    });

    final data = await _sapService.fetchLotData(_lotController.text);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          lotDetails = data;
          isLoading = false;
          if (data != null) {
            _quantityController.text = data.totalQuantity.toString();
            _cartonController.text = data.qteCarton.toString();
          }
        });
        if (data == null) {
          _showStatusSnackBar("Aucun lot correspondant trouvé avec du stock disponible.", isError: true);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceLight,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('EMA CHOCOSCAN',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildPremiumHeader(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  // ✨ Modification ici : Le ComboBox s'affiche maintenant TOUJOURS en haut de la zone de contenu
  Widget _buildContent() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: accentIndigo, strokeWidth: 2));
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        children: [
          // 1. Le menu déroulant s'affiche en premier, avant le scan du lot
          _buildWarehouseDropdown(),

          const SizedBox(height: 25),

          // 2. Affichage conditionnel selon si un lot est chargé ou non
          if (lotDetails != null) ...[
            _buildMainInfoCard(),
            const SizedBox(height: 30),
            _buildActionButtons(),
          ] else ...[
            // Si aucun lot n'est encore scanné, on affiche la zone d'attente (Empty State)
            _buildEmptyState(),
          ],
        ],
      ),
    );
  }

  // ✨ Ajustement visuel : Le fond passe en blanc pur avec une ombre pour bien se détacher du fond gris clair
  Widget _buildWarehouseDropdown() {
    if (_isLoadingWarehouses) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(10.0),
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: primaryDark.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8)
          )
        ],
        border: Border.all(color: accentIndigo.withOpacity(0.15), width: 1.2),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedWarehouse,
        hint: Text(
          "Sélectionner le magasin de destination",
          style: TextStyle(color: primaryDark.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w500),
        ),
        icon: Icon(Icons.arrow_drop_down_rounded, color: accentIndigo, size: 30),
        decoration: const InputDecoration(border: InputBorder.none),
        dropdownColor: Colors.white,
        isExpanded: true,
        style: TextStyle(color: primaryDark, fontWeight: FontWeight.bold, fontSize: 13),
        items: _magasinsList.map((whs) {
          return DropdownMenuItem<String>(
            value: whs['code'],
            child: Text("[${whs['code']}] ${whs['name']}"),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedWarehouse = value;
          });
        },
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryDark, const Color(0xFF1E293B)],
        ),
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Gestion des Flux", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text("Identification Lot", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 25),
          _buildSearchBox(),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: TextField(
        controller: _lotController,
        onSubmitted: (_) => _fetchData(),
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: "Saisir ou scanner un lot...",
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.normal),
          prefixIcon: const Icon(Icons.search_rounded, color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
          suffixIcon: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: accentIndigo, borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white, size: 20),
            ),
            onPressed: () async {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
              if (res != null) {
                _lotController.text = res;
                setState(() {
                  lotDetails = null;
                });
                _fetchData();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMainInfoCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: primaryDark.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          _buildCardHeader(),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _infoTile(Icons.api_rounded, "REFERENCE ARTICLE", lotDetails!.itemCode),
                _infoTile(Icons.layers_rounded, "IDENTIFIANT LOT", lotDetails!.distNumber),
                const SizedBox(height: 15),
                _buildCartonInputField(),
                const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(color: Color(0xFFF1F5F9))),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _dateBlock("FABRICATION", _formaterDate(lotDetails!.mfrDate)),
                    _dateBlock("EXPIRATION", _formaterDate(lotDetails!.expDate)),
                  ],
                ),
                const SizedBox(height: 25),
                _buildQuantityDisplay(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartonInputField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentIndigo.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("CONDITIONNEMENT (CARTONS)", style: TextStyle(color: accentIndigo, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text("Modifier le nombre", style: TextStyle(color: primaryDark.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: TextFormField(
              controller: _cartonController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primaryDark),
              decoration: const InputDecoration(border: InputBorder.none, hintText: "0", contentPadding: EdgeInsets.zero),
              onChanged: (val) {
                if (lotDetails == null) return;
                final double? nouveauxCartons = double.tryParse(val);
                if (nouveauxCartons != null && nouveauxCartons >= 0) {
                  double ratioInitial = (lotDetails!.qteCarton > 0) ? lotDetails!.qteCarton : 1.0;
                  double tailleUnitaireCarton = lotDetails!.totalQuantity / ratioInitial;
                  double nouvelleQuantite = nouveauxCartons * tailleUnitaireCarton;

                  if (nouvelleQuantite > lotDetails!.totalQuantity) {
                    _showStatusSnackBar("Avertissement : Quantité supérieure au stock initial.", isError: false);
                  }
                  setState(() {
                    _quantityController.text = nouvelleQuantite.toStringAsFixed(2);
                  });
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: accentIndigo.withOpacity(0.08),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Row(
        children: [
          CircleAvatar(backgroundColor: accentIndigo, radius: 18, child: const Icon(Icons.shopping_bag_rounded, size: 18, color: Colors.white)),
          const SizedBox(width: 12),
          Expanded(child: Text(lotDetails!.itemName.toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: primaryDark, letterSpacing: 0.5))),
        ],
      ),
    );
  }

  Widget _buildQuantityDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: primaryDark,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: accentIndigo.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("QUANTITÉ CALCULÉE (KG/UT)", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
              SizedBox(height: 4),
              Text("Mise à jour auto", style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: TextFormField(
              controller: _quantityController,
              enabled: false,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
              decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.zero, disabledBorder: InputBorder.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accentIndigo.withOpacity(0.5)),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 1)),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: primaryDark, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateBlock(String label, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: surfaceLight, borderRadius: BorderRadius.circular(8)),
          child: Text(date, style: TextStyle(fontWeight: FontWeight.bold, color: primaryDark, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    bool canTransfer = lotDetails != null && lotDetails!.totalQuantity > 0;
    return Row(
      children: [
        Expanded(child: _actionBtn("QUARANTAINE", const Color(0xFFF97316), Icons.shield_outlined,
            canTransfer ? () => _executerTransfert("QUARANTAINE") : null)),
        const SizedBox(width: 15),
        Expanded(child: _actionBtn("LIBÉRER", const Color(0xFF10B981), Icons.verified_user_outlined,
            canTransfer ? () => _executerTransfert("LIBERER") : null)),
      ],
    );
  }

  Widget _actionBtn(String label, Color color, IconData icon, VoidCallback? onTap) {
    return Material(
      color: onTap == null ? Colors.grey[200] : color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Icon(icon, color: onTap == null ? Colors.grey[400] : Colors.white),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: onTap == null ? Colors.grey[500] : Colors.white, fontWeight: FontWeight.w900, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryDark.withOpacity(0.05), blurRadius: 20)]),
            child: Icon(Icons.document_scanner_outlined, size: 60, color: accentIndigo.withOpacity(0.2)),
          ),
          const SizedBox(height: 25),
          Text("Système prêt pour analyse", style: TextStyle(color: primaryDark, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text("Veuillez scanner un lot SAP pour commencer", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            height: 200,
            width: double.infinity,
            color: primaryDark,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(backgroundColor: Colors.white24, radius: 30, child: Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 30)),
                const SizedBox(height: 15),
                const Text("Administrateur EMA", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text("v1.2.0 stable", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _drawerItem(Icons.settings_suggest_rounded, "Paramètres Système", () {
            Navigator.pop(context);
            _showLoginDialog();
          }),
          const Spacer(),
          const Padding(padding: EdgeInsets.all(20), child: Text("LOGISTIC EXPERT MODE", style: TextStyle(letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey))),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: primaryDark),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: primaryDark)),
      onTap: onTap,
    );
  }

  void _showStatusSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? Colors.redAccent : accentIndigo,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.all(15),
    ));
  }

  void _showLoginDialog() {
    final u = TextEditingController();
    final p = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Authentification Requis", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: u, decoration: const InputDecoration(labelText: "Utilisateur")),
            const SizedBox(height: 10),
            TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: "Clé d'accès")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              if (u.text.trim() == "admin" && p.text.trim() == "Bp5@maroc") {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
              } else { _showStatusSnackBar("Accès refusé : Identifiants invalides", isError: true); }
            },
            child: const Text("Vérifier", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formaterDate(String? dateSap) {
    if (dateSap == null || dateSap.isEmpty || dateSap == "--/--/--") {
      return "--/--/--";
    }
    try {
      if (dateSap.contains('-')) {
        List<String> parts = dateSap.split('-');
        if (parts.length == 3) {
          String annee = parts[0];
          String mois = parts[1];
          String jour = parts[2];
          return "$jour-$mois-$annee";
        }
      }
    } catch (e) {
      return dateSap;
    }
    return dateSap;
  }
}