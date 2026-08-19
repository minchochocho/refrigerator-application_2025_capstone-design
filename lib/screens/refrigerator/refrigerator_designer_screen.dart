import 'package:flutter/material.dart';
import 'refrigerator_compartment_screen.dart';

class RefrigeratorDesignerScreen extends StatefulWidget {
  final String roomId;

  const RefrigeratorDesignerScreen({
    Key? key,
    required this.roomId,
  }) : super(key: key);

  @override
  _RefrigeratorDesignerScreenState createState() => _RefrigeratorDesignerScreenState();
}

class _RefrigeratorDesignerScreenState extends State<RefrigeratorDesignerScreen> {
  // 냉장고 이름
  final TextEditingController _nameController = TextEditingController();
  
  // 선택된 레이아웃
  RefrigeratorLayout? _selectedLayout;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '냉장고 선택',
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
          // 냉장고 이름 입력
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: '냉장고 이름',
                hintText: '냉장고 이름을 입력하세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLength: 20,
            ),
          ),
          
          // 안내 메시지
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              '냉장고 모양을 선택해주세요',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          
          // 레이아웃 선택 영역
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLayoutSection('1칸 냉장고', [
                    RefrigeratorLayout.single,
                  ]),
                  SizedBox(height: 24),
                  _buildLayoutSection('2칸 냉장고', [
                    RefrigeratorLayout.doubleVertical,
                    RefrigeratorLayout.doubleHorizontal,
                  ]),
                  SizedBox(height: 24),
                  _buildLayoutSection('3칸 냉장고', [
                    RefrigeratorLayout.tripleTopTwo,
                    RefrigeratorLayout.tripleBottomTwo,
                  ]),
                  SizedBox(height: 24),
                  _buildLayoutSection('4칸 냉장고', [
                    RefrigeratorLayout.quad,
                  ]),
                ],
              ),
            ),
          ),
          
          // 다음 버튼
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _selectedLayout != null ? _goToNextScreen : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                minimumSize: Size(double.infinity, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '다음',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // 레이아웃 섹션 위젯
  Widget _buildLayoutSection(String title, List<RefrigeratorLayout> layouts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: layouts.map((layout) => _buildLayoutItem(layout)).toList(),
        ),
      ],
    );
  }
  
  // 레이아웃 아이템 위젯
  Widget _buildLayoutItem(RefrigeratorLayout layout) {
    final isSelected = _selectedLayout == layout;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLayout = layout;
        });
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade100,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: _buildLayoutPreview(layout),
      ),
    );
  }
  
  // 레이아웃 미리보기 위젯
  Widget _buildLayoutPreview(RefrigeratorLayout layout) {
    switch (layout) {
      case RefrigeratorLayout.single:
        return _buildSingleLayout();
      case RefrigeratorLayout.doubleVertical:
        return _buildDoubleVerticalLayout();
      case RefrigeratorLayout.doubleHorizontal:
        return _buildDoubleHorizontalLayout();
      case RefrigeratorLayout.tripleTopTwo:
        return _buildTripleTopTwoLayout();
      case RefrigeratorLayout.tripleBottomTwo:
        return _buildTripleBottomTwoLayout();
      case RefrigeratorLayout.quad:
        return _buildQuadLayout();
    }
  }
  
  // 1칸 레이아웃
  Widget _buildSingleLayout() {
    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
  
  // 2칸 세로 레이아웃
  Widget _buildDoubleVerticalLayout() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
  
  // 2칸 가로 레이아웃
  Widget _buildDoubleHorizontalLayout() {
    return Row(
      children: [
        Expanded(
          child: Container(
            margin: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Expanded(
          child: Container(
            margin: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
  
  // 3칸 위 두칸 아래 한칸 레이아웃
  Widget _buildTripleTopTwoLayout() {
    return Column(
      children: [
        // 위쪽 두 칸
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 아래쪽 한 칸
        Expanded(
          flex: 1,
          child: Container(
            margin: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
  
  // 3칸 아래 두칸 위 한칸 레이아웃
  Widget _buildTripleBottomTwoLayout() {
    return Column(
      children: [
        // 위쪽 한 칸
        Expanded(
          flex: 1,
          child: Container(
            margin: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        // 아래쪽 두 칸
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 4칸 레이아웃
  Widget _buildQuadLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  margin: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // 다음 화면으로 이동
  void _goToNextScreen() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('냉장고 이름을 입력해주세요')),
      );
      return;
    }
    
    if (_selectedLayout == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('냉장고 모양을 선택해주세요')),
      );
      return;
    }
    
    // 냉장고 생성 후 방 상세화면으로 돌아가기
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RefrigeratorCompartmentScreen(
          roomId: widget.roomId,
          refrigeratorName: _nameController.text.trim(),
          layout: _selectedLayout.toString().split('.').last,
        ),
        settings: RouteSettings(name: '/refrigeratorCompartment'),
      ),
    );
  }
}

// 냉장고 레이아웃 열거형
enum RefrigeratorLayout {
  single,           // 1칸
  doubleVertical,   // 2칸 세로
  doubleHorizontal, // 2칸 가로
  tripleTopTwo,     // 3칸 위 두칸 아래 한칸
  tripleBottomTwo,  // 3칸 아래 두칸 위 한칸
  quad,             // 4칸
} 