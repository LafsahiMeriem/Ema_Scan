class LotInfo {
  final String itemCode;
  final String itemName;
  final String distNumber;
  final double qteCarton;
  final double numInCnt;
  final String? inDate;
  final String? mnfSerial;
  final String? expDate;
  final String sysNumber;

  LotInfo({
    required this.itemCode,
    required this.itemName,
    required this.distNumber,
    required this.qteCarton,
    required this.numInCnt,
    this.inDate,
    this.mnfSerial,
    this.expDate,
    required this.sysNumber,
  });

  factory LotInfo.fromJson(Map<String, dynamic> json) {
    return LotInfo(
      itemCode: json['ItemCode'] ?? 'N/A',
      itemName: json['ItemDescription'] ?? 'Inconnu',
      distNumber: json['Batch'] ?? 'N/A',
      qteCarton: double.tryParse(json['U_U_QteCarton']?.toString() ?? '0') ?? 0.0,
      inDate: json['AdmissionDate'] != null ? json['AdmissionDate'].split('T')[0] : '---',
      numInCnt: double.tryParse(json['NumInCnt']?.toString() ?? '1') ?? 1.0,
      mnfSerial: json['BatchAttribute1'] ?? '---',
      expDate: json['ExpirationDate'] != null ? json['ExpirationDate'].split('T')[0] : '---',
      sysNumber: json['SystemNumber']?.toString() ?? '0',
    );
  }
  double get totalQuantity => qteCarton * numInCnt;
}