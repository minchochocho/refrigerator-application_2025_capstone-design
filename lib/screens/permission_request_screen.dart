import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../expiration_alert/expiration_alert_service.dart';
import 'main_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PermissionRequestScreen extends StatefulWidget {
  final User? user;
  final Widget? nextScreen;

  const PermissionRequestScreen({
    Key? key,
    this.user,
    this.nextScreen,
  }) : super(key: key);

  @override
  _PermissionRequestScreenState createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> 
    with SingleTickerProviderStateMixin {
  bool _isRequesting = false;
  bool _permissionGranted = false;
  String _statusMessage = '';
  late AnimationController _animationController;
  final ExpirationAlertService _alertService = ExpirationAlertService();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _animationController.forward();
    
    // 권한 상태 확인
    _checkPermissionStatus();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 권한 상태 확인
  Future<void> _checkPermissionStatus() async {
    try {
      // 이미 권한을 요청했는지 확인 (initialize 호출 없이)
      final prefs = await SharedPreferences.getInstance();
      final hasRequestedBefore = prefs.getBool('has_requested_permissions') ?? false;
      
      if (hasRequestedBefore) {
        // 이미 요청했다면 바로 다음 화면으로
        _navigateToNextScreen();
      }
      // 자동 권한 요청 제거 - 사용자가 버튼을 클릭해야만 실행
    } catch (e) {
      print('권한 상태 확인 오류: $e');
    }
  }

  // 권한 요청
  Future<void> _requestPermissions() async {
    setState(() {
      _isRequesting = true;
      _statusMessage = '알림 권한을 요청하고 있습니다...';
    });

    try {
      await _alertService.initialize();
      
      // 바로 시스템 권한 팝업 호출 (별도 메시지 없이)
      await _alertService.requestAllPermissions();
      
      setState(() {
        _statusMessage = '권한 요청이 완료되었습니다!';
        _permissionGranted = true;
      });

      // 권한 요청 완료 상태 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_requested_permissions', true);

      // 기존 식품 알림 자동 갱신 (권한 설정 후)
      setState(() {
        _statusMessage = '기존 식품 알림을 갱신하고 있습니다...';
      });
      
      try {
        await _alertService.updateAllExpirationAlerts();
        setState(() {
          _statusMessage = '모든 설정이 완료되었습니다!';
        });
      } catch (e) {
        print('자동 갱신 오류: $e');
        // 오류가 있어도 진행
      }

      // 1초 후 다음 화면으로 이동 (더 빠르게)
      await Future.delayed(Duration(seconds: 1));
      _navigateToNextScreen();

    } catch (e) {
      setState(() {
        _isRequesting = false;
        _statusMessage = '권한 요청 중 오류가 발생했습니다: $e';
      });
      print('권한 요청 오류: $e');
    }
  }

  // 다음 화면으로 이동
  void _navigateToNextScreen() {
    if (widget.nextScreen != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => widget.nextScreen!),
      );
    } else if (widget.user != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => MainScreen(user: widget.user!),
        ),
      );
    } else {
      // 기본적으로 메인 화면으로 이동
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  // 건너뛰기
  void _skipPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_requested_permissions', true);
    _navigateToNextScreen();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 알림 아이콘 애니메이션
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, -0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(0.0, 0.6, curve: Curves.easeOutCubic),
                      )),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(0.0, 0.6, curve: Curves.easeOut),
                        ),
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_active,
                            size: 60,
                            color: Colors.blue[600],
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 40),
                    
                    // 제목
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(0.2, 0.8, curve: Curves.easeOutCubic),
                      )),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(0.2, 0.8, curve: Curves.easeOut),
                        ),
                        child: Text(
                          '유통기한 알림 설정',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // 설명
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(0.4, 1.0, curve: Curves.easeOutCubic),
                      )),
                      child: FadeTransition(
                        opacity: CurvedAnimation(
                          parent: _animationController,
                          curve: Interval(0.4, 1.0, curve: Curves.easeOut),
                        ),
                        child: Text(
                          '식품의 유통기한이 다가오면\n알림을 보내드립니다.\n\n권한을 허용해주시면 더 정확한\n알림을 받을 수 있습니다.',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    
                    if (_statusMessage.isNotEmpty) ...[
                      SizedBox(height: 30),
                      
                      // 상태 메시지
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _permissionGranted ? Colors.green[50] : Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _permissionGranted ? Colors.green[200]! : Colors.blue[200]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (_isRequesting)
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                                ),
                              )
                            else if (_permissionGranted)
                              Icon(Icons.check_circle, color: Colors.green[600], size: 20)
                            else
                              Icon(Icons.info, color: Colors.blue[600], size: 20),
                            
                            SizedBox(width: 12),
                            
                            Expanded(
                              child: Text(
                                _statusMessage,
                                style: TextStyle(
                                  color: _permissionGranted ? Colors.green[700] : Colors.blue[700],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // 버튼들
              if (!_isRequesting && !_permissionGranted) ...[
                // 주요 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _requestPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      '권한 허용하기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 12),
                
                // 건너뛰기 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: TextButton(
                    onPressed: _skipPermissions,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      '나중에 설정하기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                
                SizedBox(height: 20),
                
                // 추가 안내
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[600], size: 20),
                          SizedBox(width: 8),
                          Text(
                            '권한 안내',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• 알림 권한: 유통기한 알림 표시\n• 정확한 알람 권한: 정시 알림 보장\n• 배터리 최적화 제외: 백그라운드 알림 보장',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
