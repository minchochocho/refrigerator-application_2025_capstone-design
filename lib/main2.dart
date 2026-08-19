import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    print('Firebase 초기화 성공 (main2.dart)');
  } catch (e) {
    print('Firebase 초기화 오류 (main2.dart): $e');
    // 이미 초기화된 경우 무시하고 계속 진행
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: SignInScreen(),
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  User? _user;
  bool _isSigningIn = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isNewUser = false;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _auth.authStateChanges().listen((User? user) {
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
    super.dispose();
  }

  // 이메일/비밀번호 로그인
  Future<void> _signInWithEmailPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      return;
    }

    setState(() {
      _isSigningIn = true;
    });

    try {
      // 로그인 시도
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // 성공 시 자동으로 _user 상태가 업데이트됨
    } catch (e) {
      setState(() {
        _isSigningIn = false;
      });

      // 특정 FirebaseAuthException 오류 코드에 대해서만 메시지 표시
      if (e is FirebaseAuthException) {
        String? errorMessage;

        if (e.code == 'user-not-found') {
          errorMessage = '해당 이메일로 가입된 계정이 없습니다';
        } else if (e.code == 'wrong-password') {
          errorMessage = '비밀번호가 일치하지 않습니다';
        } else if (e.code == 'invalid-email') {
          errorMessage = '유효하지 않은 이메일 형식입니다';
        } else if (e.code == 'user-disabled') {
          errorMessage = '비활성화된 계정입니다';
        }

        // 특정 오류 코드에 대해서만 SnackBar 표시
        if (errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
      // 그 외 일반적인 오류에 대해서는 메시지 표시하지 않음
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

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('비밀번호는 최소 6자 이상이어야 합니다')),
      );
      return;
    }

    setState(() {
      _isSigningIn = true;
    });

    try {
      // 회원가입 시도
      await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // 성공 시 자동으로 _user 상태가 업데이트됨
    } catch (e) {
      setState(() {
        _isSigningIn = false;
      });

      // 특정 FirebaseAuthException 오류 코드에 대해서만 메시지 표시
      if (e is FirebaseAuthException) {
        String? errorMessage;

        if (e.code == 'email-already-in-use') {
          errorMessage = '이미 사용 중인 이메일입니다';
        } else if (e.code == 'weak-password') {
          errorMessage = '보안에 취약한 비밀번호입니다. 다른 비밀번호를 사용해주세요';
        } else if (e.code == 'invalid-email') {
          errorMessage = '유효하지 않은 이메일 형식입니다';
        }

        // 특정 오류 코드에 대해서만 SnackBar 표시
        if (errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
      // 그 외 일반적인 오류에 대해서는 메시지 표시하지 않음
    }
  }

  // 구글 로그인
  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      // 이전에 연결된 구글 계정을 해제하여 계정 선택 창을 강제로 띄움
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // 사용자가 구글 로그인을 취소한 경우
        setState(() {
          _isSigningIn = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 구글 계정으로 Firebase 로그인
      await _auth.signInWithCredential(credential);
      // 성공 시 자동으로 _user 상태가 업데이트됨
    } catch (e) {
      setState(() {
        _isSigningIn = false;
      });

      // 특정 FirebaseAuthException 오류 코드에 대해서만 메시지 표시
      if (e is FirebaseAuthException) {
        String? errorMessage;

        if (e.code == 'account-exists-with-different-credential') {
          errorMessage = '이미 다른 방식으로 가입된 이메일입니다';
        } else if (e.code == 'invalid-credential') {
          errorMessage = '인증 정보가 유효하지 않습니다';
        }

        // 특정 오류 코드에 대해서만 SnackBar 표시
        if (errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
      // 그 외 일반적인 오류에 대해서는 메시지 표시하지 않음
    }
  }

  // 익명 로그인
  Future<void> _signInAnonymously() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      // 익명 로그인 시도
      await _auth.signInAnonymously();
      // 성공 시 자동으로 _user 상태가 업데이트됨
    } catch (e) {
      setState(() {
        _isSigningIn = false;
      });

      // 특정 FirebaseAuthException 오류 코드에 대해서만 메시지 표시
      if (e is FirebaseAuthException) {
        String? errorMessage;

        if (e.code == 'operation-not-allowed') {
          errorMessage = '익명 로그인이 비활성화되어 있습니다';
        }

        // 특정 오류 코드에 대해서만 SnackBar 표시
        if (errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
      // 그 외 일반적인 오류에 대해서는 메시지 표시하지 않음
    }
  }

  // 로그아웃
  Future<void> _signOut() async {
    setState(() {
      _isSigningIn = true;
    });

    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } catch (e) {
      // 오류 메시지를 표시하지 않음
    } finally {
      setState(() {
        _isSigningIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isSigningIn
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('처리 중...', style: TextStyle(fontSize: 16)),
            ],
          ),
        )
            : _user == null
            ? _buildLoginForm()
            : _buildUserProfile(),
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: 40),
            // 앱 로고 또는 아이콘
            Icon(
              Icons.lock_outlined,
              size: 80,
              color: Theme.of(context).primaryColor,
            ),
            SizedBox(height: 24),
            // 앱 제목
            Text(
              _isNewUser ? '회원가입' : '로그인',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              _isNewUser
                  ? '계정을 생성하여 서비스를 이용해보세요'
                  : '계정 정보를 입력하여 로그인하세요',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 36),

            // 이메일 입력 필드
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: "이메일",
                prefixIcon: Icon(Icons.email_outlined),
                hintText: "example@email.com",
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            SizedBox(height: 16),

            // 비밀번호 입력 필드
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: "비밀번호",
                prefixIcon: Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility_off : Icons.visibility,
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
              onSubmitted: (_) {
                _isNewUser ? _signUpWithEmailPassword() : _signInWithEmailPassword();
              },
            ),

            if (!_isNewUser) ...[
              SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // 비밀번호 재설정 기능 (필요시 구현)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('비밀번호 재설정 기능은 아직 구현되지 않았습니다')),
                    );
                  },
                  child: Text('비밀번호를 잊으셨나요?'),
                ),
              ),
            ],

            SizedBox(height: 24),

            // 로그인/회원가입 버튼
            ElevatedButton(
              onPressed: _isNewUser ? _signUpWithEmailPassword : _signInWithEmailPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 54),
              ),
              child: Text(
                _isNewUser ? "회원가입" : "로그인",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            SizedBox(height: 16),

            // 회원가입/로그인 전환 버튼
            TextButton(
              onPressed: () {
                setState(() {
                  _isNewUser = !_isNewUser;
                  // 전환 시 입력 필드 초기화
                  _emailController.clear();
                  _passwordController.clear();
                });
              },
              child: Text(
                _isNewUser
                    ? "이미 계정이 있으신가요? 로그인하기"
                    : "계정이 없으신가요? 회원가입하기",
                style: TextStyle(fontSize: 14),
              ),
            ),

            SizedBox(height: 32),

            // 구분선
            Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    "또는",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                Expanded(child: Divider()),
              ],
            ),

            SizedBox(height: 32),

            // 구글 로그인 버튼
            OutlinedButton.icon(
              onPressed: _signInWithGoogle,
              icon: Icon(
                Icons.login,
                size: 24,
                color: Colors.blue,
              ),
              label: Text(
                "구글 계정으로 계속하기",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            SizedBox(height: 16),

            // 익명 로그인 버튼
            OutlinedButton.icon(
              onPressed: _signInAnonymously,
              icon: Icon(
                Icons.person_outline,
                size: 24,
                color: Colors.grey.shade700,
              ),
              label: Text(
                "게스트로 계속하기",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Icon(
                _user!.isAnonymous ? Icons.person_outline : Icons.person,
                size: 70,
                color: Theme.of(context).primaryColor,
              ),
            ),
            SizedBox(height: 24),
            Text(
              _user!.isAnonymous ? "게스트로 로그인됨" : "환영합니다!",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _user!.isAnonymous
                  ? "익명 사용자입니다"
                  : "${_user!.email}",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _signOut,
              icon: Icon(Icons.logout),
              label: Text(
                "로그아웃",
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red,
                minimumSize: Size(200, 54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}