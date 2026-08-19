import 'package:flutter/material.dart';
import '../../services/room_service.dart';
import '../../models/room.dart';

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({Key? key}) : super(key: key);

  @override
  _CreateRoomScreenState createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final TextEditingController _roomNameController = TextEditingController();
  final RoomService _roomService = RoomService();
  bool _isCreating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  // 그룹 생성 기능
  Future<void> _createRoom() async {
    String roomName = _roomNameController.text.trim();
    
    // 입력 검증
    if (roomName.isEmpty) {
      setState(() {
        _errorMessage = '그룹 이름을 입력해주세요';
      });
      return;
    }

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      Room? createdRoom = await _roomService.createRoom(roomName);
      
      if (createdRoom != null) {
        if (mounted) {
          // 성공 메시지 표시 및 이전 화면으로 이동
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('그룹이 성공적으로 생성되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // 그룹 목록 화면으로 돌아가기
        }
      } else {
        // 오류 처리
        setState(() {
          _isCreating = false;
          _errorMessage = '그룹 생성에 실패했습니다. 다시 시도해주세요.';
        });
      }
    } catch (e) {
      setState(() {
        _isCreating = false;
        _errorMessage = '오류가 발생했습니다: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // 마이페이지 스타일 헤더
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Color(0xFF6B9FFF),
            leading: Container(
              margin: EdgeInsets.only(left: 16, top: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF6B9FFF),
                      Color(0xFF5A8FEF),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 60, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 아이콘
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        SizedBox(height: 16),
                        // 제목
                        Text(
                          '그룹 생성',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        // 설명
                        Text(
                          '새로운 그룹을 만들어보세요',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // 컨텐츠
          SliverFillRemaining(
            child: Container(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 설명 카드
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF6B9FFF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFF6B9FFF),
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              '그룹 생성 안내',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          '그룹 이름을 입력하고 그룹을 생성하세요.\n그룹이 생성되면 다른 사람들과 공유할 수 있는\n고유한 그룹 코드가 생성됩니다.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // 그룹 이름 입력 섹션
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '그룹 이름',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _roomNameController,
                          decoration: InputDecoration(
                            hintText: '그룹 이름을 입력하세요',
                            errorText: _errorMessage,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFF6B9FFF), width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            filled: true,
                            fillColor: Colors.grey[50],
                          ),
                          maxLength: 30,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _createRoom(),
                        ),
                      ],
                    ),
                  ),
                  
                  Spacer(),
                  
                  // 생성 버튼
                  Container(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6B9FFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: _isCreating
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '그룹 생성',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 