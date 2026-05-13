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



  Future<List<Map<String, String>>> fetchAllWarehouses() async {
    if (sessionId == null) await login();

    List<Map<String, String>> whsList = [];
    // On commence avec l'URL initiale (on filtre les actifs et on demande 100 par page)
    String? nextUrl = "$baseUrl/Warehouses?\$select=WarehouseCode,WarehouseName&\$filter=Inactive eq 'tNO'&\$top=100";

    try {
      // Tant qu'il y a une URL suivante, on continue de charger
      while (nextUrl != null) {
        final response = await http.get(
          Uri.parse(nextUrl),
          headers: {
            "Cookie": "B1SESSION=$sessionId",
            "Content-Type": "application/json",
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final List<dynamic>? values = data['value'];

          if (values != null) {
            for (var item in values) {
              whsList.add({
                'code': item['WarehouseCode']?.toString() ?? '',
                'name': item['WarehouseName']?.toString() ?? '',
              });
            }
          }

          // --- C'EST ICI QUE ÇA SE JOUE ---
          // On vérifie si SAP nous donne un lien vers la page suivante
          if (data['@odata.nextLink'] != null) {
            // Le lien suivant est souvent relatif ou complet, on le reconstruit si besoin
            String nextPath = data['@odata.nextLink'];
            if (nextPath.startsWith('http')) {
              nextUrl = nextPath;
            } else {
              nextUrl = "$baseUrl/$nextPath";
            }
          } else {
            nextUrl = null; // Plus de pages, on arrête la boucle
          }
        } else {
          print("❌ Erreur SAP : ${response.body}");
          break;
        }
      }

      // Tri final pour le confort de l'utilisateur
      whsList.sort((a, b) => a['code']!.compareTo(b['code']!));
      return whsList;

    } catch (e) {
      print("❌ Exception lors du chargement total : $e");
      return whsList;
    }
  }


  Future<List<Map<String, dynamic>>> fetchLotsByWarehouse(String whsCode) async {
    if (sessionId == null) await login();

    // On change d'objet pour "BatchNumbers" qui est souvent plus complet
    // ou on reste sur BatchNumberDetails mais on accepte que le magasin
    // puisse être absent et on ajuste la stratégie.
    final String url = "$baseUrl/BatchNumberDetails?\$top=1000";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "Cookie": "B1SESSION=$sessionId",
          "Content-Type": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic>? values = data['value'];

        if (values == null) return [];

        List<Map<String, dynamic>> filteredLots = [];

        for (var item in values) {
          // Selon votre DEBUG, le champ magasin n'existe pas dans le premier niveau.
          // On va essayer de chercher dans une propriété 'WarehouseLocation'
          // ou d'autres noms techniques courants.
          String itemWhs = (item['Warehouse'] ??
              item['WhsCode'] ??
              item['DefaultWarehouse'] ??
              "").toString();

          // Si le champ est toujours vide, SAP nécessite peut-être une requête jointe.
          // Mais testons d'abord avec les noms de votre SQL (DistNumber et ItemCode)
          if (itemWhs == whsCode || itemWhs.isEmpty) {
            // Si itemWhs est vide, on l'ajoute quand même pour test
            // (à retirer si trop de résultats)
            filteredLots.add({
              'itemCode': item['ItemCode']?.toString() ?? '',
              'itemName': item['ItemDescription']?.toString() ?? 'Article sans nom',
              'distNumber': item['Batch']?.toString() ?? item['SystemNumber']?.toString() ?? '',
              'quantity': "Vérifier SQL",
              'expDate': item['ExpirationDate']?.toString() ?? '-',
              'mfrDate': item['ManufacturingDate']?.toString() ?? '-',
            });
          }
        }

        // Si toujours 0, essayons une requête plus directe sur les lignes de stock
        if (filteredLots.isEmpty) {
          print("⚠️ Toujours 0 lots. Tentative via une autre URL...");
          return await _fetchViaAlternative(whsCode);
        }

        return filteredLots;
      }
    } catch (e) {
      print("❌ Exception : $e");
    }
    return [];
  }

// Fonction de secours si la première échoue
  Future<List<Map<String, dynamic>>> _fetchViaAlternative(String whsCode) async {
    // On tente d'interroger directement la table de liaison (OBTQ en Service Layer)
    final String url = "$baseUrl/BatchNumberDetails?\$filter=Warehouse eq '$whsCode'";
    // ... (Code similaire au dessus)
    return [];
  }
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