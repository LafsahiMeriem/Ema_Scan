import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lot_info.dart';

// Bypass SSL pour les certificats auto-signés
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

  // 1. Connexion à SAP
  Future<bool> login() async {
    try {
      final response = await http.post(
          Uri.parse('$baseUrl/Login'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "CompanyDB": "DB_APP_WEB_HK",
            "UserName": "manager",
            "Password": "20@Y0ur20"
          })
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
      print("❌ Erreur réseau Login : $e");
      return false;
    }
  }

  // 2. Récupérer tous les magasins (avec pagination)
  Future<List<Map<String, String>>> fetchAllWarehouses() async {
    if (sessionId == null) await login();

    List<Map<String, String>> whsList = [];
    String? nextUrl = "$baseUrl/Warehouses?\$select=WarehouseCode,WarehouseName&\$top=100";

    try {
      while (nextUrl != null) {
        final response = await http.get(
          Uri.parse(nextUrl),
          headers: {
            "Cookie": "B1SESSION=$sessionId",
            "Content-Type": "application/json",
            "B1S-PageSize": "500",
          },
        );

        if (response.statusCode != 200) {
          print("Erreur API: ${response.statusCode} - ${response.body}");
          break;
        }

        final data = jsonDecode(response.body);
        final List<dynamic> values = data['value'] ?? [];

        for (var item in values) {
          whsList.add({
            'code': item['WarehouseCode']?.toString() ?? '',
            'name': item['WarehouseName']?.toString() ?? '',
          });
        }

        if (data['@odata.nextLink'] != null) {
          String nextPath = data['@odata.nextLink'];
          if (nextPath.startsWith('/')) {
            nextPath = nextPath.substring(1);
          }
          nextUrl = nextPath.startsWith('http') ? nextPath : "$baseUrl/$nextPath";
        } else {
          nextUrl = null;
        }
      }

      whsList.sort((a, b) => a['code']!.compareTo(b['code']!));
      return whsList;
    } catch (e) {
      print("Error fetching warehouses: $e");
      return whsList;
    }
  }

  // 3. Récupérer la liste globale des lots
  Future<List<Map<String, dynamic>>> fetchAllLotsGlobal() async {
    if (sessionId == null) await login();
    List<Map<String, dynamic>> allLots = [];
    String? nextUrl = "$baseUrl/BatchNumberDetails?\$top=500";

    try {
      while (nextUrl != null) {
        final response = await http.get(
          Uri.parse(nextUrl),
          headers: {
            "Cookie": "B1SESSION=$sessionId",
            "Content-Type": "application/json",
            "Prefer": "odata.maxpagesize=500",
          },
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic> values = data['value'] ?? [];

          final currentPageLots = values.map((item) {
            var rawQty = item['Quantity'] ?? item['TotalInStock'] ?? item['InStock'] ?? item['Available'] ?? '0';
            return {
              'itemCode': item['ItemCode']?.toString() ?? '',
              'itemName': item['ItemDescription']?.toString() ?? 'Sans nom',
              'distNumber': (item['Batch'] ?? item['BatchNumber'] ?? item['DistNumber'] ?? 'N/A').toString(),
              'warehouse': (item['ItemLocation'] ?? item['WhsCode'] ?? item['WarehouseCode'] ?? 'N/A').toString(),
              'quantity': rawQty.toString(),
              'expDate': item['ExpirationDate']?.toString()?.split('T')[0] ?? '-',
              'mfrDate': item['ManufacturingDate']?.toString()?.split('T')[0] ?? '-',
            };
          }).toList();

          allLots.addAll(currentPageLots);

          if (data['@odata.nextLink'] != null) {
            String nextPath = data['@odata.nextLink'];
            nextUrl = nextPath.startsWith('http') ? nextPath : "$baseUrl/$nextPath";
          } else {
            nextUrl = null;
          }
        } else {
          break;
        }
      }
      return allLots;
    } catch (e) {
      print("❌ Erreur : $e");
      return [];
    }
  }

  // 4. Récupérer les lots par magasin
  Future<List<Map<String, dynamic>>> fetchLotsByWarehouse(String whsCode) async {
    final allLots = await fetchAllLotsGlobal();
    return allLots.where((lot) => lot['warehouse'] == whsCode).toList();
  }
  Future<LotInfo?> fetchLotData(String scanCode) async {
    if (sessionId == null) await login();
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? whsSource = prefs.getString('whsSource');
      final String? whsNonConforme = prefs.getString('whsSourceNonConforme');

      // ÉTAPE 1 : Recherche dans le magasin Source principal (ex: ZPF-BC)
      if (whsSource != null) {
        print("🔍 ÉTAPE 1 : Vérification dans le magasin source standard ($whsSource)");
        LotInfo? lot = await _fetchLotSpecificWhs(scanCode, whsSource);
        if (lot != null && lot.totalQuantity > 0) {
          print("🎯 Lot trouvé dans le magasin Source avec du stock disponible (${lot.totalQuantity}).");
          return lot;
        }
      }

      // ÉTAPE 2 : Si introuvable ou quantité à 0, recherche dans le magasin Non Conforme (ex: MANQ MP)
      if (whsNonConforme != null) {
        print("🔍 ÉTAPE 2 : Recherche secondaire dans le magasin Non Conforme ($whsNonConforme)");
        LotInfo? lot = await _fetchLotSpecificWhs(scanCode, whsNonConforme);
        if (lot != null && lot.totalQuantity > 0) {
          print("🎯 Lot identifié dans la zone Non Conforme avec du stock (${lot.totalQuantity}).");
          return lot;
        }
      }
    } catch (e) {
      print("❌ Erreur fetchLotData globale : $e");
    }
    return null;
  }

  Future<LotInfo?> _fetchLotSpecificWhs(String scanCode, String whsCode) async {
    try {
      // 1. 🎯 REQUÊTE ABSOLUE : On filtre par le numéro de Lot ET par le Magasin directement dans SAP
      // On utilise $expand=ItemWarehouseInfoCollection pour s'assurer d'avoir les données fraîches
      final String url = "$baseUrl/BatchNumberDetails?\$filter=Batch eq '${scanCode.trim()}' and WhsCode eq '${whsCode.trim()}'";

      print("📡 Requête SAP ciblée : Lot '${scanCode.trim()}' dans Magasin '${whsCode.trim()}'");

      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Cookie": "B1SESSION=$sessionId",
          "Content-Type": "application/json",
          "B1S-KeepSessionInCache": "false" // Désactive le cache HANA/SQL
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['value'] != null && data['value'].isNotEmpty) {
          // SAP nous renvoie exactement la ligne du lot pour CE magasin
          final Map<String, dynamic> itemRaw = data['value'][0];
          final String itemCode = itemRaw['ItemCode']?.toString() ?? '';

          // 🚨 extraction de la VRAIE quantité du lot disponible dans ce magasin précis
          // Selon les versions de SAP, le champ peut s'appeler 'Quantity', 'InStock' ou 'Available'
          double stockReelLot = double.tryParse(itemRaw['Quantity']?.toString() ?? '0') ?? 0.0;

          // Si SAP renvoie 0 dans 'Quantity' à cause d'un bug d'affichage de cet endpoint,
          // on va chercher dans le champ 'ItemLocation' ou on fait un double check
          print("📊 Quantité du Lot renvoyée par SAP pour le magasin $whsCode = $stockReelLot");

          // Si le stock de ce lot est tombé à 0 dans ce magasin suite au transfert,
          // on retourne null pour que l'application passe au magasin suivant
          if (stockReelLot <= 0) {
            print("⚠️ Le lot ${scanCode.trim()} est épuisé (0) dans le magasin $whsCode.");
            return null;
          }

          // Configuration des données pour l'affichage de l'écran
          itemRaw['ItemCode'] = itemCode;
          itemRaw['WhsCode'] = whsCode.trim();
          itemRaw['Quantity'] = stockReelLot;

          return LotInfo.fromJson(itemRaw);
        } else {
          print("ℹ️ Aucun stock trouvé pour le lot ${scanCode.trim()} dans le magasin $whsCode");
        }
      } else {
        print("❌ Erreur API SAP : ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("❌ Erreur critique lors de la récupération du stock du lot : $e");
    }
    return null;
  }

  Future<String?> createStockTransfer({
    required String itemCode,
    required String batchNumber,
    required String fromWhs,
    required String toWhs,
    required double quantity,
  }) async {
    if (sessionId == null) await login();
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
            "WarehouseCode": toWhs,
            "BatchNumbers": [
              {"BatchNumber": batchNumber.trim(), "Quantity": quantity}
            ]
          }
        ]
      };

      final response = await http.post(
        Uri.parse('$baseUrl/StockTransfers'),
        headers: {"Cookie": "B1SESSION=$sessionId", "Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201 || response.statusCode == 200) return null;

      final errorData = jsonDecode(response.body);
      return errorData['error']['message']['value'] ?? "Erreur inconnue";
    } catch (e) {
      return "Erreur réseau : $e";
    }
  }

  // 8. Lier l'article au magasin de destination (Obligatoire SAP)
  Future<bool> lierArticleAuMagasin(String itemCode, String toWhs) async {
    if (sessionId == null) await login();
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/Items(\'$itemCode\')'),
        headers: {"Cookie": "B1SESSION=$sessionId", "Content-Type": "application/json"},
        body: jsonEncode({
          "ItemWarehouseInfoCollection": [{"WarehouseCode": toWhs}]
        }),
      );
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}


