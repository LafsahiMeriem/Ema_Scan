class LotInfo {
  final String itemCode;
  final String itemName;
  final String distNumber;
  final double qteCarton;
  final double numInCnt;
  final String? mfrDate;
  final String? expDate;
  final String? mfrSerial;
  final String? docDate;

  LotInfo({
    required this.itemCode,
    required this.itemName,
    required this.distNumber,
    required this.qteCarton,
    required this.numInCnt,
    this.mfrDate,
    this.expDate,
    this.mfrSerial,
    this.docDate,
  });

  factory LotInfo.fromJson(Map<String, dynamic> json) {
    String name = json['ItemDescription'] ?? json['ItemName'] ?? '';
    double extractedNumInCnt = 1.0;

    try {
      final regExp = RegExp(r'(\d+)UN');
      final match = regExp.firstMatch(name);
      if (match != null) {
        extractedNumInCnt = double.parse(match.group(1)!);
      }
    } catch (e) {
      print("Erreur extraction NumInCnt: $e");
    }

    return LotInfo(
      itemCode: json['ItemCode'] ?? '',
      itemName: name,
      distNumber: json['Batch'] ?? '',
      qteCarton: (json['U_U_QteCarton'] ?? 0).toDouble(),
      numInCnt: extractedNumInCnt,

      // Correction Dates : Si ManufacturingDate est null, on prend AdmissionDate
      mfrDate: (json['ManufacturingDate'] != null)
          ? json['ManufacturingDate'].toString().split('T')[0]
          : (json['AdmissionDate'] != null ? json['AdmissionDate'].toString().split('T')[0] : "-"),

      expDate: json['ExpirationDate']?.toString().split('T')[0],
      mfrSerial: json['BatchAttribute1'] ?? "-",
      docDate: json['AdmissionDate']?.toString().split('T')[0],
    );
  }

  // Utilisation de .roundToDouble() pour éviter les erreurs de précision SAP
  double get totalQuantity => (qteCarton * numInCnt).roundToDouble();
}