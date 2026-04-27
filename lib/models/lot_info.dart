class LotInfo {
  final String itemCode;
  final String itemName;
  final String batchNum;

  LotInfo({
    required this.itemCode,
    required this.itemName,
    required this.batchNum,
  });

  // Convertit le JSON de SAP Service Layer en objet Dart
  factory LotInfo.fromJson(Map<String, dynamic> json) {
    return LotInfo(
      itemCode: json['ItemCode'] ?? 'N/A',
      itemName: json['ItemName'] ?? 'Produit inconnu',
      batchNum: json['BatchNumber'] ?? 'N/A',
    );
  }
}