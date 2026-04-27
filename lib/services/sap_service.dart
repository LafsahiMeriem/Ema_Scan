import 'dart:convert';
import 'dart:io'; // Nécessaire pour le bypass SSL
import 'package:http/http.dart' as http;
import '../models/lot_info.dart';

// Cette classe permet d'accepter les certificats auto-signés de SAP en local
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

class SapService {
  final String baseUrl = "https://EMA.bpsMaroc.com:50000/b1s/v1";  String? sessionId;

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

  // 2. Récupération des données du Lot
  Future<LotInfo?> fetchLotData(String scanCode) async {
    // Si on n'a pas de session, on se connecte d'abord
    if (sessionId == null) {
      bool connected = await login();
      if (!connected) return null;
    }

    try {
      // On interroge les détails des numéros de lots (OIBT / OBTN)
      final response = await http.get(
        Uri.parse("$baseUrl/BatchNumberDetails?\$filter=BatchNumber eq '$scanCode'"),
        headers: {
          "Cookie": "B1SESSION=$sessionId",
          "Content-Type": "application/json"
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['value'] != null && data['value'].isNotEmpty) {
          return LotInfo.fromJson(data['value'][0]);
        } else {
          print("⚠️ Aucun lot trouvé pour le code : $scanCode");
        }
      }
      return null;
    } catch (e) {
      print("❌ Erreur lors de la récupération : $e");
      return null;
    }
  }
}