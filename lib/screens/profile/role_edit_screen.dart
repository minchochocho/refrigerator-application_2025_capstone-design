import 'package:flutter/material.dart';
import '../../services/room_service.dart';
import '../../services/auth_service.dart';

class RoleEditScreen extends StatefulWidget {
  final String roomId;
  final String roomName;
  final String currentRole;

  const RoleEditScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
    this.currentRole = '',
  }) : super(key: key);

  @override
  _RoleEditScreenState createState() => _RoleEditScreenState();
}

class _RoleEditScreenState extends State<RoleEditScreen> {
  final TextEditingController _roleController = TextEditingController();
  final RoomService _roomService = RoomService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  String? _nickname;
  
  // 역할 제안 목록
  final List<String> _roleSuggestions = [
    '맛있는', '요리왕', '냉장고지기', '냉장고관리자', '장보미', 
    '야식담당', '요리장인', '분식왕', '인스턴트마스터', '청소담당',
    '음식천재', '식재료관리자', '식신', '맛잘알', '음식덕후'
  ];
  
  @override
  void initState() {
    super.initState();
    _roleController.text = widget.currentRole;
    _loadNickname();
  }
  
  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }
  
  // 닉네임 불러오기
  Future<void> _loadNickname() async {
    try {
      _nickname = await _authService.getUserNickname();
      setState(() {});
    } catch (e) {
      print('닉네임 로드 오류: $e');
    }
  }
  
  // 역할 저장
  Future<void> _saveRole() async {
    final role = _roleController.text.trim();
    
    if (role.isEmpty) {
      // 빈 값도 허용 (역할 삭제)
      await _updateRole('');
      return;
    }
    
    if (role.length > 10) {
      setState(() {
        _errorMessage = '역할은 10자 이내로 입력해주세요';
      });
      return;
    }
    
    await _updateRole(role);
  }
  
  // 역할 업데이트
  Future<void> _updateRole(String role) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final success = await _roomService.setMyRole(widget.roomId, role);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('역할이 저장되었습니다')),
        );
        Navigator.pop(context, role); // 역할 정보를 반환하며 화면 닫기
      } else {
        setState(() {
          _errorMessage = '역할 저장에 실패했습니다';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }
  
  // 역할 미리보기
  String get _rolePreview {
    final role = _roleController.text.trim();
    if (role.isEmpty) return _nickname ?? '사용자';
    return '$role ${_nickname ?? '사용자'}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('역할 수정'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // 초기화 버튼
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _roleController.clear();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 방 이름 표시
                  Text(
                    '${widget.roomName} 방에서의 역할',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '이 방에서 보여질 당신의 역할을 입력해주세요.\n비워두면 역할 없이 닉네임만 표시됩니다.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // 역할 미리보기
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '미리보기',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.blue.shade100,
                              child: Icon(
                                Icons.person,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              _rolePreview,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 24),
                  
                  // 역할 입력 필드
                  TextField(
                    controller: _roleController,
                    decoration: InputDecoration(
                      labelText: '역할',
                      hintText: '예: 요리왕, 냉장고관리자 등',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => _roleController.clear(),
                        icon: Icon(Icons.clear),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                    maxLength: 10,
                  ),
                  
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  
                  SizedBox(height: 24),
                  
                  // 역할 제안 목록
                  Text(
                    '역할 제안',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _roleSuggestions.map((role) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _roleController.text = role;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            role,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  SizedBox(height: 40),
                  
                  // 저장 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveRole,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.blue.shade200,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              '저장',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
} 