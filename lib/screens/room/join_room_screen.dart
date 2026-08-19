import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/room_service.dart';

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({Key? key}) : super(key: key);

  @override
  _JoinRoomScreenState createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final TextEditingController _roomCodeController = TextEditingController();
  final RoomService _roomService = RoomService();
  bool _isJoining = false;
  String? _errorMessage;

  @override
  void dispose() {
    _roomCodeController.dispose();
    super.dispose();
  }

  // 방 참여 기능
  Future<void> _joinRoom() async {
    String roomCode = _roomCodeController.text.trim().toUpperCase();
    
    // 입력 검증
    if (roomCode.isEmpty) {
      setState(() {
        _errorMessage = '코드를 입력해주세요';
      });
      return;
    }

    if (roomCode.length != 6) {
      setState(() {
        _errorMessage = '6자리 코드를 입력해주세요';
      });
      return;
    }

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      bool success = await _roomService.joinRoomByCode(roomCode);
      
      if (success && mounted) {
        // 성공 메시지 표시 및 이전 화면으로 이동
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('그룹에 성공적으로 참여했습니다!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // 그룹 목록 화면으로 돌아가기
      }
    } catch (e) {
      setState(() {
        _isJoining = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
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
                            Icons.login_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        SizedBox(height: 16),
                        // 제목
                        Text(
                          '그룹 참여',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 6),
                        // 설명
                        Text(
                          '초대 코드로 그룹에 참여하세요',
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
                              '그룹 참여 안내',
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
                          '방장에게 받은 6자리 초대 코드를 입력하여\n그룹에 참여하세요.',
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
                  
                  // 초대 코드 입력 섹션
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
                          '초대 코드',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 12),
                        TextField(
                          controller: _roomCodeController,
                          decoration: InputDecoration(
                            hintText: '6자리 코드 입력',
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
                            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                            filled: true,
                            fillColor: Colors.grey[50],
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 18,
                              letterSpacing: 0,
                            ),
                          ),
                          maxLength: 6,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _joinRoom(),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9]')),
                          ],
                          textCapitalization: TextCapitalization.characters,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            letterSpacing: 10,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Spacer(),
                  
                  // 참여 버튼
                  Container(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isJoining ? null : _joinRoom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6B9FFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                      child: _isJoining
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
                                Icon(Icons.login_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  '그룹 참여',
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