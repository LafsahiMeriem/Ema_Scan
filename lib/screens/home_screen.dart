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
        // 🔄 ÉTAPE 1 : On part du magasin source principal vers la quarantaine
        sourceWhs = prefs.getString('whsSource');           // 'ZPF-BC'
        targetWhs = prefs.getString('whsQuarantaine');      // 'MANQ MP'
      } else if (type == "LIBERER") {
        // 🔄 ÉTAPE 2 : On part du magasin de quarantaine vers le magasin libéré
        sourceWhs = prefs.getString('whsSourceNonConforme');// 'MANQ MP' (destination du 1er scan)
        targetWhs = prefs.getString('whsLiberer');          // 'APPOLO'
      }

      if (sourceWhs == null || targetWhs == null) {
        _showStatusSnackBar("Configuration des magasins incomplète dans les réglages.", isError: true);
        _setLoading(false);
        return;
      }

      // Sécurité anti-boucle : évite l'erreur SAP 125000017
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
        quantity: qteSaisie, // Prend en compte la valeur modifiée à l'écran
      );

      _setLoading(false);

      if (error == null) {
        _showStatusSnackBar("✅ Transfert réussi de $sourceWhs vers $targetWhs !");
        setState(() {
          lotDetails = null;
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
    _quantityController.dispose(); // Ne pas oublier de le libérer
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
            // ✨ On affiche la valeur initiale des cartons reçue de SAP
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

  Widget _buildContent() {
    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: accentIndigo, strokeWidth: 2));
    }
    if (lotDetails != null) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
        child: Column(
          children: [
            _buildMainInfoCard(),
            const SizedBox(height: 30),
            _buildActionButtons(),
          ],
        ),
      );
    }
    return _buildEmptyState();
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

                _fetchData(); }
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
                // ✨ ÉTAPE MULTI-SCAN : Zone de modification du conditionnement (Cartons)
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
                _buildQuantityDisplay(), // Affichera la quantité automatiquement calculée
              ],
            ),
          ),
        ],
      ),
    );
  }

// ✨ Nouveau Widget : Saisie du nombre de cartons avec calcul auto de la quantité
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
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "0",
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) {
                if (lotDetails == null) return;

                final double? nouveauxCartons = double.tryParse(val);
                if (nouveauxCartons != null && nouveauxCartons >= 0) {
                  // 🧮 RÈGLE : Calcul de la taille unitaire d'un carton (Ex: 7200 kg / 40 cartons = 180 kg par carton)
                  // Si la valeur initiale de qteCarton est à 0, on sécurise pour éviter la division par zéro.
                  double ratioInitial = (lotDetails!.qteCarton > 0) ? lotDetails!.qteCarton : 1.0;
                  double tailleUnitaireCarton = lotDetails!.totalQuantity / ratioInitial;

                  // Calcul de la nouvelle quantité théorique
                  double nouvelleQuantite = nouveauxCartons * tailleUnitaireCarton;

                  // Optionnel : Limitation au stock disponible SAP maximum pour éviter les erreurs de flux
                  if (nouvelleQuantite > lotDetails!.totalQuantity) {
                    _showStatusSnackBar("Avertissement : Quantité supérieure au stock initial.", isError: false);
                  }

                  setState(() {
                    // Met à jour dynamiquement le champ de quantité à l'écran
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
              enabled: false, // 🔒 Verrouillé car calculé automatiquement par le nombre de cartons
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                disabledBorder: InputBorder.none, // Supprime la ligne de désactivation
              ),
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
          /* _drawerItem(Icons.warehouse_rounded, "Inventaire Global", () {
            Navigator.pop(context);
          //  Navigator.push(context, MaterialPageRoute(builder: (_) => const WarehouseLotsScreen(whsCode: "GLOBAL", whsName: "Stock Global")));
          }),

          */
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
