class LotInfo {
  final String itemCode;
  final String itemName;
  final String distNumber;
  final String? qteCarton;
  final String? inDate;
  final String? mnfSerial;
  final String? expDate;

  LotInfo({
    required this.itemCode,
    required this.itemName,
    required this.distNumber,
    this.qteCarton,
    this.inDate,
    this.mnfSerial,
    this.expDate,
  });

  factory LotInfo.fromJson(Map<String, dynamic> json) {
    return LotInfo(
      itemCode: json['ItemCode'] ?? 'N/A',
      itemName: json['ItemDescription'] ?? 'Inconnu', // Changé ItemName -> ItemDescription
      distNumber: json['Batch'] ?? 'N/A',            // Changé DistNumber -> Batch
      qteCarton: json['U_U_QteCarton']?.toString() ?? '0',
      inDate: json['AdmissionDate'] != null ? json['AdmissionDate'].split('T')[0] : '---', // Changé InDate -> AdmissionDate
      mnfSerial: json['BatchAttribute1'] ?? '---',   // On utilise souvent Attribute1 pour le MnfSerial
      expDate: json['ExpirationDate'] != null ? json['ExpirationDate'].split('T')[0] : '---', // Changé ExpDate -> ExpirationDate
    );
  }
}