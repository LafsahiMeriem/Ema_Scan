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
          "UserName": "manager",
          "Password": "20@Y0ur20"
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

  // 2. Récupération dynamique de TOUS les magasins (Warehouses)
  // Cette méthode permet de gérer des centaines de magasins sans les coder en dur
// 2. Récupération dynamique de TOUS les magasins (Warehouses)
// Dans sap_service.dart

  Future<List<Map<String, String>>> fetchAllWarehouses() async {
    if (sessionId == null) await login();

    try {
      // Construction de l'URL avec des paramètres explicites
      final uri = Uri.parse('$baseUrl/Warehouses').replace(queryParameters: {
        '\$select': 'WarehouseCode,WarehouseName',
        '\$filter': 'Inactive eq \'tNO\'',
        '\$top': '100', // On force 100 ici
      });

      print("🌐 Appel URL : $uri");

      final response = await http.get(
        uri,
        headers: {
          "Cookie": "B1SESSION=$sessionId",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, String>> whsList = [];

        if (data['value'] != null) {
          for (var item in data['value']) {
            whsList.add({
              'code': item['WarehouseCode'].toString(),
              'name': item['WarehouseName'].toString(),
            });
          }
        }
        print("✅ ${whsList.length} magasins récupérés réellement.");
        return whsList;
      } else {
        print("❌ Erreur SAP Warehouses: ${response.body}");
      }
    } catch (e) {
      print("❌ Erreur de chargement des magasins : $e");
    }
    return [];
  }
  // 3. Récupération des données du Lot via BatchNumberDetails
  Future<LotInfo?> fetchLotData(String scanCode) async {
    if (sessionId == null) await login();

    try {
      final String cleanCode = scanCode.trim();
      final String url = "$baseUrl/BatchNumberDetails?\$filter=Batch eq '$cleanCode'";

      print("🔍 Recherche du lot : $cleanCode");

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
          print("✅ Lot trouvé !");
          print("DEBUG DATA: ${data['value'][0]}");
          return LotInfo.fromJson(data['value'][0]);
        } else {
          print("⚠️ Le lot '$cleanCode' n'existe pas.");
        }
      } else {
        print("❌ Erreur SAP : ${response.body}");
      }
    } catch (e) {
      print("❌ Erreur critique fetchLotData : $e");
    }
    return null;
  }

  // 4. Création du transfert de stock (StockTransfer)
// Dans services/sap_service.dart

  Future<String?> createStockTransfer({
    required String itemCode,
    required String batchNumber,
    required String fromWhs,
    required String toWhs,
    required double quantity,
  }) async {
    if (sessionId == null) await login();

    // Nettoyage radical du numéro de lot pour éviter les erreurs de caractères
    final String cleanBatch = batchNumber.trim();

    await lierArticleAuMagasin(itemCode, toWhs);

    try {
      final Map<String, dynamic> body = {
        "DocDate": DateTime.now().toIso8601String().split('T')[0],
        "FromWarehouse": fromWhs,
        "ToWarehouse": toWhs,
        "StockTransferLines": [
          {
            "ItemCode": itemCode,
            "Quantity": quantity,
            "FromWarehouseCode": fromWhs,
            "WarehouseCode": toWhs,
            "BatchNumbers": [
              {
                "BatchNumber": cleanBatch, // Utilisation du lot nettoyé
                "Quantity": quantity,
                // "BaseLineNumber": 0 // Optionnel, SAP le gère souvent seul
              }
            ]
          }
        ]
      };

      print("🚀 Tentative de transfert : $itemCode | Lot: $cleanBatch | Qte: $quantity");

      final response = await http.post(
        Uri.parse('$baseUrl/StockTransfers'),
        headers: {
          "Cookie": "B1SESSION=$sessionId",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return null;
      } else {
        final errorData = jsonDecode(response.body);
        String msg = errorData['error']['message']['value'] ?? "Erreur inconnue";

        // Aide au diagnostic si l'erreur persiste
        if (msg.contains("-5002")) {
          return "Le lot [$cleanBatch] n'est pas disponible dans le magasin $fromWhs (Erreur 131-183).";
        }
        return msg;
      }
    } catch (e) {
      return "Erreur réseau : $e";
    }
  }
  // --- Méthodes de secours (Optionnelles) ---

  Future<LotInfo?> _fetchViaItemsSerial(String code) async {
    final String url = "$baseUrl/Items?\$filter=ItemSerialNumberCollection/any(s: s/InternalSerialNumber eq '$code')";
    final response = await http.get(Uri.parse(url), headers: {"Cookie": "B1SESSION=$sessionId"});
    return null;
  }


  Future<bool> lierArticleAuMagasin(String itemCode, String toWhs) async {
    if (sessionId == null) await login();

    try {
      // On met à jour l'objet Items via un PATCH
      final response = await http.patch(
        Uri.parse('$baseUrl/Items(\'$itemCode\')'),
        headers: {
          "Cookie": "B1SESSION=$sessionId",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "ItemWarehouseInfoCollection": [
            {
              "WarehouseCode": toWhs
            }
          ]
        }),
      );

      // SAP retourne 204 No Content en cas de succès pour un PATCH
      if (response.statusCode == 204 || response.statusCode == 200) {
        print("✅ Article $itemCode lié au magasin $toWhs");
        return true;
      } else {
        print("❌ Erreur liaison article : ${response.body}");
        return false;
      }
    } catch (e) {
      return false;
    }
  }


  Future<LotInfo?> _searchManualSerial(String code) async {
    final String url = "$baseUrl/SerialNumberDetails?\$top=20";
    final response = await http.get(Uri.parse(url), headers: {"Cookie": "B1SESSION=$sessionId"});
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      for (var item in data['value']) {
        if (item['SerialNumber'] == code || item['InternalSerialNumber'] == code || item['SystemSerialNumber'] == code) {
          return LotInfo.fromJson(item);
        }
      }
    }
    return null;
  }
}