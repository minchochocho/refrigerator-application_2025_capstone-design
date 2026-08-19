import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../../services/image_edit_service.dart';
import '../../../date_recognition/camera_screen.dart';
import '../widgets/ingredient_image_widget.dart';
import '../../../widgets/ingredients/scroll_date_picker_dialog.dart';
import 'date_field_widget.dart';

// 점선 구분선 (스크린샷과 동일한 느낌)
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

/// 재료 추가/수정 다이얼로그
class AddIngredientDialog extends StatefulWidget {
  final String compartmentName;
  final List<String>? availableCompartments; // 선택 가능한 칸 목록
  final Future<void> Function({
    required String name,
    required int quantity,
    DateTime? expiryDate,
    DateTime? manufactureDate,
    DateTime? registrationDate,
    String? memo,
    String? imagePath,
    String? compartmentName, // 선택된 칸 이름
  }) onAdd;
  
  // 수정 모드용 필드
  final bool isEditMode;
  final Map<String, dynamic>? existingIngredient;
  
  const AddIngredientDialog({
    Key? key,
    required this.compartmentName,
    this.availableCompartments,
    required this.onAdd,
    this.isEditMode = false,
    this.existingIngredient,
  }) : super(key: key);
  
  @override
  State<AddIngredientDialog> createState() => _AddIngredientDialogState();
}

class _AddIngredientDialogState extends State<AddIngredientDialog> {
  late final TextEditingController nameController;
  late final TextEditingController quantityController;
  late final TextEditingController expiryDateController;
  late final TextEditingController manufactureDateController;
  late final TextEditingController registrationDateController;
  late final TextEditingController memoController;
  
  DateTime? selectedExpiryDate;
  DateTime? selectedManufactureDate;
  DateTime? selectedRegistrationDate;
  String? selectedImagePath;
  String? selectedCompartment;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    
    // 현재 칸을 선택된 칸으로 먼저 설정 (중요!)
    selectedCompartment = widget.compartmentName;
    
    // 수정 모드인 경우 기존 데이터로 초기화
    if (widget.isEditMode && widget.existingIngredient != null) {
      final ingredient = widget.existingIngredient!;
      
      nameController = TextEditingController(text: ingredient['name'] ?? '');
      quantityController = TextEditingController(text: (ingredient['quantity'] ?? 1).toString());
      memoController = TextEditingController(text: ingredient['memo'] ?? '');
      // 이미지 경로 또는 URL 가져오기
      selectedImagePath = ingredient['imagePath'] ?? ingredient['imageUrl'];
      
      // 날짜 데이터 파싱 (타임존 변환)
      if (ingredient['expiryDate'] is Timestamp) {
        final utcDate = (ingredient['expiryDate'] as Timestamp).toDate();
        selectedExpiryDate = utcDate.add(Duration(hours: 9));
      }
      
      if (ingredient['manufactureDate'] is Timestamp) {
        final utcDate = (ingredient['manufactureDate'] as Timestamp).toDate();
        selectedManufactureDate = utcDate.add(Duration(hours: 9));
      }
      
      if (ingredient['registrationDate'] is Timestamp) {
        final utcDate = (ingredient['registrationDate'] as Timestamp).toDate();
        selectedRegistrationDate = utcDate.add(Duration(hours: 9));
      } else {
        selectedRegistrationDate = DateTime.now();
      }
      
      expiryDateController = TextEditingController(
        text: selectedExpiryDate != null ? _formatKoreanDate(selectedExpiryDate!) : ''
      );
      manufactureDateController = TextEditingController(
        text: selectedManufactureDate != null ? _formatKoreanDate(selectedManufactureDate!) : ''
      );
      registrationDateController = TextEditingController(
        text: selectedRegistrationDate != null 
            ? _formatKoreanDate(selectedRegistrationDate!)
            : _formatKoreanDate(DateTime.now())
      );
    } else {
      // 추가 모드 - 기본값
      nameController = TextEditingController();
      quantityController = TextEditingController(text: '1');
      expiryDateController = TextEditingController();
      manufactureDateController = TextEditingController();
      registrationDateController = TextEditingController(
        text: '${DateTime.now().year}. ${DateTime.now().month.toString().padLeft(2, '0')}. ${DateTime.now().day.toString().padLeft(2, '0')}',
      );
      memoController = TextEditingController();
      selectedRegistrationDate = DateTime.now();
      // selectedCompartment는 이미 위에서 설정됨
    }
    
    // 디버그: 초기화된 칸 이름 확인
    print('✅ 다이얼로그 초기화: compartmentName = ${widget.compartmentName}, selectedCompartment = $selectedCompartment');
  }

  DateTime? _tryParseDate(String input) {
    try {
      final cleaned = input.replaceAll('유통기한:', '').trim();
      // 1) yyyy-MM-dd, yyyy.MM.dd, yyyy/MM/dd
      final sepMatch = RegExp(r'^(\d{4})[./-](\d{1,2})[./-](\d{1,2})$').firstMatch(cleaned);
      if (sepMatch != null) {
        final y = int.parse(sepMatch.group(1)!);
        final m = int.parse(sepMatch.group(2)!);
        final d = int.parse(sepMatch.group(3)!);
        return DateTime(y, m, d);
      }
      // 2) yyyy년 MM월 dd일
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
            widget.isEditMode ? '식품 정보 수정' : '식품 추가',
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
          child: selectedImagePath != null && selectedImagePath!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      IngredientImageWidget(
                        imagePath: selectedImagePath!,
                        width: 60,
                        height: 60,
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => selectedImagePath = null),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickAndCropImage,
                    borderRadius: BorderRadius.circular(8),
                    child: Center(
                      child: Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400], size: 26),
                    ),
                  ),
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
                  // 현재 선택된 항목 제외
                  final availableCompartments = compartments
                      .where((c) => c != (selectedCompartment ?? widget.compartmentName))
                      .toList();
                  
                  // 선택 가능한 칸이 없으면 빈 리스트 반환
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
                enabled: compartments.length > 1, // 칸이 2개 이상일 때만 활성화
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
          isReadOnly: widget.isEditMode ? false : true, // 수정 모드에서는 변경 가능
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
          firstDate: DateTime(1900), // 과거 모든 날짜 선택 가능
          lastDate: DateTime.now().add(Duration(days: 365 * 10)), // 미래 날짜도 선택 가능
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
    bool isReadOnly = false, // 선택 불가 옵션 추가
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

    // 기본 캘린더 날짜 선택 (식품추가 UI 스타일)
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
                primary: Color(0xFF3B82F6), // 헤더 배경색
                onPrimary: Colors.white, // 헤더 텍스트 색
                onSurface: Colors.black87, // 본문 텍스트 색
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
              // 캘린더 아이콘 (기본 캘린더 열기)
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
              // 날짜 표시 캡슐 (스크롤 날짜 선택)
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
                  widget.isEditMode ? '저장' : '추가',
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
      await showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        builder: (context) => ScaleTransition(
          scale: CurvedAnimation(
            parent: AnimationController(
              duration: Duration(milliseconds: 200),
              vsync: Navigator.of(context),
            )..forward(),
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: AnimationController(
                duration: Duration(milliseconds: 150),
                vsync: Navigator.of(context),
              )..forward(),
              curve: Curves.easeOut,
            ),
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                constraints: BoxConstraints(maxWidth: 280),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 아이콘
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(0xFF3B82F6).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: Color(0xFF3B82F6),
                        size: 26,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // 메시지
                    Text(
                      '제품명을 입력해주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    // 확인 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          '확인',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }
    
    int? quantity = int.tryParse(quantityController.text);
    if (quantity == null || quantity <= 0) {
      await showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        builder: (context) => ScaleTransition(
          scale: CurvedAnimation(
            parent: AnimationController(
              duration: Duration(milliseconds: 200),
              vsync: Navigator.of(context),
            )..forward(),
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: AnimationController(
                duration: Duration(milliseconds: 150),
                vsync: Navigator.of(context),
              )..forward(),
              curve: Curves.easeOut,
            ),
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: EdgeInsets.all(20),
                constraints: BoxConstraints(maxWidth: 280),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 아이콘
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(0xFF3B82F6).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline,
                        color: Color(0xFF3B82F6),
                        size: 26,
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // 메시지
                    Text(
                      '유효한 개수를 입력해주세요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 20),
                    
                    // 확인 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          '확인',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    // 중복 제출 방지: 실제 추가 로직 전에 잠금
    setState(() {
      _isSubmitting = true;
    });

    // 만약 선택된 날짜가 없고 텍스트만 있다면 파싱 시도 (OCR/수기 입력 보완)
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
      imagePath: selectedImagePath,
      compartmentName: selectedCompartment ?? widget.compartmentName, // 선택된 칸 전달
    );

    Navigator.pop(context);
  }

  
  Future<void> _pickAndCropImage() async {
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('이미지 선택'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('카메라로 촬영'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('갤러리에서 선택'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
            ],
          );
        },
      );

      if (source == null) return;

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 90);
      if (pickedFile == null) return;

      final editor = ImageEditService();
      final editedFile = await editor.openCropEditor(
        context: context,
        imageFile: File(pickedFile.path),
      );

      if (editedFile != null) {
        setState(() {
          selectedImagePath = editedFile.path;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
      );
    }
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

