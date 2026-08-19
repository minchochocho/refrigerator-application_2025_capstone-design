class BarcodeModel {
  final String id;
  final String barcodeId;
  final String barcodeType;
  final String foodName;
  final String imageUrl;
  final DateTime timestamp;
  final String expirationDate;
  final String? userId; // 바코드를 처음 스캔한 사용자 (nullable)
  final int scanCount; // 스캔 횟수
  final DateTime lastScannedAt; // 마지막 스캔 시간

  const BarcodeModel({
    required this.id,
    required this.barcodeId,
    required this.barcodeType,
    required this.timestamp,
    this.foodName = '',
    this.imageUrl = '',
    this.expirationDate = '',
    this.userId,
    this.scanCount = 1,
    DateTime? lastScannedAt,
  }) : lastScannedAt = lastScannedAt ?? timestamp;

  // Firestore에서 가져온 데이터를 BarcodeModel로 변환
  factory BarcodeModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return BarcodeModel(
      id: documentId,
      barcodeId: data['barcodeId'] ?? '',
      barcodeType: data['barcodeType'] ?? 'UNKNOWN',
      timestamp: _getDateOnly(data['timestamp']?.toDate() ?? DateTime.now()),
      foodName: data['foodName'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      expirationDate: data['expirationDate'] ?? '',
      userId: data['userId'],
      scanCount: data['scanCount'] ?? 1,
      lastScannedAt: _getDateOnly(data['lastScannedAt']?.toDate() ?? DateTime.now()),
      
    );
  }

  // BarcodeModel을 Firestore에 저장할 형태로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'barcodeId': barcodeId,
      'barcodeType': barcodeType,
      'foodName': foodName,
      'imageUrl': imageUrl,
      'expirationDate': expirationDate,
      'timestamp': timestamp,
      'userId': userId,
      'scanCount': scanCount,
      'lastScannedAt': lastScannedAt,
    };
  }

  // copyWith 메소드 추가 - 불변성 유지
  BarcodeModel copyWith({
    String? id,
    String? barcodeId,
    String? barcodeType,
    String? foodName,
    String? imageUrl,
    DateTime? timestamp,
    String? expirationDate,
    String? userId,
    int? scanCount,
    DateTime? lastScannedAt,
  }) {
    return BarcodeModel(
      id: id ?? this.id,
      barcodeId: barcodeId ?? this.barcodeId,
      barcodeType: barcodeType ?? this.barcodeType,
      foodName: foodName ?? this.foodName,
      imageUrl: imageUrl ?? this.imageUrl,
      timestamp: timestamp ?? this.timestamp,
      expirationDate: expirationDate ?? this.expirationDate,
      userId: userId ?? this.userId,
      scanCount: scanCount ?? this.scanCount,
      lastScannedAt: lastScannedAt ?? this.lastScannedAt,
    );
  }

  // 스캔 횟수 증가 메소드
  BarcodeModel incrementScanCount() {
    return copyWith(
      scanCount: scanCount + 1,
      lastScannedAt: DateTime.now(),
    );
  }

  // 시간 정보를 제외하고 날짜만 반환하는 도우미 메서드
  static DateTime _getDateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  // 날짜 포맷팅 메소드 - UI에서 사용
  String get formattedDate =>
      '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';

  // 마지막 스캔 날짜 포맷팅
  String get formattedLastScannedDate =>
      '${lastScannedAt.year}-${lastScannedAt.month.toString().padLeft(2, '0')}-${lastScannedAt.day.toString().padLeft(2, '0')}';

  // 로컬 이미지 여부 확인
  bool get isLocalImage => imageUrl.startsWith('asset://');

  // 실제 asset 경로 반환
  String get assetPath => isLocalImage ? imageUrl.replaceFirst('asset://', '') : imageUrl;
}