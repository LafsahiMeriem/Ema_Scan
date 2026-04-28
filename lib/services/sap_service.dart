import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/lot_info.dart';

// --- CETTE CLASSE DOIT RESTER ICI POUR LE BYPASS SSL ---
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class SapService {
  final String baseUrl = "https://EMA.bpsMaroc.com:50000/b1s/v1";
  String? sessionId;

  // 1. Connexion à SAP (Login)
  Future<bool> login() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/Login'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "CompanyDB": "test_Web",
          "UserName": "bps1",
          "Password": "1234"
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        sessionId = data['SessionId'];
        print("✅ Connexion réussie ! SessionId: $sessionId");
        return true;
      } else {
        print("❌ Échec de connexion : ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Erreur réseau : $e");
      return false;
    }
  }

  // 2. Récupération des données complètes du Lot
  Future<LotInfo?> fetchLotData(String scanCode) async {
    if (sessionId == null) await login();

    try {
      final String cleanCode = scanCode.trim();

      // On utilise 'Batch' pour le filtre
      final String url = "$baseUrl/BatchNumberDetails?\$filter=Batch eq '$cleanCode'";

      print("🔍 Envoi de la requête finale avec 'Batch'...");

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Cookie": "B1SESSION=$sessionId",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['value'] != null && data['value'].isNotEmpty) {
          print("✅ LOT TROUVÉ !");
          return LotInfo.fromJson(data['value'][0]);
        } else {
          print("⚠️ Le lot '$cleanCode' n'existe pas dans la table Batch (OBTN).");
        }
      } else {
        print("❌ Erreur SAP : ${response.body}");
      }
    } catch (e) {
      print("❌ Erreur critique : $e");
    }
    return null;
  }

  Future<LotInfo?> _fetchViaItemsSerial(String code) async {
    final String url = "$baseUrl/Items?\$filter=ItemSerialNumberCollection/any(s: s/InternalSerialNumber eq '$code')";
    print("🔍 Recherche via ItemSerialNumberCollection...");
    final response = await http.get(Uri.parse(url), headers: {"Cookie": "B1SESSION=$sessionId"});
    // ... logique similaire ...
    return null;
  }



// Petite fonction d'aide pour trouver le nom exact du champ dans OSRN
  Future<LotInfo?> _searchManualSerial(String code) async {
    final String url = "$baseUrl/SerialNumberDetails?\$top=20";
    final response = await http.get(Uri.parse(url), headers: {"Cookie": "B1SESSION=$sessionId"});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      for (var item in data['value']) {
        // On teste les noms de champs probables pour OSRN
        if (item['SerialNumber'] == code || item['InternalSerialNumber'] == code || item['SystemSerialNumber'] == code) {
          return LotInfo.fromJson(item);
        }
      }
    }
    return null;
  }
}