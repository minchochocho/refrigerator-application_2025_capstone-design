import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/refrigerator.dart';
import '../../services/refrigerator_service.dart';
import '../refrigerator/refrigerator_compartment_screen.dart';
import 'refrigerator_designer_screen.dart';
import 'refrigerator_compartment_customization_screen.dart';

class RefrigeratorSelectionScreen extends StatefulWidget {
  final String roomId;

  const RefrigeratorSelectionScreen({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  _RefrigeratorSelectionScreenState createState() => _RefrigeratorSelectionScreenState();
}

class _RefrigeratorSelectionScreenState extends State<RefrigeratorSelectionScreen> {
  final TextEditingController _nameController = TextEditingController();
  int? _selectedTemplateId; // 템플릿 ID로 변경
  bool _isLoading = false;
  String? _errorMessage;
  String? _roomName;
  int _refrigeratorCount = 0;
  
  // 냉장고 템플릿 정보 (모양 타입별 정보)
  final List<Map<String, dynamic>> _refrigeratorTemplates = [
    {
      'id': 1,
      'name': '1칸 냉장고',
      'compartments': ['냉장실'],
      'layout': 'single',
    },
    {
      'id': 2,
      'name': '2칸 세로 냉장고',
      'compartments': ['냉장실', '냉동실'],
      'layout': 'vertical',
    },
    {
      'id': 3,
      'name': '2칸 가로 냉장고',
      'compartments': ['냉장실 좌', '냉장실 우'],
      'layout': 'horizontal',
    },
    {
      'id': 4,
      'name': '3칸 위 두칸 냉장고',
      'compartments': ['냉장실 좌', '냉장실 우', '냉동실'],
      'layout': 'tripleTopTwo',
    },
    {
      'id': 5,
      'name': '3칸 아래 두칸 냉장고',
      'compartments': ['냉장실', '냉동실 좌', '냉동실 우'],
      'layout': 'tripleBottomTwo',
    },
    {
      'id': 6,
      'name': '4칸 냉장고',
      'compartments': ['냉장실 좌', '냉장실 우', '냉동실 좌', '냉동실 우'],
      'layout': 'quad',
    },
  ];
  
  @override
  void initState() {
    super.initState();
    _loadRoomInfo();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // 방 정보 로드 및 자동 이름 생성
  Future<void> _loadRoomInfo() async {
    try {
      // 방 정보 가져오기
      final roomDoc = await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .get();
      
      if (roomDoc.exists) {
        final roomData = roomDoc.data() as Map<String, dynamic>;
        _roomName = roomData['name'] ?? '알 수 없는 방';
      }

      // 현재 방의 냉장고 개수 세기
      final refrigeratorService = RefrigeratorService();
      final refrigerators = await refrigeratorService.getRoomRefrigerators(widget.roomId).first;
      _refrigeratorCount = refrigerators.length;

      // 자동으로 냉장고 이름 생성
      _generateAutoName();
    } catch (e) {
      print('방 정보 로드 오류: $e');
      _roomName = '알 수 없는 방';
      _generateAutoName();
    }
  }

  // 자동 냉장고 이름 생성
  void _generateAutoName() {
    if (_roomName != null) {
      final autoName = '${_roomName} 냉장고 ${_refrigeratorCount + 1}';
      setState(() {
        _nameController.text = autoName;
      });
    }
  }
  
  // 템플릿 선택 업데이트 (최적화)
  void _updateSelectedTemplate(int templateId) {
    setState(() {
      _selectedTemplateId = templateId;
    });
  }
  
  // 선택된 템플릿 가져오기
  Map<String, dynamic>? get _selectedTemplate {
    if (_selectedTemplateId == null) return null;
    try {
      return _refrigeratorTemplates.firstWhere((t) => t['id'] == _selectedTemplateId);
    } catch (e) {
      return null;
    }
  }
  
  // 칸 이름 커스터마이징으로 이동
  void _goToCompartmentCustomization() {
    if (_selectedTemplateId == null || _nameController.text.trim().isEmpty) {
      return;
    }

    final template = _refrigeratorTemplates.firstWhere(
      (t) => t['id'] == _selectedTemplateId
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RefrigeratorCompartmentCustomizationScreen(
          roomId: widget.roomId,
          refrigeratorName: _nameController.text.trim(),
          layout: template['layout'] as String,
          defaultCompartmentNames: List<String>.from(template['compartments']),
        ),
      ),
    );
  }

  // 냉장고 생성 함수 (칸 이름 커스터마이징 화면에서 호출됨)
  Future<void> _createRefrigerator() async {
    if (_selectedTemplateId == null || _nameController.text.trim().isEmpty) {
      return;
    }

    // 로딩 다이얼로그 표시 제거: UI는 스낵바와 내비게이션으로만 처리

    try {
      final template = _refrigeratorTemplates.firstWhere(
        (t) => t['id'] == _selectedTemplateId
      );

      final refrigeratorService = RefrigeratorService();
      
      // 냉장고 생성 (기본 칸 이름 사용)
      final refrigerator = await refrigeratorService.createRefrigeratorForRoom(
        widget.roomId,
        _nameController.text.trim(),
        compartmentNames: List<String>.from(template['compartments']),
        layout: template['layout'] as String,
      );

      // 다이얼로그를 사용하지 않으므로 닫기 호출 없음

      if (refrigerator != null) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('냉장고가 성공적으로 생성되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );

        // 생성 후 흐름: 그룹 탭 초기화 → 방 상세 → 냉장고 칸
        // 커스터마이즈 화면에서 이미 동일한 흐름을 제공하므로 여기선 유지
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RefrigeratorCompartmentScreen(
              roomId: widget.roomId,
              refrigeratorName: _nameController.text.trim(),
              layout: template['layout'] as String,
            ),
            settings: RouteSettings(name: '/refrigeratorCompartment'),
          ),
        );
      } else {
        // 실패 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('냉장고 생성에 실패했습니다. 다시 시도해주세요.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 다이얼로그를 사용하지 않으므로 닫기 호출 없음
      
      print('냉장고 생성 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('냉장고 생성 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '냉장고 모양 선택',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 냉장고 모양 선택 먼저 보여주기
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '냉장고 모양 선택',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_selectedTemplate != null)
                        Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 16),
                            SizedBox(width: 4),
                            Text(
                              '${_selectedTemplate!['name']} 선택됨',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: 16),
                  
                  // 1칸 냉장고
                  _buildTemplateGroup(
                    title: '1칸 냉장고',
                    templates: _refrigeratorTemplates.where((t) => t['layout'] == 'single').toList(),
                  ),
                  
                  // 2칸 냉장고
                  _buildTemplateGroup(
                    title: '2칸 냉장고',
                    templates: _refrigeratorTemplates.where((t) => 
                      t['layout'] == 'vertical' || t['layout'] == 'horizontal'
                    ).toList(),
                  ),
                  
                  // 3칸 냉장고
                  _buildTemplateGroup(
                    title: '3칸 냉장고',
                    templates: _refrigeratorTemplates.where((t) => 
                      t['layout'] == 'tripleTopTwo' || t['layout'] == 'tripleBottomTwo'
                    ).toList(),
                  ),
                  
                  // 4칸 냉장고
                  _buildTemplateGroup(
                    title: '4칸 냉장고',
                    templates: _refrigeratorTemplates.where((t) => t['layout'] == 'quad').toList(),
                  ),

                  // 모양 선택 후 냉장고 이름 입력하도록 배치 변경
                  SizedBox(height: 32),
                  
                  // 냉장고 이름 입력
                  Text(
                    '냉장고 이름',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: '냉장고 이름을 입력하세요',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) {
                      // 텍스트 변경 시 화면 갱신하여 버튼 활성화 상태 업데이트
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
          
          // 다음 단계 버튼
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedTemplateId == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      '※ 냉장고 모양을 선택해주세요',
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                if (_selectedTemplateId != null && _nameController.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      '※ 냉장고 이름을 입력해주세요',
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                ElevatedButton(
                  onPressed: (_selectedTemplateId == null || _nameController.text.trim().isEmpty)
                      ? null
                      : () {
                          _goToCompartmentCustomization();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(
                    '다음 단계',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // 템플릿 그룹 위젯
  Widget _buildTemplateGroup({
    required String title,
    required List<Map<String, dynamic>> templates,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        SizedBox(height: 12),
        Container(
          height: 180, // 높이를 줄여서 더 컴팩트하게
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              final isSelected = _selectedTemplateId == template['id'];
              
              return Container(
                width: 140, // 너비도 줄여서 더 많이 보이게
                margin: EdgeInsets.only(right: 12),
                child: Card(
                  elevation: isSelected ? 6 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? Colors.blue.shade600 : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => _updateSelectedTemplate(template['id'] as int),
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 냉장고 미리보기 (크기 최적화)
                              Container(
                                height: 100, // 미리보기 높이 줄임
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected ? Colors.blue.shade400 : Colors.grey.shade300,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: _buildLayoutPreview(
                                  template['layout'] as String,
                                  isSelected: isSelected,
                                ),
                              ),
                              SizedBox(height: 8), // 간격 줄임
                              
                              // 템플릿 이름 (텍스트 최적화)
                              Text(
                                template['name'],
                                style: TextStyle(
                                  fontSize: 12, // 폰트 크기 줄임
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected ? Colors.blue.shade800 : Colors.black87,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 2),
                              Text(
                                '${(template['compartments'] as List).length}칸',
                                style: TextStyle(
                                  fontSize: 10, // 폰트 크기 줄임
                                  color: isSelected ? Colors.blue.shade600 : Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 선택 표시자
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 24),
      ],
    );
  }
  
  // 공통 컨테이너 빌더 (코드 최적화)
  Widget _buildCompartmentContainer(Color baseColor, Color borderColor) {
    return Container(
      margin: EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: 1),
      ),
    );
  }

  // 레이아웃 미리보기 위젯 (최적화)
  Widget _buildLayoutPreview(String layout, {bool isSelected = false}) {
    final Color baseColor = isSelected ? Colors.blue.shade50 : Colors.grey.shade100;
    final Color borderColor = isSelected ? Colors.blue.shade400 : Colors.grey.shade400;
    
    switch (layout) {
      case 'single':
        return Container(
          margin: EdgeInsets.all(8), // 마진 늘려서 여백 확보
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor, width: 1.5),
          ),
        );
        
      case 'vertical':
        return Column(
          children: [
            Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
            Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
          ],
        );
        
      case 'horizontal':
        return Row(
          children: [
            Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
            Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
          ],
        );
        
      case 'tripleTopTwo':
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
                  Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
                ],
              ),
            ),
            Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
          ],
        );
        
      case 'tripleBottomTwo':
        return Column(
          children: [
            Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
                  Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
                ],
              ),
            ),
          ],
        );
        
      case 'quad':
        return Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
                  Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
                  Expanded(child: _buildCompartmentContainer(baseColor, borderColor)),
                ],
              ),
            ),
          ],
        );
        
      default:
        return Container();
    }
  }

} 