import 'package:flutter/material.dart';
import '../../services/refrigerator_service.dart';
import '../../models/refrigerator.dart';

class RefrigeratorCompartmentSettingsScreen extends StatefulWidget {
  final String roomId;
  final String refrigeratorName;

  const RefrigeratorCompartmentSettingsScreen({
    Key? key,
    required this.roomId,
    required this.refrigeratorName,
  }) : super(key: key);

  @override
  _RefrigeratorCompartmentSettingsScreenState createState() => _RefrigeratorCompartmentSettingsScreenState();
}

class _RefrigeratorCompartmentSettingsScreenState extends State<RefrigeratorCompartmentSettingsScreen> {
  final RefrigeratorService _refrigeratorService = RefrigeratorService();
  final List<TextEditingController> _controllers = [];
  Refrigerator? _refrigerator;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadRefrigeratorData();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // 냉장고 데이터 로드
  Future<void> _loadRefrigeratorData() async {
    try {
      final refrigerator = await _refrigeratorService.getRefrigeratorByRoomAndName(
        widget.roomId,
        widget.refrigeratorName,
      );

      if (refrigerator != null) {
        setState(() {
          _refrigerator = refrigerator;
          _isLoading = false;
        });

        // 컨트롤러 초기화
        _initializeControllers();
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('냉장고 정보를 불러올 수 없습니다.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('데이터 로드 중 오류가 발생했습니다: $e');
    }
  }

  // 컨트롤러 초기화
  void _initializeControllers() {
    _controllers.clear();
    for (String compartmentName in _refrigerator!.compartmentNames) {
      _controllers.add(TextEditingController(text: compartmentName));
    }
  }

  // 칸 이름 저장
  Future<void> _saveCompartmentNames() async {
    if (_isSaving) return;

    // 유효성 검사
    List<String> newNames = _controllers.map((controller) => controller.text.trim()).toList();
    
    if (newNames.any((name) => name.isEmpty)) {
      _showErrorSnackBar('모든 칸의 이름을 입력해주세요.');
      return;
    }

    // 중복 이름 검사
    Set<String> uniqueNames = newNames.toSet();
    if (uniqueNames.length != newNames.length) {
      _showErrorSnackBar('칸 이름은 중복될 수 없습니다.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      bool success = await _refrigeratorService.updateCompartmentNames(
        widget.roomId,
        widget.refrigeratorName,
        newNames,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('칸 이름이 저장되었습니다'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // 저장 성공을 알리며 화면 닫기
      } else {
        _showErrorSnackBar('칸 이름 저장에 실패했습니다.');
      }
    } catch (e) {
      _showErrorSnackBar('저장 중 오류가 발생했습니다: $e');
    }

    setState(() {
      _isSaving = false;
    });
  }

  // 에러 스낵바 표시
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 칸 타입에 따른 색상 설정
  Color _getCompartmentColor(String name) {
    if (name.contains('냉동')) {
      return Colors.blue.shade50;
    } else {
      return Colors.green.shade50;
    }
  }

  // 칸 타입에 따른 테두리 색상
  Color _getCompartmentBorderColor(String name) {
    if (name.contains('냉동')) {
      return Colors.blue.shade400;
    } else {
      return Colors.green.shade400;
    }
  }

  // 칸 타입에 따른 아이콘
  IconData _getCompartmentIcon(String name) {
    if (name.contains('냉동')) {
      return Icons.ac_unit;
    } else {
      return Icons.kitchen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '냉장고 칸 설정',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveCompartmentNames,
              child: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                  : Text(
                      '저장',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('냉장고 정보를 불러오는 중...'),
                ],
              ),
            )
          : _refrigerator == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        '냉장고 정보를 찾을 수 없습니다',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더 정보
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[400]!, Colors.blue[600]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.kitchen, color: Colors.white, size: 24),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.refrigeratorName,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${_refrigerator!.compartmentNames.length}개의 칸',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // 안내 텍스트
                      Text(
                        '칸 이름 편집',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '각 칸의 이름을 자유롭게 변경할 수 있습니다. 칸 이름은 중복될 수 없습니다.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),

                      SizedBox(height: 20),

                      // 칸 이름 편집 목록
                      ...List.generate(_controllers.length, (index) {
                        final currentName = _refrigerator!.compartmentNames[index];
                        return Container(
                          margin: EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '칸 ${index + 1}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: _getCompartmentColor(currentName),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _getCompartmentBorderColor(currentName),
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: _controllers[index],
                                  decoration: InputDecoration(
                                    prefixIcon: Icon(
                                      _getCompartmentIcon(currentName),
                                      color: _getCompartmentBorderColor(currentName),
                                    ),
                                    hintText: '칸 이름을 입력하세요',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 16,
                                    ),
                                    filled: true,
                                    fillColor: Colors.transparent,
                                  ),
                                  maxLength: 20,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      SizedBox(height: 20),

                      // 주의사항
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber.shade700,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '주의사항',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    '• 칸 이름은 중복될 수 없습니다\n• 최대 20자까지 입력 가능합니다\n• 변경 후 저장 버튼을 누르세요',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.amber.shade700,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
} 