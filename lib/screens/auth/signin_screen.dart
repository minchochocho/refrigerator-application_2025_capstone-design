import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth/login_options.dart';
import '../../widgets/auth/terms_agreement.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({Key? key}) : super(key: key);

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isSigningIn = false;

  // 이메일 유효성 검사를 위한 정규식
  final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  // 현재 화면 상태 관리
  String _currentScreen = 'main'; // 'main', 'email_login', 'email_signup'

  @override
  void initState() {
    super.initState();
    _authService.authStateChanges.listen((User? user) {
      setState(() {
        _user = user;
        _isSigningIn = false;
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 이메일/비밀번호 로그인
  Future<void> _signInWithEmailPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이메일과 비밀번호를 모두 입력해주세요')),
      );
      return;
    }

    // 이메일 형식 검사
    if (!_emailRegExp.hasMatch(_emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('올바른 이메일 형식이 아닙니다')),
      );
      return;
    }

    setState(() {
      _isSigningIn = true;
    });

    try {
      await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } catch (e) {
      setState(() {
        _isSigningIn = false;
      });

      // 에러 메시지 표시
      if (e is FirebaseAuthException) {
        String? errorMessage = _authService.getErrorMessage(e);
        if (errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    }
  }

  // 이메일/비밀번호 회원가입
  Future<void> _signUpWithEmailPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이메일과 비밀번호를 모두 입력해주세요')),
      );
      return;
    }

    // 이메일 형식 검사
    if (!_emailRegExp.hasMatch(_emailController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('올바른 이메일 형식이 아닙니다')),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('비밀번호는 최소 6자 이상이어야 합니다')),
      );
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('비밀번호가 일치하지 않습니다')),
      );
      return;
    }

    setState(() {
      _isSigningIn = true;
    });

    try {
      await _authService.signUpWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
    } catch (e) {
      setState(() {
        _isSigningIn = false;
      });

      // 에러 메시지 표시
      if (e is FirebaseAuthException) {
        String? errorMessage = _authService.getErrorMessage(e);
        if (errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    }
  }

  // 구글 로그인
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      setState(() {
        _isSigningIn = false;
      });

      // 에러 메시지 표시
      if (e is FirebaseAuthException) {
        String? errorMessage = _authService.getErrorMessage(e);
        if (errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    }
  }

  // 익명 로그인
  Future<void> _signInAnonymously() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      await _authService.signInAnonymously();
    } catch (e) {
      setState(() {
        _isSigningIn = false;
      });

      // 에러 메시지 표시
      if (e is FirebaseAuthException) {
        String? errorMessage = _authService.getErrorMessage(e);
        if (errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    }
  }

  // 로그아웃
  Future<void> _signOut() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      await _authService.signOut();
    } catch (e) {
      // 오류 메시지를 표시하지 않음
    } finally {
      setState(() {
        _isSigningIn = false;
      });
    }
  }

  void _navigateTo(String screen) {
    setState(() {
      _currentScreen = screen;
      
      // 화면 전환 시 입력 필드 초기화
      if (screen == 'main' || screen == 'login_options') {
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
      }
    });
  }

  void _showLoginOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return LoginOptionsBottomSheet(
          onGoogleLoginPressed: _signInWithGoogle,
          onEmailLoginPressed: () => _navigateTo('email_login'),
          onFindAccountPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('계정 찾기 기능은 아직 구현되지 않았습니다')),
            );
          },
        );
      },
    );
  }

  void _showAnonymousLoginDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AnonymousLoginDialog(
          onContinuePressed: _signInAnonymously,
        );
      },
    );
  }

  void _showTermsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      builder: (BuildContext context) {
        return TermsAgreementBottomSheet(
          onContinuePressed: (termsAccepted, privacyAccepted, marketingAccepted) {
            _signUpWithEmailPassword();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSigningIn) {
      return _buildLoadingScreen();
    } else {
      // 로그인하지 않은 상태에서는 현재 화면 상태에 따라 다른 화면 표시
      switch (_currentScreen) {
        case 'email_login':
          return _buildEmailLoginScreen();
        case 'email_signup':
          return _buildEmailSignupScreen();
        case 'main':
        default:
          return _buildMainScreen();
      }
    }
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  // 메인 화면: 냉장고 아이콘, 로그인/회원가입 버튼 표시
  Widget _buildMainScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Spacer(flex: 2),
              Image.asset(
                'assets/images/naengard_logo.png',
                width: 150,
                height: 150,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(75),
                    ),
                    child: Icon(
                      Icons.kitchen,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
              
              SizedBox(height: 8),
              Text(
                '냉가드에 오신걸\n 환영합니다',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(flex: 2),
              
              // 로그인/회원가입 버튼
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // 로그인 버튼
                    Container(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () {
                          _showLoginOptions(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '로그인',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    
                    // 회원가입 버튼
                    Container(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _navigateTo('email_signup');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          '회원가입',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // 비회원 시작 텍스트 버튼
                    TextButton(
                      onPressed: () {
                        _showAnonymousLoginDialog(context);
                      },
                      child: Text(
                        '비회원으로 시작하기',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // 이메일 로그인 화면
  Widget _buildEmailLoginScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            _navigateTo('main');
          },
        ),
        title: Text(
          '로그인',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            
            // 이메일 라벨
            Text(
              '이메일',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: "이메일 주소를 입력해주세요",
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                errorText: _emailController.text.isNotEmpty && !_emailRegExp.hasMatch(_emailController.text) 
                    ? "올바른 이메일 형식이 아닙니다"
                    : null,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (value) {
                // 텍스트 변경 시 화면 갱신하여 에러 메시지 업데이트
                setState(() {});
              },
            ),
            SizedBox(height: 24),
            
            // 비밀번호 라벨
            Text(
              '비밀번호',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                hintText: "비밀번호(영문,숫자,특수문자)",
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.done,
            ),
            
            // 비밀번호 잊음 링크
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // 비밀번호 재설정 기능 (필요시 구현)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('비밀번호 재설정 기능은 아직 구현되지 않았습니다')),
                  );
                },
                child: Text(
                  '비밀번호를 잊으셨나요?',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            
            Spacer(),
            
            // 로그인 버튼
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _signInWithEmailPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '로그인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // 이메일 회원가입 화면
  Widget _buildEmailSignupScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            _navigateTo('main');
          },
        ),
        title: Text(
          '회원가입',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16),
            
            // 이메일 라벨
            Text(
              '이메일',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: "이메일 주소를 입력해주세요",
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                errorText: _emailController.text.isNotEmpty && !_emailRegExp.hasMatch(_emailController.text) 
                    ? "올바른 이메일 형식이 아닙니다"
                    : null,
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onChanged: (value) {
                // 텍스트 변경 시 화면 갱신하여 에러 메시지 업데이트
                setState(() {});
              },
            ),
            SizedBox(height: 24),
            
            // 비밀번호 라벨
            Text(
              '비밀번호',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                hintText: "비밀번호(영문,숫자,특수문자)",
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _passwordVisible = !_passwordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_passwordVisible,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: 24),
            
            // 비밀번호 확인 라벨
            Text(
              '비밀번호 확인',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                hintText: "비밀번호(영문,숫자,특수문자)",
                hintStyle: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _confirmPasswordVisible = !_confirmPasswordVisible;
                    });
                  },
                ),
              ),
              obscureText: !_confirmPasswordVisible,
              textInputAction: TextInputAction.done,
            ),
            
            Spacer(),
            
            // 회원가입(로그인) 버튼
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // 이메일 유효성 검사
                  if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('이메일과 비밀번호를 모두 입력해주세요')),
                    );
                    return;
                  }

                  if (!_emailRegExp.hasMatch(_emailController.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('올바른 이메일 형식이 아닙니다')),
                    );
                    return;
                  }

                  if (_passwordController.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('비밀번호는 최소 6자 이상이어야 합니다')),
                    );
                    return;
                  }
                  
                  if (_passwordController.text != _confirmPasswordController.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('비밀번호가 일치하지 않습니다')),
                    );
                    return;
                  }

                  // 약관 동의 화면 표시
                  _showTermsBottomSheet(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '회원가입',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
} 