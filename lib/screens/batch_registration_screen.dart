import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../barcode_system/serp_search_service.dart';
import '../barcode_system/barcode_service.dart';
import '../services/refrigerator_service.dart';

// 일괄등록용 제품 모델
class BatchProduct {
  final String barcode;
  final String name;
  final String imageUrl;
  final String expirationDate;
  int quantity;
  bool selected; // 체크박스 선택 여부 추가

  BatchProduct({
    required this.barcode,
    required this.name,
    required this.imageUrl,
    this.expirationDate = '',
    this.quantity = 1,
    this.selected = true, // 기본값: 선택됨
  });
}

class BatchRegistrationScreen extends StatefulWidget {
  final String roomId;
  final String refrigeratorName;
  final int compartmentIndex;

  const BatchRegistrationScreen({
    Key? key,
    required this.roomId,
    required this.refrigeratorName,
    required this.compartmentIndex,
  }) : super(key: key);

  @override
  _BatchRegistrationScreenState createState() => _BatchRegistrationScreenState();
}

class _BatchRegistrationScreenState extends State<BatchRegistrationScreen> {
  MobileScannerController? cameraController;
  final SerpSearchService serpService = SerpSearchService();
  final BarcodeService barcodeService = BarcodeService();
  final RefrigeratorService refrigeratorService = RefrigeratorService();
  
  List<BatchProduct> scannedProducts = [];
  bool _isProcessing = false;
  bool _showQuantitySelection = false;
  String? _currentScannedBarcode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // 화면 시작 시 스캔된 제품 목록 초기화
    scannedProducts.clear();
    
    // 카메라 초기화
    _initializeCamera();
    
    print('일괄등록 화면 초기화 - 스캔된 제품 목록 초기화됨');
  }

  void _initializeCamera() {
    cameraController = MobileScannerController();
  }

  void _reinitializeCamera() {
    // 기존 컨트롤러 해제
    cameraController?.dispose();
    // 새 컨트롤러 생성
    cameraController = MobileScannerController();
    setState(() {}); // UI 업데이트
  }

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showQuantitySelection) {
      return _buildQuantitySelectionScreen();
    }
    
    return _buildScannerScreen();
  }

  Widget _buildScannerScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text('일괄등록'),
        backgroundColor: Color(0xFF6B9FFF),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (scannedProducts.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _showQuantitySelection = true;
                });
              },
              child: Text(
                '완료',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      extendBody: true,
      body: Stack(
        children: [
          if (cameraController != null)
            MobileScanner(
              controller: cameraController!,
              onDetect: (capture) {
                if (!_isProcessing) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final barcode = barcodes.first;
                    if (barcode.rawValue != null) {
                      _handleBarcodeDetected(barcode.rawValue!);
                    }
                  }
                }
              },
            ),
          
          // 스캔된 제품 수 표시
          if (scannedProducts.isNotEmpty)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF6B9FFF),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF6B9FFF).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '스캔된 제품: ${scannedProducts.length}개',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // 로딩 표시
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '제품 정보를 가져오는 중...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // 안내 메시지
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
                  SizedBox(height: 8),
                  Text(
                    '바코드를 스캔해주세요',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (scannedProducts.isNotEmpty) ...[
                    SizedBox(height: 8),
                    Text(
                      '계속 스캔하거나 우상단 완료 버튼을 눌러주세요',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelectionScreen() {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        title: Text(
          '수량 선택',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _showQuantitySelection = false;
              _isProcessing = false;
              _currentScannedBarcode = null;
            });
            _reinitializeCamera();
          },
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _showQuantitySelection = false;
                  _isProcessing = false;
                  _currentScannedBarcode = null;
                });
                _reinitializeCamera();
              },
              icon: Icon(
                Icons.add_circle_outline,
                color: Color(0xFF6B9FFF),
                size: 28,
              ),
              tooltip: '계속 스캔',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 제품 목록
          Expanded(
            child: scannedProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.inbox,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          '스캔된 제품이 없습니다',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '제품을 스캔해주세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 100), // 하단 여백 추가
                    itemCount: scannedProducts.length,
                    itemBuilder: (context, index) {
                      final product = scannedProducts[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 제품 이미지
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Color(0xFFF5F5F5),
                                border: Border.all(color: Color(0xFFE0E0E0)),
                              ),
                              child: product.imageUrl.isEmpty || product.imageUrl == ''
                                  ? Center(
                                      child: Icon(
                                        Icons.shopping_bag_rounded,
                                        size: 24,
                                        color: Colors.grey[400],
                                      ),
                                    )
                                  : product.imageUrl.startsWith('asset://')
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.asset(
                                            product.imageUrl.substring(8),
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Center(
                                                child: Icon(
                                                  Icons.shopping_bag_rounded,
                                                  size: 24,
                                                  color: Colors.grey[400],
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            product.imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Center(
                                                child: Icon(
                                                  Icons.shopping_bag_rounded,
                                                  size: 24,
                                                  color: Colors.grey[400],
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                            ),
                            
                            SizedBox(width: 14),
                            
                            // 제품 정보
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[900],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(width: 12),
                            
                            // 수량 선택 버튼
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 수량 감소 버튼
                                InkWell(
                                  onTap: product.quantity > 1
                                      ? () {
                                          setState(() {
                                            product.quantity--;
                                          });
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: product.quantity > 1 
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      size: 16,
                                      color: product.quantity > 1 
                                          ? Colors.red[400]
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ),
                                
                                // 수량 표시
                                Container(
                                  width: 32,
                                  child: Text(
                                    '${product.quantity}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[900],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                
                                // 수량 증가 버튼
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      product.quantity++;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF3B82F6).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            
                            SizedBox(width: 8),
                            
                            // 체크박스
                            InkWell(
                              onTap: () {
                                setState(() {
                                  product.selected = !product.selected;
                                });
                              },
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: product.selected
                                      ? Color(0xFF3B82F6)
                                      : Colors.white,
                                  border: Border.all(
                                    color: product.selected
                                        ? Color(0xFF3B82F6)
                                        : Colors.grey[300]!,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: product.selected
                                    ? Icon(
                                        Icons.check,
                                        size: 16,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          // 하단 저장 버튼
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveAllProducts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6B9FFF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              '냉장고에 저장',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleBarcodeDetected(String barcode) async {
    print('🔍 바코드 스캔 감지: $barcode (처리 중: $_isProcessing)');
    
    if (_isProcessing) {
      print('⚠️ 이미 처리 중인 바코드가 있어 무시: $barcode');
      return;
    }
    
    print('📊 현재 스캔된 제품 수: ${scannedProducts.length}');
    for (int i = 0; i < scannedProducts.length; i++) {
      print('  제품 $i: ${scannedProducts[i].barcode} - ${scannedProducts[i].name}');
    }
    
    // 이미 스캔된 바코드인지 확인
    int existingProductIndex = scannedProducts.indexWhere((product) => product.barcode == barcode);
    bool isDuplicate = existingProductIndex != -1;
    print('🔄 중복 체크 결과: $isDuplicate');
    
    if (isDuplicate) {
      print('📈 중복 바코드 감지 - 수량 증가: $barcode');
      
      // _isProcessing을 true로 설정하여 스캔 비활성화
      setState(() {
        _isProcessing = true;
        scannedProducts[existingProductIndex].quantity++;
      });

      // 연속 스캔을 위한 다이얼로그 표시
      _showContinueDialog();
      return;
    }
    
    print('✅ 새로운 바코드 처리 시작: $barcode');

    setState(() {
      _isProcessing = true;
      _currentScannedBarcode = barcode;
    });

    try {
      // 바코드 타입 감지
      final barcodeType = barcodeService.detectBarcodeType(barcode);
      
      // 기존 바코드 캐시 확인
      final existingBarcode = await barcodeService.findExistingBarcode(barcode, barcodeType);
      
      String foodName = '';
      String imageUrl = '';
      
      if (existingBarcode != null) {
        // 캐시된 바코드가 있으면 해당 정보 사용
        foodName = existingBarcode.foodName;
        imageUrl = existingBarcode.imageUrl;
        print('바코드 캐시 사용 - 바코드: $barcode, 상품명: $foodName (캐시에서 가져옴)');
      } else {
        // 새로운 바코드면 SERP API로 검색
        final productInfo = await serpService.searchProductByBarcode(barcode);
        foodName = productInfo['foodName'] ?? '알 수 없는 제품';
        imageUrl = productInfo['imageUrl'] ?? '';
        print('바코드 API 검색 - 바코드: $barcode, 원본 상품명: ${productInfo['foodName']}, 필터링된 상품명: $foodName');
      }
      
      // 타임바코드(CODE-128)인 경우 제품명은 "신선제품"
      if (barcodeType == 'CODE-128') {
        foodName = '신선제품';
      }
      
      // 바코드 정보 저장 (캐시든 새로운 것이든 항상 호출 - 스캔 횟수 증가 및 마지막 스캔 시간 업데이트)
      final savedBarcode = await barcodeService.saveBarcodeToFirestore(
        barcode,
        barcodeType,
        foodName: foodName,
        imageUrl: imageUrl,
      );

      // 알 수 없는 제품의 경우 이미지를 '' 문자로 설정
      if (foodName == '알 수 없는 제품') {
        imageUrl = '';
      }

      // 유통기한 정보 추출 (savedBarcode에서 가져옴)
      String expirationDate = savedBarcode.expirationDate;
      if (expirationDate.isNotEmpty) {
        print('유통기한 추출됨: $barcode -> $expirationDate');
      }

      // 스캔된 제품 목록에 추가 (유통기한 정보 포함)
      setState(() {
        scannedProducts.add(BatchProduct(
          barcode: barcode,
          name: foodName,
          imageUrl: imageUrl,
          expirationDate: expirationDate, // 유통기한 정보 추가
        ));
      });

      // 다이얼로그 표시 (이 시점에서는 _isProcessing = true 유지하여 스캔 비활성화)
      _showContinueDialog();

    } catch (e) {
      _showSnackBar('제품 정보를 가져올 수 없습니다', Colors.red);
      // 오류 발생 시에도 _isProcessing 해제
      setState(() {
        _isProcessing = false;
        _currentScannedBarcode = null;
      });
    }
  }

  void _showContinueDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 아이콘
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Color(0xFF6B9FFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF6B9FFF),
                    size: 28,
                  ),
                ),
                
                SizedBox(height: 20),
                
                // 제목
                Text(
                  '스캔 완료',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                
                SizedBox(height: 8),
                
                // 설명
                Text(
                  '제품이 추가되었습니다\n계속 스캔하시겠습니까?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // 버튼들
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _isProcessing = false;
                            _currentScannedBarcode = null;
                            _showQuantitySelection = true;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          '완료',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          setState(() {
                            _isProcessing = false;
                            _currentScannedBarcode = null;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B9FFF),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          '계속 스캔',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveAllProducts() async {
    if (scannedProducts.isEmpty || _isSaving) return;

    // 선택된 제품만 필터링
    final selectedProducts = scannedProducts.where((p) => p.selected).toList();
    
    if (selectedProducts.isEmpty) {
      _showSnackBar('선택된 제품이 없습니다', Colors.orange);
      return;
    }

    _isSaving = true;
    bool loadingShown = false;

    // 로딩 다이얼로그 표시 (최상위 네비게이터)
    await Future.microtask(() {
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('제품을 냉장고에 추가하는 중...'),
            ],
          ),
        ),
      );
      loadingShown = true;
    });

    try {
      for (final product in selectedProducts) {
        final ingredientData = {
          'name': product.name,
          'barcode': product.barcode,
          'imagePath': product.imageUrl,
          'quantity': product.quantity, // 숫자로 저장
          'created_at': Timestamp.now(),
          'expiryDate': product.expirationDate.isNotEmpty
              ? _safeParseToTimestamp(product.expirationDate)
              : null,
        };

        await refrigeratorService.addIngredient(
          widget.roomId,
          widget.refrigeratorName,
          widget.compartmentIndex,
          ingredientData,
        );
      }

      if (loadingShown && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }
      // BatchRegistrationScreen만 한 단계 닫기 (칸 화면 유지)
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop('saved');
      }
    } catch (e) {
      if (loadingShown && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      _showSnackBar('저장 중 오류가 발생했습니다', Colors.red);
    } finally {
      _isSaving = false;
    }
  }

  Timestamp _safeParseToTimestamp(String dateStr) {
    try {
      // 지원 형식: yyyy-MM-dd 또는 yyyy.MM.dd
      if (dateStr.contains('.')) {
        final parts = dateStr.split('.');
        if (parts.length >= 3) {
          final y = int.parse(parts[0]);
          final m = int.parse(parts[1]);
          final d = int.parse(parts[2]);
          return Timestamp.fromDate(DateTime(y, m, d));
        }
      }
      return Timestamp.fromDate(DateTime.parse(dateStr));
    } catch (_) {
      return Timestamp.fromDate(DateTime.now());
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}
