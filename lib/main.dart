import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/auth/signin_screen.dart';
import 'screens/main_screen.dart';
import 'screens/auth/nickname_screen.dart';
import 'screens/permission_request_screen.dart';
import 'widgets/loading_animation.dart';
import 'theme/app_theme.dart';
import 'expiration_alert/expiration_alert_service.dart';
import 'insik/insik_scanner_screen.dart';
import 'screens/expiration/expiring_overview_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'screens/receipt_scanner_screen.dart';

// 이미지 파일 추가 방법:
// 1. 프로젝트 루트에 assets/images/ 폴더 생성
// 2. 이미지 파일(naengard_logo.png, google_logo.png 등)을 해당 폴더에 넣기
// 3. pubspec.yaml 파일에 아래 내용 추가:
//   flutter:
//     assets:
//       - assets/images/
// 4. 터미널에서 'flutter pub get' 실행

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Firebase 초기화 - 통합된 설정 사용
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase 초기화 성공 - 프로젝트: refrigerator-care');

    // FCM 초기화
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // 포그라운드 메시지 처리 → 로컬 알림 표시
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final alertService = ExpirationAlertService();
      await alertService.initialize();
      final title = message.notification?.title ?? '알림';
      final body = message.notification?.body ?? '메시지가 도착했습니다';
      await alertService.showLocalNotification(title: title, body: body);
    });
    
    // 유통기한 알림 서비스 초기화 (권한 요청은 별도 화면에서 진행)
    try {
      final alertService = ExpirationAlertService();
      await alertService.initialize();
      print('유통기한 알림 서비스 초기화 완료');

      // 이전에 예약된 테스트 알림 정리
      await alertService.cancelTestNotifications();
      print('테스트 알림 정리 완료');
      
      // 로그인 상태 확인 후 알림 업데이트
      FirebaseAuth.instance.authStateChanges().listen((User? user) async {
        if (user != null) {
          print('사용자 로그인 감지, 알림 업데이트 시작...');
          try {
            await alertService.updateAllExpirationAlerts();
            print('알림 업데이트 완료');
          } catch (e) {
            print('❌ 알림 업데이트 오류: $e');
          }
        }
      });
    } catch (e) {
      print('❌ 알림 서비스 초기화 오류: $e');
    }
    
    // 매일 자동 알림 갱신 스케줄링은 플랫폼 제약으로 비활성화되었습니다.
  } catch (e) {
    print('Firebase 초기화 오류: $e');
    // 오류 발생 시에도 앱이 실행되도록 처리
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: AppTheme.noGlowScrollBehavior,
      locale: const Locale('ko', 'KR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/auth': (context) => AuthWrapper(),
        '/signin': (context) => SignInScreen(),
        '/nickname': (context) => NicknameScreen(),
        '/receiptScan': (context) => const ReceiptScannerScreen(),
        '/insikScan': (context) => const InsikReceiptScannerScreen(),
        '/expiring': (context) => const ExpiringOverviewScreen(),
      },
    );
  }
}

/// 스플래시 화면 위젯
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    );
    
    _controller.forward();
    
    // 스플래시 후 권한 여부에 따라 첫 화면 분기
    Future.delayed(Duration(milliseconds: 2500), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final hasRequested = prefs.getBool('has_requested_permissions') ?? false;
        final isFirstLaunch = !(prefs.getBool('coldguard_first_launch_done') ?? false);
        if (isFirstLaunch) {
          // 첫 실행 시 어떤 로그인 상태라도 정리하여 항상 권한/로그인 플로우로 진입
          try {
            await FirebaseAuth.instance.signOut();
          } catch (_) {}
          try {
            await GoogleSignIn().signOut();
          } catch (_) {}
          await prefs.setBool('coldguard_first_launch_done', true);
        }
        if (!mounted) return;
        if (isFirstLaunch || !hasRequested) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => PermissionRequestScreen(nextScreen: AuthWrapper())),
          );
        } else {
          Navigator.of(context).pushReplacementNamed('/auth');
        }
      } catch (_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 로고 애니메이션
            SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, 0.2),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _controller,
                curve: Interval(0.0, 0.5, curve: Curves.easeOutCubic),
              )),
              child: FadeTransition(
                opacity: Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(CurvedAnimation(
                  parent: _controller,
                  curve: Interval(0.0, 0.5, curve: Curves.easeOutCubic),
                )),
                child: Icon(
                  Icons.kitchen_rounded,
                  size: 120,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            SizedBox(height: 24),
            // 앱 이름 텍스트
            SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, 0.5),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _controller,
                curve: Interval(0.3, 0.8, curve: Curves.easeOutCubic),
              )),
              child: FadeTransition(
                opacity: Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(CurvedAnimation(
                  parent: _controller,
                  curve: Interval(0.3, 0.8, curve: Curves.easeOutCubic),
                )),
                child: Text(
                  '냉가드',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            // 앱 설명 텍스트
            SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, 0.5),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _controller,
                curve: Interval(0.5, 1.0, curve: Curves.easeOutCubic),
              )),
              child: FadeTransition(
                opacity: Tween<double>(
                  begin: 0.0,
                  end: 1.0,
                ).animate(CurvedAnimation(
                  parent: _controller,
                  curve: Interval(0.5, 1.0, curve: Curves.easeOutCubic),
                )),
                child: Text(
                  '똑똑한 냉장고 관리',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
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

/// 인증 상태에 따라 적절한 화면을 표시하는 Wrapper 위젯
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LoadingManager(
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // 인증 상태 확인 중
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: LoadingAnimation(
                  message: '로그인 상태 확인 중...',
                ),
              ),
            );
          }
          
          // 로그인된 사용자가 있으면 닉네임 설정 또는 메인 화면으로
          if (snapshot.hasData && snapshot.data != null) {
            return FutureBuilder<bool>(
              future: _checkIsFirstLogin(snapshot.data!.uid),
              builder: (context, firstLoginSnapshot) {
                if (firstLoginSnapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(
                      child: LoadingAnimation(
                        message: '사용자 정보 로딩 중...',
                      ),
                    ),
                  );
                }
                
                // 처음 로그인한 경우만 닉네임 설정 화면으로 이동
                if (firstLoginSnapshot.data == true) {
                  return NicknameScreen(user: snapshot.data!);
                }
                
                // 처음이 아니면 바로 메인 화면으로 (권한은 별도 처리)
                _ensurePermissionsChecked(snapshot.data!.uid);
                return MainScreen(user: snapshot.data!);
              },
            );
          }
          
          // 로그인되지 않았으면 로그인 화면으로
          return SignInScreen();
        },
      ),
    );
  }
  
  /// 사용자가 처음 로그인했는지 확인
  Future<bool> _checkIsFirstLogin(String uid) async {
    try {
      // 공유 환경설정에서 해당 사용자의 로그인 기록 확인
      final prefs = await SharedPreferences.getInstance();
      final hasLoggedInBefore = prefs.getBool('user_${uid}_has_logged_in') ?? false;
      
      if (!hasLoggedInBefore) {
        // 닉네임이 설정되어 있는지 확인
        final hasNickname = await _checkNicknameExists(uid);
        
        // 닉네임이 이미 설정되어 있다면 처음 로그인이 아님
        if (hasNickname) {
          // 닉네임이 설정되어 있으면 로그인 기록 저장
          await prefs.setBool('user_${uid}_has_logged_in', true);
          return false;
        }
        
        // 첫 로그인으로 처리 (닉네임 설정 필요)
        return true;
      }
      
      // 이미 로그인한 적이 있음
      return false;
    } catch (e) {
      print('첫 로그인 확인 중 오류: $e');
      // 오류 발생 시 안전하게 닉네임 설정 화면으로 이동
      return false;
    }
  }
  
  /// 닉네임이 이미 설정되어 있는지 확인
  Future<bool> _checkNicknameExists(String uid) async {
    try {
      // 사용자 문서 조회
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(uid)
          .get();
      
      // 문서가 존재하고 nickname 필드가 있는지 확인
      return userDoc.exists && userDoc.data() != null && (userDoc.data() as Map<String, dynamic>).containsKey('nickname');
    } catch (e) {
      print('닉네임 확인 중 오류: $e');
      return false;
    }
  }
  
  /// 권한이 확인되었는지 체크하고, 안되어 있으면 백그라운드에서 처리
  void _ensurePermissionsChecked(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRequestedBefore = prefs.getBool('has_requested_permissions') ?? false;
      
      if (!hasRequestedBefore) {
        // 권한이 요청되지 않았으면 알림 서비스만 초기화
        // (사용자는 설정에서 나중에 권한을 허용할 수 있음)
        print('권한이 아직 요청되지 않았습니다. 설정에서 확인해주세요.');
      }
    } catch (e) {
      print('권한 확인 오류: $e');
    }
  }
} 