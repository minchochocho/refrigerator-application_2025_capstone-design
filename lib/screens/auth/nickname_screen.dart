import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../main_screen.dart';
import '../permission_request_screen.dart';

class NicknameScreen extends StatefulWidget {
  final User? user;

  const NicknameScreen({Key? key, this.user}) : super(key: key);

  @override
  _NicknameScreenState createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _setDefaultNickname();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }
  
  // 기본 닉네임 설정
  Future<void> _setDefaultNickname() async {
    if (widget.user != null) {
      String? nickname;
      
      // 이미 설정된 닉네임이 있는지 확인
      nickname = await _authService.getUserNickname();
      
      if (nickname == null || nickname.isEmpty) {
        // 기본값 설정
        if (widget.user!.displayName != null && widget.user!.displayName!.isNotEmpty) {
          nickname = widget.user!.displayName;
        } else if (widget.user!.email != null) {
          nickname = widget.user!.email!.split('@')[0];
        } else {
          nickname = '사용자';
        }
      }
      
      setState(() {
        _nicknameController.text = nickname ?? '';
      });
    }
  }
  
  // 닉네임 저장
  Future<void> _saveNickname() async {
    final nickname = _nicknameController.text.trim();
    
    if (nickname.isEmpty) {
      setState(() {
        _errorMessage = '닉네임을 입력해주세요';
      });
      return;
    }
    
    if (nickname.length < 2 || nickname.length > 10) {
      setState(() {
        _errorMessage = '닉네임은 2~10자 사이여야 합니다';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // 더 명확한 디버그 메시지 출력
      print('닉네임 저장 시도: $nickname');
      final success = await _authService.updateUserNickname(nickname);
      
      if (success) {
        print('닉네임 저장 성공');
        
        // 닉네임 설정 완료 후 사용자의 첫 로그인 상태 기록
        if (widget.user != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('user_${widget.user!.uid}_has_logged_in', true);
        }
        
        // 메인으로 이동 (권한 화면은 스플래시에서 1회만 노출)
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => MainScreen(user: widget.user),
          ),
          (route) => false,
        );
      } else {
        print('닉네임 저장 실패: 서비스에서 false 반환');
        setState(() {
          _isLoading = false;
          _errorMessage = '닉네임 저장에 실패했습니다. 다시 시도해주세요.';
        });
      }
    } catch (e) {
      print('닉네임 저장 중 예외 발생: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = '오류가 발생했습니다: $e';
      });
      
      // 오류가 발생해도 메인 화면으로 이동 시도
      // (닉네임이 정상적으로 저장되지 않았더라도 앱 사용 가능하도록)
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          // 오류 발생 시에도 로그인 상태 기록 시도
          _setLoggedInStatus().then((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) => MainScreen(user: widget.user),
              ),
              (route) => false,
            );
          });
        }
      });
    }
  }
  
  // 사용자의 로그인 상태를 기록하는 메서드
  Future<void> _setLoggedInStatus() async {
    if (widget.user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('user_${widget.user!.uid}_has_logged_in', true);
      } catch (e) {
        print('로그인 상태 기록 중 오류: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '닉네임 설정',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // 뒤로가기 버튼 제거
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20),
              
              Center(
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blue.shade100,
                  child: Icon(
                    Icons.person,
                    size: 60,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
              
              SizedBox(height: 40),
              
              Text(
                '환영합니다!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              SizedBox(height: 12),
              
              Text(
                '다른 사용자에게 보여질 닉네임을 설정해주세요.\n나중에 마이페이지에서 변경할 수 있습니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                ),
              ),
              
              SizedBox(height: 40),
              
              Text(
                '닉네임',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              
              SizedBox(height: 8),
              
              TextField(
                controller: _nicknameController,
                decoration: InputDecoration(
                  hintText: '2~10자 사이로 입력해주세요',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => _nicknameController.clear(),
                    icon: Icon(Icons.clear),
                  ),
                ),
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
              
              SizedBox(height: 40),
              
              Container(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveNickname,
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
                          '완료',
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
      ),
    );
  }
} 