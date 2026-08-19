import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'barcode_model.dart';

class BarcodeService {
  static final BarcodeService _instance = BarcodeService._internal();
  factory BarcodeService() => _instance;
  BarcodeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _barcodesCollection = 'barcodes'; // 루트 컬렉션

  // 현재 사용자 ID 가져오기
  String? get currentUserId => FirebaseAuth.instance.currentUser?.uid;

  // 전역 바코드 캐시 검색 (사용자에 관계없이)
  Future<BarcodeModel?> findExistingBarcode(String barcodeValue, String barcodeType) async {
    try {
      final querySnapshot = await _firestore
          .collection(_barcodesCollection)
          .where('barcodeId', isEqualTo: barcodeValue)
          .where('barcodeType', isEqualTo: barcodeType)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return BarcodeModel.fromFirestore(doc.data(), doc.id);
      }

      return null;
    } catch (e) {
      print('기존 바코드 검색 중 오류 발생: $e');
      return null;
    }
  }

  // 바코드 정보를 Firestore에 저장 (전역 캐시 활용)
  Future<BarcodeModel> saveBarcodeToFirestore(
      String barcodeValue,
      String barcodeType, {
        String foodName = '',
        String imageUrl = '',
        bool forceNew = false, // 강제로 새로 저장할지 여부
      }) async {
    
    final userId = currentUserId;
    if (userId == null) throw Exception('로그인이 필요합니다');

    try {
      // 강제 새로 저장이 아닌 경우, 전역 바코드 캐시 체크
      BarcodeModel? existingBarcode;
      if (!forceNew) {
        existingBarcode = await findExistingBarcode(barcodeValue, barcodeType);
        if (existingBarcode != null) {
          print('전역 캐시된 바코드 발견: ${existingBarcode.barcodeId}');
          
          // 스캔 횟수 증가 및 마지막 스캔 시간 업데이트
          final updatedBarcode = existingBarcode.incrementScanCount();
          await _firestore.collection(_barcodesCollection).doc(existingBarcode.id).update({
            'scanCount': updatedBarcode.scanCount,
            'lastScannedAt': updatedBarcode.lastScannedAt,
          });

          return updatedBarcode;
        }
      }

      // 새로운 바코드 저장 (전역 컬렉션)
      final now = DateTime.now();
      final timestamp = DateTime(now.year, now.month, now.day);

      final barcode = BarcodeModel(
        id: '', // Firestore에서 자동 생성
        barcodeId: barcodeValue,
        barcodeType: barcodeType,
        foodName: foodName,
        imageUrl: imageUrl,
        timestamp: timestamp,
        expirationDate: barcodeType == 'CODE-128' ? extractExpirationDate(barcodeValue) : '',
        userId: userId, // 처음 스캔한 사용자
        scanCount: 1,
        lastScannedAt: timestamp,
      );

      final docRef = await _firestore.collection(_barcodesCollection).add(barcode.toFirestore());
      print('새로운 바코드 저장됨: $barcodeValue');

      return barcode.copyWith(id: docRef.id);
    } catch (e) {
      throw Exception('바코드 저장 실패: $e');
    }
  }

  // 유통기한 추출 로직 (기존과 동일)
  String extractExpirationDate(String barcodeValue) {
    if (barcodeValue.length < 5) return '';

    final lastFiveDigits = barcodeValue.substring(barcodeValue.length - 5);
    if (!RegExp(r'^\d{5}$').hasMatch(lastFiveDigits)) return '';

    final firstDigit = int.parse(lastFiveDigits[0]);
    final now = DateTime.now();

    int day;
    switch (firstDigit) {
      case 2:
        day = int.parse(lastFiveDigits.substring(3, 5));
        break;
      case 4:
        day = int.parse(lastFiveDigits.substring(1, 3));
        break;
      default:
        return '';
    }

    if (day < 1 || day > 31) return '';

    var month = now.month;
    var year = now.year;

    if (day < now.day) {
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }

    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  // 모든 바코드 가져오기 (간단한 버전)
  Stream<List<BarcodeModel>> getAllBarcodes() {
    return _firestore
        .collection(_barcodesCollection)
        .orderBy('lastScannedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BarcodeModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  // 특정 ID의 바코드 가져오기 (루트 컬렉션에서)
  Future<BarcodeModel?> getBarcodeById(String id) async {
    try {
      final docSnapshot = await _firestore.collection(_barcodesCollection).doc(id).get();
      return docSnapshot.exists
          ? BarcodeModel.fromFirestore(docSnapshot.data()!, docSnapshot.id)
          : null;
    } catch (e) {
      throw Exception('바코드 조회 실패: $e');
    }
  }

  // 바코드 삭제
  Future<void> deleteBarcode(String barcodeId) async {
    try {
      await _firestore.collection(_barcodesCollection).doc(barcodeId).delete();
    } catch (e) {
      throw Exception('바코드 삭제 실패: $e');
    }
  }

  // 바코드 정보 업데이트 (전역 바코드 업데이트)
  Future<void> updateBarcodeInfo(String id, String foodName, String imageUrl) async {
    try {
      await _firestore.collection(_barcodesCollection).doc(id).update({
        'foodName': foodName,
        'imageUrl': imageUrl,
      });
    } catch (e) {
      throw Exception('바코드 정보 업데이트 실패: $e');
    }
  }

  // 이미지만 업데이트
  Future<void> updateBarcodeImage(String id, String imageUrl) async {
    try {
      await _firestore.collection(_barcodesCollection).doc(id).update({'imageUrl': imageUrl});
    } catch (e) {
      throw Exception('바코드 이미지 업데이트 실패: $e');
    }
  }

  // 바코드 타입 판별 (기존과 동일)
  String detectBarcodeType(String value) {
    final length = value.length;

    // 길이 기반 우선 판별
    switch (length) {
      case 8:
        return value.startsWith('0') ? 'UPC-E' : 'EAN-8';
      case 12:
        return 'UPC-A';
      case 13:
        return 'EAN-13';
      case 14:
        return 'ITF-14';
    }

    // URL 패턴 체크
    if (value.startsWith(RegExp(r'https?://|www\.'))) {
      return 'QR URL';
    }

    // 숫자만으로 구성된 경우
    if (RegExp(r'^\d+$').hasMatch(value)) {
      return 'CODE-128';
    }

    return 'QR/OTHER';
  }

  // 전역 바코드 통계 조회
  Future<Map<String, dynamic>> getBarcodeStats() async {
    try {
      final snapshot = await _firestore.collection(_barcodesCollection).get();
      
      int totalBarcodes = snapshot.docs.length;
      int totalScans = 0;
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        totalScans += (data['scanCount'] as int?) ?? 1;
      }
      
      return {
        'totalBarcodes': totalBarcodes,
        'totalScans': totalScans,
        'averageScansPerBarcode': totalBarcodes > 0 ? totalScans / totalBarcodes : 0,
      };
    } catch (e) {
      print('바코드 통계 조회 오류: $e');
      return {'totalBarcodes': 0, 'totalScans': 0, 'averageScansPerBarcode': 0};
    }
  }
}