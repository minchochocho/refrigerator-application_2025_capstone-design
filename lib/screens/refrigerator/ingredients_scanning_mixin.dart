part of 'ingredients_screen.dart';

mixin IngredientsScanningMixin on State<IngredientsScreen> {
  // Abstract members provided by _IngredientsScreenState
  bool get _isLoading;
  set _isLoading(bool value);
  bool get _isProcessingBarcode;
  set _isProcessingBarcode(bool value);
  ReceiptScannerLogic get _receiptScanner;
  BarcodeScannerLogic get _barcodeScanner;
  RefrigeratorService get _refrigeratorService;
  Future<void> _loadIngredients();
  Future<void> _addIngredient({
    required String name,
    required int quantity,
    DateTime? expiryDate,
    DateTime? manufactureDate,
    DateTime? registrationDate,
    String? memo,
    String? imagePath,
    String? compartmentName,
  });
  IconData _getFoodIcon(String foodName);
  
  // These fields are accessed from _IngredientsScreenState
  String get _currentCompartmentName;
  List<String> get _compartmentNames;
  void _showReceiptScanDialog() {
    showDialog(
      context: context,
      builder: (context) => ReceiptScanDialog(
        onCameraTap: _scanReceiptWithCamera,
        onGalleryTap: _scanReceiptFromGallery,
      ),
    );
  }

  Widget _buildReceiptOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.green[600],
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanReceiptWithCamera() async {
    await _handleReceiptPick(ImageSource.camera);
  }

  Future<void> _scanReceiptFromGallery() async {
    await _handleReceiptPick(ImageSource.gallery);
  }

  Future<void> _handleReceiptPick(ImageSource source) async {
    bool loadingShown = false;
    try {
      // 전역 차단 로딩 다이얼로그 표시 (뒤로가기/외부 터치 불가)
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('영수증을 인식하는 중입니다...'),
              ],
            ),
          ),
        ),
      );
      loadingShown = true;

      final receipt = await _receiptScanner.handleReceiptPick(source);

      if (loadingShown && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }

      if (receipt != null) {
        await _showReceiptResultDialog(receipt);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('영수증을 인식하지 못했습니다'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (loadingShown && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('영수증 인식 중 오류가 발생했습니다: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _showReceiptResultDialog(Receipt receipt) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => ReceiptResultDialog(
          receipt: receipt,
          onSave: (selected) async {
            for (final s in selected) {
              await _addIngredient(
                name: s.item.name,
                quantity: s.quantity,
                expiryDate: s.item.expiryDate,
                registrationDate: receipt.date,
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    try {
      await Navigator.of(context, rootNavigator: true).push(
        
        MaterialPageRoute(
          builder: (context) => BarcodeScannerScreen(
            onBarcodeDetected: (String barcode) async {
              Navigator.pop(context);
              await _processBarcodeResult(barcode);
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('바코드 스캔 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _processBarcodeResult(String barcodeValue) async {
    if (_isProcessingBarcode) return; // re-entry guard
    _isProcessingBarcode = true;
    bool loadingShown = false;
    try {
      _barcodeScanner.showLoadingDialog(context);
      loadingShown = true;
      final savedBarcode = await _barcodeScanner.processBarcodeResult(barcodeValue);
      if (loadingShown) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingShown = false;
      }
      await _showAddIngredientFromBarcode(savedBarcode); // keep lock until dialog closed
    } catch (e) {
      if (loadingShown && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('제품 정보를 가져오는 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _isProcessingBarcode = false;
    }
  }

  Future<void> _showAddIngredientFromBarcode(BarcodeModel barcode) async {
    return showDialog(
      context: context,
      builder: (context) => AddIngredientFromBarcodeDialog(
        barcode: barcode,
        compartmentName: _currentCompartmentName,
        availableCompartments: _compartmentNames,
        onShowDetail: () => _showBarcodeDetailDialog(barcode),
        onAdd: ({
          required String name,
          required int quantity,
          DateTime? expiryDate,
          DateTime? manufactureDate,
          DateTime? registrationDate,
          String? memo,
          String? imagePath,
          String? compartmentName,
        }) async {
          await _addIngredient(
            name: name,
            quantity: quantity,
            expiryDate: expiryDate,
            manufactureDate: manufactureDate,
            registrationDate: registrationDate,
            memo: memo,
            imagePath: imagePath,
            compartmentName: compartmentName,
          );
        },
      ),
    );
  }

  void _showBarcodeDetailDialog(BarcodeModel barcode) {
    showDialog(
      context: context,
      builder: (context) => BarcodeDetailDialog(barcode: barcode),
    );
  }

  Widget _buildBarcodeProductImage(BarcodeModel barcode) {
    if (barcode.imageUrl.isNotEmpty && barcode.imageUrl != '') {
      if (barcode.isLocalImage) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            barcode.assetPath,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              return _buildProductImagePlaceholder();
            },
          ),
        );
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: barcode.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            errorWidget: (context, url, error) => _buildProductImagePlaceholder(),
          ),
        );
      }
    } else {
      return _buildProductImagePlaceholder();
    }
  }

  Widget _buildProductImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            color: Colors.grey[400],
            size: 48,
          ),
          SizedBox(height: 8),
          Text(
            '제품 이미지',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndCropImage({Function(String?)? onImageSelected}) async {
    final path = await ImagePickerHelper.pickAndCrop(context);
    if (path != null) {
      onImageSelected?.call(path);
    }
  }

  void _showCameraProductScanDialog() {
    final bulkController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: EdgeInsets.all(24),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.purple[400]!, Colors.purple[600]!],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.camera_enhance,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '카메라 제품 스캔',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Column(
                  children: [
                    _buildScanOptionTile(
                      icon: Icons.camera_alt,
                      title: '실시간 카메라 스캔',
                      subtitle: '카메라로 제품을 비춰서 즉시 인식',
                      onTap: () {
                        Navigator.pop(context);
                        _startCameraScan();
                      },
                    ),
                    SizedBox(height: 12),
                    _buildScanOptionTile(
                      icon: Icons.photo_library,
                      title: '사진에서 제품 인식',
                      subtitle: '갤러리의 제품 사진에서 자동 인식',
                      onTap: () {
                        Navigator.pop(context);
                        _scanFromGallery();
                      },
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.purple[600], size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI가 제품명, 유통기한 등을 자동으로 인식합니다',
                          style: TextStyle(
                            color: Colors.purple[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildScanOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.purple[600],
                  size: 24,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.purple[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startCameraScan() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.camera_enhance, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('사진 제품 인식 기능은 곧 추가될 예정입니다')),
          ],
        ),
        backgroundColor: Colors.purple[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _scanFromGallery() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.photo_library, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text('사진 제품 인식 기능은 곧 추가될 예정입니다')),
          ],
        ),
        backgroundColor: Colors.purple[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showBulkScanDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[400]!, Colors.green[600]!],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Text('카메라로 식품 스캔'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '카메라로 여러 식품을 한번에 스캔하고 등록할 수 있습니다.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates, color: Colors.green[600], size: 18),
                      SizedBox(width: 6),
                      Text(
                        '스캔 팁',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 제품명이 잘 보이도록 촬영하세요\n• 여러 제품을 함께 촬영 가능합니다\n• 밝은 곳에서 촬영하면 더 정확해요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _startBulkScan();
            },
            icon: Icon(Icons.camera_alt),
            label: Text('카메라 열기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _startBulkScan() {
    _simulateBulkScan();
  }

  void _simulateBulkScan() {
    final dummyProducts = [
      {'name': '바나나', 'quantity': '1송이'},
      {'name': '사과', 'quantity': '5개'},
      {'name': '우유', 'quantity': '1팩'},
      {'name': '계란', 'quantity': '1판'},
      {'name': '양파', 'quantity': '3개'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600]),
            SizedBox(width: 8),
            Text('스캔 완료'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '다음 식품들이 인식되었습니다:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 12),
            Container(
              height: 150,
              child: ListView.builder(
                itemCount: dummyProducts.length,
                itemBuilder: (context, index) {
                  final product = dummyProducts[index];
                  return ListTile(
                    leading: Icon(_getFoodIcon(product['name']!), color: Colors.green[600]),
                    title: Text(product['name']!),
                    subtitle: Text(product['quantity']!),
                    trailing: Icon(Icons.add_circle_outline, color: Colors.green[600]),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addBulkIngredients(dummyProducts);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: Text('모두 추가'),
          ),
        ],
      ),
    );
  }

  Future<void> _addBulkIngredients(List<Map<String, String>> products) async {
    for (final product in products) {
      final ingredientData = {
        'name': product['name']!,
        'quantity': product['quantity']!,
        'created_at': Timestamp.now(),
        'expiryDate': null,
      };

      await _refrigeratorService.addIngredient(
        widget.roomId,
        widget.refrigeratorName,
        widget.compartmentIndex,
        ingredientData,
      );
    }

    _loadIngredients();
  }

  Future<void> _openDateRecognitionCamera(BuildContext context, Function(String) onDateRecognized) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용 가능한 카메라가 없습니다')),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DateRecognitionCameraScreen(
            cameras: cameras,
            onDateRecognized: onDateRecognized,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('카메라 초기화 오류: $e')),
      );
    }
  }
}


