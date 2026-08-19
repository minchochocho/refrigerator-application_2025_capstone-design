import 'dart:convert';
import 'dart:io';

import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../services/groq_client.dart';
import '../utils/receipt_parse_utils.dart';

import '../models/receipt_item.dart';

class ReceiptScannerScreen extends StatefulWidget {
  const ReceiptScannerScreen({super.key});

  @override
  State<ReceiptScannerScreen> createState() => _ReceiptScannerScreenState();
}

class _ReceiptScannerScreenState extends State<ReceiptScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _isLoading = false;
  List<ReceiptItem> _items = [];
  final GroqClient _groq = GroqClient();
  bool _useDummyData = false; // 더미 데이터 비활성화

  @override
  void initState() {
    super.initState();
  }

  // 서버 호출 제거: 로컬 OCR만 사용

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.storage.request();
  }

  Future<void> _pickFromCamera() async {
    await _requestPermissions();
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 95);
    if (x == null) return;
    final fixed = await _fixImageRotation(File(x.path));
    setState(() { _image = fixed; });
    await _process();
  }

  Future<void> _pickFromGallery() async {
    await _requestPermissions();
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (x == null) return;
    setState(() { _image = File(x.path); });
    await _process();
  }

  Future<File> _fixImageRotation(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final exifData = await readExifFromBytes(bytes);
      final img.Image? original = img.decodeImage(bytes);
      if (original == null) return file;
      final orientationValue = exifData['Image Orientation']?.printable;
      int? o;
      if (orientationValue != null) {
        if (orientationValue.contains('180')) o = 3;
        else if (orientationValue.contains('90 CW')) o = 6;
        else if (orientationValue.contains('90 CCW')) o = 8;
      }
      img.Image fixed = original;
      if (o == 3) fixed = img.copyRotate(original, angle: 180);
      else if (o == 6) fixed = img.copyRotate(original, angle: 90);
      else if (o == 8) fixed = img.copyRotate(original, angle: -90);
      final out = await file.writeAsBytes(img.encodeJpg(fixed));
      return out;
    } catch (_) {
      return file;
    }
  }

  Future<void> _process() async {
    if (_image == null) return;
    setState(() { _isLoading = true; _items = []; });
    try {
      final recognized = await _processLocallyWithMLKit(_image!);
      final refined = await _groq.refineItems(
        ocrText: recognized.$2,
        basicItems: recognized.$1,
      );
      setState(() { _items = refined; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('인식 오류: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<(List<ReceiptItem>, String)> _processLocallyWithMLKit(File imageFile) async {
    // 전처리로 OCR 인식률 향상
    final pre = await ReceiptParseUtils.enhanceImageForOcr(imageFile);
    final input = InputImage.fromFile(pre);
    // 일부 기기에서 한국어 옵션 클래스가 누락될 수 있어 안전 폴백 제공
    TextRecognizer recognizer;
    try {
      recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    } catch (_) {
      recognizer = TextRecognizer();
    }
    try {
      final RecognizedText rt = await recognizer.processImage(input);
      final String text = rt.text;
      final items = ReceiptParseUtils.parseItemsHeuristically(text);
      return (items, text);
    } finally {
      await recognizer.close();
    }
  }

  List<ReceiptItem> _parseReceiptTextLocally(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final List<ReceiptItem> items = [];
    for (final line in lines) {
      if (_isMetaLine(line)) continue;
      // 패턴: "상품명 2 3000" 또는 "상품명 3000"
      final m = RegExp(r'^(.+?)\s+(\d{1,2})\s+(\d{3,})$').firstMatch(line);
      if (m != null) {
        final name = m.group(1)!.trim();
        final qty = int.tryParse(m.group(2)! ) ?? 1;
        final price = double.tryParse(m.group(3)!.replaceAll(',', ''));
        if (name.isNotEmpty) {
          items.add(ReceiptItem(name: name, quantity: qty, price: price));
          continue;
        }
      }
      final m2 = RegExp(r'^(.+?)\s+(\d{3,})$').firstMatch(line);
      if (m2 != null) {
        final name = m2.group(1)!.trim();
        final price = double.tryParse(m2.group(2)!.replaceAll(',', ''));
        if (name.isNotEmpty) {
          items.add(ReceiptItem(name: name, quantity: 1, price: price));
          continue;
        }
      }
      // 키워드 기반 후보 라인 → 수량 1로 추가
      if (_looksLikeProduct(line)) {
        items.add(ReceiptItem(name: line, quantity: 1));
      }
    }
    // 중복 제거(이름 기준)
    final seen = <String>{};
    final dedup = <ReceiptItem>[];
    for (final it in items) {
      final key = it.name;
      if (!seen.contains(key)) {
        seen.add(key);
        dedup.add(it);
      }
    }
    return dedup;
  }

  bool _isMetaLine(String line) {
    final meta = [
      '합계','총액','부가세','할인','카드','현금','승인','거래','사업자','주소','전화',
      '상품명','단가','수량','금액','일시','시간','날짜','포인트','적립','쿠폰',
    ];
    if (RegExp(r'^\d+$').hasMatch(line)) return true;
    return meta.any((k) => line.contains(k));
  }

  bool _looksLikeProduct(String line) {
    // 한글/영문 포함, 너무 짧지 않음, 큰 금액 숫자 포함하지 않음
    if (line.length < 2 || line.length > 25) return false;
    if (RegExp(r'\d{4,}').hasMatch(line)) return false;
    return RegExp(r'[가-힣A-Za-z]').hasMatch(line);
  }

  @override
  Widget build(BuildContext context) {
    // 결과가 있으면 결과 화면 표시
    if (_items.isNotEmpty && !_isLoading) {
      return _buildResultScreen();
    }

    // 이미지 선택 전이거나 로딩 중인 경우
    return _buildInitialScreen();
  }

  Widget _buildInitialScreen() {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('영수증 인식'),
        backgroundColor: Color(0xFF6B9FFF),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 버튼들
            Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickFromCamera,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('카메라 촬영'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6B9FFF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('갤러리 선택'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6B9FFF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            
            // 이미지
            if (_image != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 3/4,
                    child: Image.file(_image!, fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            
            // 로딩
            if (_isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B9FFF)),
                    strokeWidth: 3,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
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
            Navigator.pop(context);
          },
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: () {
                setState(() {
                  _image = null;
                  _items = [];
                });
              },
              icon: Icon(
                Icons.add_circle_outline,
                color: Color(0xFF6B9FFF),
                size: 28,
              ),
              tooltip: '다시 촬영',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 제품 목록
          Expanded(
            child: _items.isEmpty
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
                          '인식된 항목이 없습니다',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '영수증을 다시 촬영해주세요',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 100),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
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
                            // 제품 이미지/아이콘
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Color(0xFFF5F5F5),
                                border: Border.all(color: Color(0xFFE0E0E0)),
                              ),
                              child: Icon(
                                Icons.shopping_basket_rounded,
                                size: 24,
                                color: Colors.grey[400],
                              ),
                            ),
                            
                            SizedBox(width: 14),
                            
                            // 제품 정보
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[900],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF3B82F6).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '수량 ${item.quantity ?? 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                      ),
                                      if (item.price != null) ...[
                                        SizedBox(width: 8),
                                        Text(
                                          '${item.price!.toStringAsFixed(0)}원',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(width: 12),
                            
                            // 수량 선택 및 삭제 버튼
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 수량 감소 버튼
                                InkWell(
                                  onTap: (item.quantity ?? 1) > 1
                                      ? () {
                                          setState(() {
                                            _items[index] = item.copyWith(
                                              quantity: (item.quantity ?? 1) - 1,
                                            );
                                          });
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: (item.quantity ?? 1) > 1 
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      size: 16,
                                      color: (item.quantity ?? 1) > 1 
                                          ? Colors.red[400]
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ),
                                
                                // 수량 표시
                                Container(
                                  width: 32,
                                  child: Text(
                                    '${item.quantity ?? 1}',
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
                                      _items[index] = item.copyWith(
                                        quantity: (item.quantity ?? 1) + 1,
                                      );
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
                                
                                SizedBox(width: 8),
                                
                                // 삭제 버튼
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _items.removeAt(index);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.delete_outline,
                                      size: 16,
                                      color: Colors.red[400],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          // 하단 버튼
          if (_items.isNotEmpty)
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
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: 선택된 항목들을 냉장고에 추가하는 로직
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${_items.length}개 항목이 추가되었습니다'),
                        backgroundColor: Color(0xFF6B9FFF),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6B9FFF),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '선택 항목 추가',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


