import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../barcode_system/barcode_model.dart';
import '../../../date_recognition/camera_screen.dart';
import '../../../widgets/ingredients/scroll_date_picker_dialog.dart';
import 'date_field_widget.dart';

/// 바코드 제품 이미지 표시 위젯
class BarcodeProductImage extends StatelessWidget {
  final BarcodeModel barcode;
  final double? width;
  final double? height;
  
  const BarcodeProductImage({
    Key? key,
    required this.barcode,
    this.width,
    this.height,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (barcode.imageUrl.isNotEmpty && barcode.imageUrl != '') {
      if (barcode.isLocalImage) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            barcode.assetPath,
            fit: BoxFit.cover,
            width: width ?? double.infinity,
            height: height ?? double.infinity,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          ),
        );
      } else {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: barcode.imageUrl,
            fit: BoxFit.cover,
            width: width ?? double.infinity,
            height: height ?? double.infinity,
            placeholder: (context, url) => Container(
              child: Center(child: CircularProgressIndicator()),
            ),
            errorWidget: (context, url, error) => _buildPlaceholder(),
          ),
        );
      }
    } else {
      return _buildPlaceholder();
    }
  }
  
  Widget _buildPlaceholder() {
    return Container(
      width: width ?? double.infinity,
      height: height ?? double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, color: Colors.grey[400], size: 48),
          SizedBox(height: 8),
          Text(
            '제품 이미지',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }
}

/// 바코드 상세보기 다이얼로그
class BarcodeDetailDialog extends StatelessWidget {
  final BarcodeModel barcode;
  
  const BarcodeDetailDialog({
    Key? key,
    required this.barcode,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
          maxWidth: MediaQuery.of(context).size.width * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 200,
                      child: BarcodeProductImage(barcode: barcode),
                    ),
                    SizedBox(height: 20),
                    _buildInfoCard(
                      title: '제품 정보',
                      children: [
                        _buildDetailRow('제품명', barcode.barcodeType == 'CODE-128' ? '신선제품' : (barcode.foodName.isNotEmpty ? barcode.foodName : '알 수 없는 제품')),
                        if (barcode.expirationDate.isNotEmpty)
                          _buildDetailRow('유통기한', barcode.expirationDate),
                      ],
                    ),
                    SizedBox(height: 16),
                    _buildInfoCard(
                      title: '바코드 정보',
                      children: [
                        _buildDetailRow('바코드 번호', barcode.barcodeId),
                        _buildDetailRow('바코드 타입', barcode.barcodeType),
                        _buildDetailRow('스캔 날짜', barcode.formattedDate),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text('닫기'),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('재료 추가하기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[400]!, Colors.green[600]!],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.qr_code, color: Colors.white, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            '바코드 상세 정보',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.close, color: Colors.grey[600]),
        ),
      ],
    );
  }
  
  Widget _buildInfoCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }
}

/// 바코드로부터 재료 추가 다이얼로그
class AddIngredientFromBarcodeDialog extends StatefulWidget {
  final BarcodeModel barcode;
  final String compartmentName;
  final List<String>? availableCompartments;
  final Future<void> Function({
    required String name,
    required int quantity,
    DateTime? expiryDate,
    DateTime? manufactureDate,
    DateTime? registrationDate,
    String? memo,
    String? imagePath,
    String? compartmentName,
  }) onAdd;
  final VoidCallback onShowDetail;
  
  const AddIngredientFromBarcodeDialog({
    Key? key,
    required this.barcode,
    required this.compartmentName,
    this.availableCompartments,
    required this.onAdd,
    required this.onShowDetail,
  }) : super(key: key);
  
  @override
  State<AddIngredientFromBarcodeDialog> createState() => _AddIngredientFromBarcodeDialogState();
}

class _AddIngredientFromBarcodeDialogState extends State<AddIngredientFromBarcodeDialog> {
  late TextEditingController nameController;
  late TextEditingController quantityController;
  late TextEditingController expiryDateController;
  late TextEditingController manufactureDateController;
  late TextEditingController registrationDateController;
  late TextEditingController memoController;
  bool _isSubmitting = false;
  
  DateTime? selectedExpiryDate;
  DateTime? selectedManufactureDate;
  DateTime? selectedRegistrationDate;
  String? selectedCompartment;
  
  DateTime? _tryParseDate(String input) {
    try {
      final cleaned = input.replaceAll('유통기한:', '').trim();
      // yyyy-MM-dd, yyyy.MM.dd, yyyy/MM/dd
      final sepMatch = RegExp(r'^(\d{4})[./-](\d{1,2})[./-](\d{1,2})$').firstMatch(cleaned);
      if (sepMatch != null) {
        final y = int.parse(sepMatch.group(1)!);
        final m = int.parse(sepMatch.group(2)!);
        final d = int.parse(sepMatch.group(3)!);
        return DateTime(y, m, d);
      }
      // yyyy년 MM월 dd일
      final krMatch = RegExp(r'^(\d{4})\s*년\s*(\d{1,2})\s*월\s*(\d{1,2})\s*일$').firstMatch(cleaned);
      if (krMatch != null) {
        final y = int.parse(krMatch.group(1)!);
        final m = int.parse(krMatch.group(2)!);
        final d = int.parse(krMatch.group(3)!);
        return DateTime(y, m, d);
      }
    } catch (_) {}
    return null;
  }
  
  String _formatKoreanDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}. ${two(date.month)}. ${two(date.day)}';
  }
  
  @override
  void initState() {
    super.initState();
    
    // 현재 칸을 선택된 칸으로 설정
    selectedCompartment = widget.compartmentName;
    selectedRegistrationDate = DateTime.now();
    
    nameController = TextEditingController(
      text: widget.barcode.barcodeType == 'CODE-128'
          ? '신선제품'
          : (widget.barcode.foodName.isNotEmpty ? widget.barcode.foodName : '알 수 없는 제품')
    );
    quantityController = TextEditingController(text: '1');
    memoController = TextEditingController();
    
    // 유통기한 초기화
    final initialExpiry = widget.barcode.expirationDate;
    final parsed = initialExpiry.isNotEmpty ? _tryParseDate(initialExpiry) : null;
    if (parsed != null) {
      selectedExpiryDate = parsed;
      expiryDateController = TextEditingController(text: _formatKoreanDate(parsed));
    } else {
      expiryDateController = TextEditingController(text: initialExpiry);
    }
    
    manufactureDateController = TextEditingController();
    registrationDateController = TextEditingController(
      text: _formatKoreanDate(DateTime.now())
    );
  }
  
  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    expiryDateController.dispose();
    manufactureDateController.dispose();
    registrationDateController.dispose();
    memoController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
          maxWidth: 400,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      Container(
                        color: Colors.white,
                        padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildImageAndNameSection(),
                            SizedBox(height: 16),
                            _buildStorageAndQuantitySection(),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: _DashedDivider(),
                      ),
                      Container(
                        color: Colors.white,
                        padding: EdgeInsets.fromLTRB(24, 16, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildDateSection(),
                          ],
                        ),
                      ),
                      Container(
                        color: Colors.white,
                        padding: EdgeInsets.fromLTRB(24, 16, 24, 20),
                        child: _buildMemoSection(),
                      ),
                    ],
                  ),
                ),
              ),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back, color: Colors.black, size: 24),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
          ),
          SizedBox(width: 12),
          Text(
            '식품 추가',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageAndNameSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 이미지
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFFE0E0E0)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: BarcodeProductImage(barcode: widget.barcode),
          ),
        ),
        SizedBox(width: 16),
        // 식품명
        Expanded(
          child: TextField(
            controller: nameController,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
            decoration: InputDecoration(
              hintText: '식품명을 입력하세요',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 16, fontWeight: FontWeight.w500),
              contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 8),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF3B82F6), width: 2),
              ),
              counterText: '',
            ),
            maxLength: 30,
          ),
        ),
      ],
    );
  }

  Widget _buildStorageAndQuantitySection() {
    final compartments = widget.availableCompartments ?? [widget.compartmentName];
    
    return Column(
      children: [
        // 보관 장소
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '보관 장소',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(
                popupMenuTheme: PopupMenuThemeData(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  color: Colors.white,
                  elevation: 12,
                  shadowColor: Colors.black.withOpacity(0.2),
                ),
              ),
              child: PopupMenuButton<String>(
                initialValue: selectedCompartment ?? widget.compartmentName,
                onSelected: (String value) {
                  if (mounted) {
                    setState(() {
                      selectedCompartment = value;
                    });
                  }
                },
                offset: Offset(0, 42),
                constraints: BoxConstraints(
                  minWidth: 176,
                  maxWidth: 176,
                ),
                itemBuilder: (BuildContext context) {
                  final availableCompartments = compartments
                      .where((c) => c != (selectedCompartment ?? widget.compartmentName))
                      .toList();
                  
                  if (availableCompartments.isEmpty) {
                    return [
                      PopupMenuItem<String>(
                        enabled: false,
                        child: Text(
                          '다른 보관 장소가 없습니다',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ];
                  }
                  
                  return availableCompartments.map((String compartment) {
                    return PopupMenuItem<String>(
                      value: compartment,
                      height: 44,
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        compartment,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList();
                },
                enabled: compartments.length > 1,
                child: Container(
                  width: 176,
                  height: 36,
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: compartments.length > 1 ? Color(0xFFE9ECEF) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedCompartment ?? widget.compartmentName,
                          style: TextStyle(
                            fontSize: 15, 
                            color: compartments.length > 1 ? Colors.black87 : Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (compartments.length > 1)
                        Icon(
                          Icons.keyboard_arrow_down,
                          size: 20,
                          color: Colors.black54,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        // 수량
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '수량',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    int current = int.tryParse(quantityController.text) ?? 1;
                    if (current > 1) {
                      quantityController.text = (current - 1).toString();
                    }
                  },
                  icon: Icon(Icons.remove_circle_outline, color: Color(0xFF3B82F6), size: 24),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                SizedBox(width: 12),
                SizedBox(
                  width: 24,
                  child: TextField(
                    controller: quantityController,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                IconButton(
                  onPressed: () {
                    int current = int.tryParse(quantityController.text) ?? 1;
                    quantityController.text = (current + 1).toString();
                  },
                  icon: Icon(Icons.add_circle, color: Color(0xFF3B82F6), size: 24),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: InkWell(
            onTap: () {
              setState(() {
                selectedRegistrationDate = null;
                registrationDateController.clear();
                selectedManufactureDate = null;
                manufactureDateController.clear();
                selectedExpiryDate = null;
                expiryDateController.clear();
              });
            },
            child: Text(
              '초기화',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        _buildDateField(
          label: '등록일',
          controller: registrationDateController,
          selectedDate: selectedRegistrationDate,
          onDateSelected: (date) {
            setState(() {
              selectedRegistrationDate = date;
            });
          },
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(Duration(days: 365)),
          isReadOnly: true,
        ),
        _buildDateField(
          label: '제조일',
          controller: manufactureDateController,
          selectedDate: selectedManufactureDate,
          onDateSelected: (date) {
            setState(() {
              selectedManufactureDate = date;
            });
          },
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime.now().add(Duration(days: 365 * 10)),
        ),
        _buildDateField(
          label: '유통기한',
          controller: expiryDateController,
          selectedDate: selectedExpiryDate,
          onDateSelected: (date) {
            setState(() {
              selectedExpiryDate = date;
            });
          },
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(Duration(days: 365 * 5)),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Spacer(),
            InkWell(
              onTap: () => _openDateRecognitionCamera(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 176,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  '카메라로 유통기한 인식',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required TextEditingController controller,
    required DateTime? selectedDate,
    required Function(DateTime) onDateSelected,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
    bool isReadOnly = false,
  }) {
    // 스크롤 날짜 선택 다이얼로그
    void _showScrollDatePicker() {
      showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return ScrollDatePickerDialog(
            currentDate: selectedDate ?? initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
            onDateSelected: (date) {
              onDateSelected(date);
              controller.text = _formatKoreanDate(date);
            },
          );
        },
      );
    }

    // 기본 캘린더 날짜 선택
    void _showCalendarDatePicker() async {
      final date = await showDatePicker(
        context: context,
        initialDate: selectedDate ?? initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Color(0xFF3B82F6),
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
              datePickerTheme: DatePickerThemeData(
                backgroundColor: Colors.white,
                headerBackgroundColor: Color(0xFF3B82F6),
                headerForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                dayStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                weekdayStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
                dayForegroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return Colors.white;
                  }
                  if (states.contains(MaterialState.disabled)) {
                    return Colors.grey[400];
                  }
                  return Colors.black87;
                }),
                dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return Color(0xFF3B82F6);
                  }
                  return null;
                }),
                todayForegroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return Colors.white;
                  }
                  return Color(0xFF3B82F6);
                }),
                todayBackgroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return Color(0xFF3B82F6);
                  }
                  return Colors.transparent;
                }),
                todayBorder: BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                yearForegroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return Colors.white;
                  }
                  return Colors.black87;
                }),
                yearBackgroundColor: MaterialStateProperty.resolveWith((states) {
                  if (states.contains(MaterialState.selected)) {
                    return Color(0xFF3B82F6);
                  }
                  return null;
                }),
                headerHelpStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                headerHeadlineStyle: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: Color(0xFF3B82F6),
                  textStyle: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            child: child!,
          );
        },
      );
      if (date != null) {
        onDateSelected(date);
        controller.text = _formatKoreanDate(date);
      }
    }

    // 날짜 지우기 함수 (제조일, 유통기한만)
    final bool isManufactureOrExpiry = (label == '제조일' || label == '유통기한');

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              // 캘린더 아이콘
              InkWell(
                onTap: isReadOnly ? null : _showCalendarDatePicker,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isReadOnly ? Colors.grey[300]! : Color(0xFFD7E3FC)),
                    color: isReadOnly ? Colors.grey[200] : Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.calendar_today_outlined, 
                    size: 14, 
                    color: isReadOnly ? Colors.grey[400] : Color(0xFF3B82F6),
                  ),
                ),
              ),
              SizedBox(width: 8),
              // 날짜 표시 캡슐
              InkWell(
                onTap: isReadOnly ? null : _showScrollDatePicker,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 140,
                  height: 36,
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isReadOnly ? Colors.grey[200] : Color(0xFFE9ECEF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (selectedDate != null ? _formatKoreanDate(selectedDate) : ''),
                    style: TextStyle(
                      fontSize: 15, 
                      color: isReadOnly ? Colors.grey[500] : Colors.black87, 
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              // X 버튼 (제조일, 유통기한만, 항상 표시, 테두리 없음)
              if (isManufactureOrExpiry)
                Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: InkWell(
                    onTap: selectedDate != null ? () {
                      setState(() {
                        if (label == '제조일') {
                          selectedManufactureDate = null;
                          manufactureDateController.clear();
                        } else if (label == '유통기한') {
                          selectedExpiryDate = null;
                          expiryDateController.clear();
                        }
                      });
                    } : null,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.close, 
                        size: 20, 
                        color: selectedDate != null ? Colors.grey[500] : Colors.grey[300],
                      ),
                    ),
                  ),
                )
              else
                // 등록일에는 X 버튼 공간만큼 여백 추가
                SizedBox(width: 36), // 8px 간격 + 28px 버튼
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '메모',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 10),
        Container(
          height: 140,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: memoController,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            maxLength: 100,
            style: TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: '',
              hintStyle: TextStyle(color: Colors.grey[400]),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButtons(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '취소',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _handleAdd(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '추가',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _handleAdd(BuildContext context) async {
    if (_isSubmitting) return;
    if (nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('제품명을 입력해주세요')),
      );
      return;
    }
    
    int? quantity = int.tryParse(quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('유효한 개수를 입력해주세요')),
      );
      return;
    }

    // 중복 제출 방지: 실제 추가 로직 전에 잠금
    setState(() {
      _isSubmitting = true;
    });

    // 만약 선택된 날짜가 없고 텍스트만 있다면 파싱 시도
    if (selectedExpiryDate == null && expiryDateController.text.trim().isNotEmpty) {
      final parsed = _tryParseDate(expiryDateController.text.trim());
      if (parsed != null) selectedExpiryDate = parsed;
    }

    // 추가 로직은 백그라운드에서 진행하고, 다이얼로그는 바로 닫음
    final _ = widget.onAdd(
      name: nameController.text.trim(),
      quantity: quantity,
      expiryDate: selectedExpiryDate,
      manufactureDate: selectedManufactureDate,
      registrationDate: selectedRegistrationDate,
      memo: memoController.text.trim(),
      imagePath: widget.barcode.imageUrl,
      compartmentName: selectedCompartment ?? widget.compartmentName,
    );

    Navigator.pop(context);
  }
  
  Future<void> _openDateRecognitionCamera(BuildContext context) async {
    try {
      final cameras = await availableCameras();
      
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용 가능한 카메라가 없습니다')),
        );
        return;
      }

      // 카메라 화면으로 이동
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DateRecognitionCameraScreen(
            cameras: cameras,
            onDateRecognized: (recognizedDate) {
              setState(() {
                final parsed = _tryParseDate(recognizedDate);
                if (parsed != null) {
                  selectedExpiryDate = parsed;
                  expiryDateController.text = _formatKoreanDate(parsed);
                } else {
                  // 파싱 실패 시 원문 표시
                  expiryDateController.text = recognizedDate;
                }
              });
            },
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

// Dashed divider widget
class _DashedDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const _DashedDivider({
    this.height = 1,
    this.color = const Color(0xFFE0E0E0),
    this.dashWidth = 4,
    this.dashSpace = 4,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final int dashCount = (constraints.maxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashCount,
            (_) => SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[300]!
      ..strokeWidth = 1;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
