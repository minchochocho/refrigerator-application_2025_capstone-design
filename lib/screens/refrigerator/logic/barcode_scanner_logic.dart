import 'package:flutter/material.dart';
import '../../../barcode_system/barcode_service.dart';
import '../../../barcode_system/barcode_model.dart';
import '../../../barcode_system/serp_search_service.dart';

/// 바코드 스캔 관련 로직을 담당하는 클래스
class BarcodeScannerLogic {
  final BarcodeService _barcodeService = BarcodeService();
  final SerpSearchService _serpService = SerpSearchService();
  
  /// 바코드 스캔 결과 처리
  Future<BarcodeModel> processBarcodeResult(String barcodeValue) async {
    try {
      // 바코드 타입 감지
      final barcodeType = _barcodeService.detectBarcodeType(barcodeValue);
      
      // 기존 바코드 확인
      final existingBarcode = await _barcodeService.findExistingBarcode(barcodeValue, barcodeType);
      
      String foodName = '';
      String imageUrl = '';
      
      if (existingBarcode != null) {
        // 기존 바코드가 있으면 해당 정보 사용
        foodName = existingBarcode.foodName;
        imageUrl = existingBarcode.imageUrl;
      } else {
        // 새로운 바코드면 SERP API로 검색
        final productInfo = await _serpService.searchProductByBarcode(barcodeValue);
        foodName = productInfo['foodName'] ?? '알 수 없는 제품';
        imageUrl = productInfo['imageUrl'] ?? '';
      }
      
      // 타임바코드(CODE-128)인 경우 제품명은 "신선제품"
      if (barcodeType == 'CODE-128') {
        foodName = '신선제품';
      }
      
      // 바코드 정보 저장
      final savedBarcode = await _barcodeService.saveBarcodeToFirestore(
        barcodeValue,
        barcodeType,
        foodName: foodName,
        imageUrl: imageUrl,
      );
      
      return savedBarcode;
    } catch (e) {
      print('바코드 처리 오류: $e');
      rethrow;
    }
  }
  
  /// 로딩 다이얼로그 표시
  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('제품 정보를 가져오는 중...'),
              ],
            ),
          ),
        );
      },
    );
  }
}

