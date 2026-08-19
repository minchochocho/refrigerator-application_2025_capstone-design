import 'package:flutter/material.dart';
import '../../services/refrigerator_service.dart';
import 'refrigerator_compartment_screen.dart';

class RefrigeratorCompartmentCustomizationScreen extends StatefulWidget {
  final String roomId;
  final String refrigeratorName;
  final String layout;
  final List<String> defaultCompartmentNames;

  const RefrigeratorCompartmentCustomizationScreen({
    Key? key,
    required this.roomId,
    required this.refrigeratorName,
    required this.layout,
    required this.defaultCompartmentNames,
  }) : super(key: key);

  @override
  _RefrigeratorCompartmentCustomizationScreenState createState() => _RefrigeratorCompartmentCustomizationScreenState();
}

class _RefrigeratorCompartmentCustomizationScreenState extends State<RefrigeratorCompartmentCustomizationScreen> {
  final RefrigeratorService _refrigeratorService = RefrigeratorService();
  final List<TextEditingController> _controllers = [];
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  // 컨트롤러 초기화
  void _initializeControllers() {
    for (String name in widget.defaultCompartmentNames) {
      _controllers.add(TextEditingController(text: name));
    }
  }

  // 냉장고 생성
  Future<void> _createRefrigerator() async {
    if (_isCreating) return;

    // 유효성 검사
    List<String> compartmentNames = _controllers.map((controller) => controller.text.trim()).toList();
    
    if (compartmentNames.any((name) => name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('모든 칸의 이름을 입력해주세요')),
      );
      return;
    }

    // 중복 이름 검사
    Set<String> uniqueNames = compartmentNames.toSet();
    if (uniqueNames.length != compartmentNames.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('칸 이름은 중복될 수 없습니다')),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    // 로딩 다이얼로그 표시 제거: 버튼 비활성화 상태만 유지

    try {
      // 냉장고 생성
      final refrigerator = await _refrigeratorService.createRefrigeratorForRoom(
        widget.roomId,
        widget.refrigeratorName,
        compartmentNames: compartmentNames,
        layout: widget.layout,
      );

      // 다이얼로그를 사용하지 않으므로 닫기 호출 없음

      if (refrigerator != null) {
        // 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('냉장고가 성공적으로 생성되었습니다!'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
          ),
        );

        // 현재 탭(내부 네비게이터)에서 다음 화면으로 전환
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RefrigeratorCompartmentScreen(
              roomId: widget.roomId,
              refrigeratorName: widget.refrigeratorName,
              layout: widget.layout,
            ),
          ),
        );
      } else {
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

    setState(() {
      _isCreating = false;
    });
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

  // 냉장고 모양 레이아웃 빌드 (실제 냉장고 화면과 동일)
  Widget _buildRefrigeratorLayout() {
    if (_controllers.isEmpty) return SizedBox();

    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 16),  // 좌우 여백 넉넉하게
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[400]!, width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(12),  // 내부 패딩 넉넉하게
        child: AspectRatio(
          aspectRatio: _getRefrigeratorAspectRatio(),
          child: _buildRealRefrigeratorLayout(),
        ),
      ),
    );
  }

  // 냉장고 가로세로 비율 설정 (W:H)
  double _getRefrigeratorAspectRatio() {
    switch (widget.layout) {
      case 'single':
        return 3/4;
      case 'horizontal':
        return 3/4;  // 세로 길이를 다른 레이아웃과 맞춤
      case 'vertical':
        return 3/4;
      case 'tripleTopTwo':
      case 'tripleBottomTwo':
        return 2/3;
      case 'quad':
        return 3/4;
      default:
        return 3/4;
    }
  }

  // 실제 냉장고 레이아웃 구현 (냉장고 화면과 동일)
  Widget _buildRealRefrigeratorLayout() {
    switch (widget.layout) {
      case 'single':
        return _buildRealSingleLayout();
      case 'vertical':
        return _buildRealVerticalLayout();
      case 'horizontal':
        return _buildRealHorizontalLayout();
      case 'tripleTopTwo':
        return _buildRealTripleTopTwoLayout();
      case 'tripleBottomTwo':
        return _buildRealTripleBottomTwoLayout();
      case 'quad':
        return _buildRealQuadLayout();
      default:
        return _buildRealSingleLayout();
    }
  }

  // 1칸 실제 냉장고 레이아웃
  Widget _buildRealSingleLayout() {
    final name = _controllers[0].text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _buildCompartmentEditor(
            name: name,
            index: 0,
            color: _getCompartmentColor(name),
            borderColor: _getCompartmentBorderColor(name),
            icon: _getCompartmentIcon(name),
          ),
        ),
      ],
    );
  }
  
  // 2칸 세로 실제 냉장고 레이아웃
  Widget _buildRealVerticalLayout() {
    final name1 = _controllers[0].text;
    final name2 = _controllers[1].text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,  // 3에서 1로 변경하여 위쪽 칸을 작게
          child: _buildCompartmentEditor(
            name: name1,
            index: 0,
            color: _getCompartmentColor(name1),
            borderColor: _getCompartmentBorderColor(name1),
            icon: _getCompartmentIcon(name1),
          ),
        ),
        Container(height: 3, color: Colors.grey[300]),
        Expanded(
          flex: 1,  // 2에서 1로 변경하여 균등하게
          child: _buildCompartmentEditor(
            name: name2,
            index: 1,
            color: _getCompartmentColor(name2),
            borderColor: _getCompartmentBorderColor(name2),
            icon: _getCompartmentIcon(name2),
          ),
        ),
      ],
    );
  }
  
  // 2칸 가로 실제 냉장고 레이아웃
  Widget _buildRealHorizontalLayout() {
    final name1 = _controllers[0].text;
    final name2 = _controllers[1].text;
    return Row(
      children: [
        Expanded(
          child: _buildCompartmentEditor(
            name: name1,
            index: 0,
            color: _getCompartmentColor(name1),
            borderColor: _getCompartmentBorderColor(name1),
            icon: _getCompartmentIcon(name1),
          ),
        ),
        Container(width: 3, color: Colors.grey[300]),
        Expanded(
          child: _buildCompartmentEditor(
            name: name2,
            index: 1,
            color: _getCompartmentColor(name2),
            borderColor: _getCompartmentBorderColor(name2),
            icon: _getCompartmentIcon(name2),
          ),
        ),
      ],
    );
  }
  
  // 3칸 위 두칸 실제 냉장고 레이아웃
  Widget _buildRealTripleTopTwoLayout() {
    final name1 = _controllers[0].text;
    final name2 = _controllers[1].text;
    final name3 = _controllers[2].text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 2,  // 위 두칸 영역을 더 크게(2)
          child: Row(
            children: [
              Expanded(
                child: _buildCompartmentEditor(
                  name: name1,
                  index: 0,
                  color: _getCompartmentColor(name1),
                  borderColor: _getCompartmentBorderColor(name1),
                  icon: _getCompartmentIcon(name1),
                ),
              ),
              Container(width: 3, color: Colors.grey[300]),
              Expanded(
                child: _buildCompartmentEditor(
                  name: name2,
                  index: 1,
                  color: _getCompartmentColor(name2),
                  borderColor: _getCompartmentBorderColor(name2),
                  icon: _getCompartmentIcon(name2),
                ),
              ),
            ],
          ),
        ),
        Container(height: 3, color: Colors.grey[300]),
        Expanded(
          flex: 1,  // 아래 한칸 영역을 더 작게 유지(1)
          child: _buildCompartmentEditor(
            name: name3,
            index: 2,
            color: _getCompartmentColor(name3),
            borderColor: _getCompartmentBorderColor(name3),
            icon: _getCompartmentIcon(name3),
          ),
        ),
      ],
    );
  }
  
  // 3칸 아래 두칸 실제 냉장고 레이아웃
  Widget _buildRealTripleBottomTwoLayout() {
    final name1 = _controllers[0].text;
    final name2 = _controllers[1].text;
    final name3 = _controllers[2].text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,  // 3에서 1로 변경하여 위쪽 칸 크기 줄임
          child: _buildCompartmentEditor(
            name: name1,
            index: 0,
            color: _getCompartmentColor(name1),
            borderColor: _getCompartmentBorderColor(name1),
            icon: _getCompartmentIcon(name1),
          ),
        ),
        Container(height: 3, color: Colors.grey[300]),
        Expanded(
          flex: 1,  // 2에서 1로 변경하여 아래쪽 칸들과 균등하게
          child: Row(
            children: [
              Expanded(
                child: _buildCompartmentEditor(
                  name: name2,
                  index: 1,
                  color: _getCompartmentColor(name2),
                  borderColor: _getCompartmentBorderColor(name2),
                  icon: _getCompartmentIcon(name2),
                ),
              ),
              Container(width: 3, color: Colors.grey[300]),
              Expanded(
                child: _buildCompartmentEditor(
                  name: name3,
                  index: 2,
                  color: _getCompartmentColor(name3),
                  borderColor: _getCompartmentBorderColor(name3),
                  icon: _getCompartmentIcon(name3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 4칸 실제 냉장고 레이아웃
  Widget _buildRealQuadLayout() {
    final name1 = _controllers[0].text;
    final name2 = _controllers[1].text;
    final name3 = _controllers[2].text;
    final name4 = _controllers[3].text;
    return Column(
      children: [
        Expanded(
          flex: 1,  // flex 비율을 명시적으로 1로 설정하여 균등하게
          child: Row(
            children: [
              Expanded(
                child: _buildCompartmentEditor(
                  name: name1,
                  index: 0,
                  color: _getCompartmentColor(name1),
                  borderColor: _getCompartmentBorderColor(name1),
                  icon: _getCompartmentIcon(name1),
                ),
              ),
              Container(width: 3, color: Colors.grey[300]),
              Expanded(
                child: _buildCompartmentEditor(
                  name: name2,
                  index: 1,
                  color: _getCompartmentColor(name2),
                  borderColor: _getCompartmentBorderColor(name2),
                  icon: _getCompartmentIcon(name2),
                ),
              ),
            ],
          ),
        ),
        Container(height: 3, color: Colors.grey[300]),
        Expanded(
          flex: 1,  // flex 비율을 명시적으로 1로 설정하여 균등하게
          child: Row(
            children: [
              Expanded(
                child: _buildCompartmentEditor(
                  name: name3,
                  index: 2,
                  color: _getCompartmentColor(name3),
                  borderColor: _getCompartmentBorderColor(name3),
                  icon: _getCompartmentIcon(name3),
                ),
              ),
              Container(width: 3, color: Colors.grey[300]),
              Expanded(
                child: _buildCompartmentEditor(
                  name: name4,
                  index: 3,
                  color: _getCompartmentColor(name4),
                  borderColor: _getCompartmentBorderColor(name4),
                  icon: _getCompartmentIcon(name4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 개별 칸 편집기 (실제 냉장고 화면과 동일한 스타일)
  Widget _buildCompartmentEditor({
    required String name,
    required int index,
    required Color color,
    required Color borderColor,
    required IconData icon,
  }) {
    return Container(
      margin: EdgeInsets.all(6),  // 칸 간격을 조금 확보
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCompartmentNameEditDialog(index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: borderColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  name.isEmpty ? '칸 이름 설정' : name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: name.isEmpty ? Colors.grey[500] : Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '탭하여 수정',
                    style: TextStyle(
                      fontSize: 10,
                      color: borderColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 칸 이름 편집 다이얼로그
  void _showCompartmentNameEditDialog(int index) {
    final controller = TextEditingController(text: _controllers[index].text);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.edit_outlined, color: Colors.blue[600]),
            SizedBox(width: 8),
            Text('칸 ${index + 1} 이름 설정'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '이 칸의 이름을 입력해주세요',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '예: 냉장실, 냉동실, 야채칸 등',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLength: 20,
              autofocus: true,
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
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                // 중복 이름 검사 (현재 칸 제외)
                bool isDuplicate = false;
                for (int i = 0; i < _controllers.length; i++) {
                  if (i != index && _controllers[i].text.trim() == newName) {
                    isDuplicate = true;
                    break;
                  }
                }
                
                if (isDuplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('이미 사용 중인 칸 이름입니다')),
                  );
                  return;
                }
                
                setState(() {
                  _controllers[index].text = newName;
                });
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '칸 이름 설정',
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
      ),
      body: SingleChildScrollView(
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
                          '${widget.defaultCompartmentNames.length}개의 칸',
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
              '칸 이름 설정',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '각 칸의 이름을 자유롭게 설정할 수 있습니다. 나중에도 변경할 수 있어요.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),

            SizedBox(height: 20),

            // 냉장고 모양 칸 이름 설정
            _buildRefrigeratorLayout(),

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
                          '참고사항',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '• 칸 이름은 중복될 수 없습니다\n• 최대 20자까지 입력 가능합니다\n• "냉동"이 포함된 이름은 파란색으로 표시됩니다\n• 나중에 설정에서 언제든지 변경할 수 있습니다',
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

            // 생성 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createRefrigerator,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _isCreating
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        '냉장고 생성하기',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
} 