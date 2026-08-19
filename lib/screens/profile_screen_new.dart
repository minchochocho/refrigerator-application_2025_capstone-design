import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import 'profile/avatar_selection_screen.dart';
import 'profile/preferences_screen.dart';
import 'profile/notification_settings_screen.dart';
import 'main_screen.dart';

class ProfileScreen extends StatefulWidget {
  final User? user;
  final Function onSignOut;

  const ProfileScreen({
    Key? key,
    required this.user,
    required this.onSignOut,
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  String? _nickname;
  Color _avatarColor = Colors.blue[400]!;
  IconData _avatarIcon = Icons.person;
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _emailNotificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 사용자 데이터 로드
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final nickname = await _authService.getUserNickname();
      
      // 아바타 색상과 아이콘 로드
      final userId = widget.user?.uid;
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          
          // 아바타 색상 로드
          if (userData['avatarColor'] != null) {
            _avatarColor = Color(userData['avatarColor']);
          }
          
          // 아바타 아이콘 로드
          if (userData['avatarIcon'] != null) {
            _avatarIcon = IconData(userData['avatarIcon'], fontFamily: 'MaterialIcons');
          }
        }
      }

      setState(() {
        _nickname = nickname;
        _isLoading = false;
      });
    } catch (e) {
      print('사용자 데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 프로필 화면으로 이동
  void _navigateToAvatarSelection() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AvatarSelectionScreen(
          onAvatarSelected: _loadUserData,
        ),
      ),
    );
  }

  // 선호도 화면으로 이동
  void _navigateToPreferences() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreferencesScreen(user: widget.user),
      ),
    );
  }

  // 알림설정 화면으로 이동
  void _navigateToNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationSettingsScreen(
          notificationsEnabled: _notificationsEnabled,
          emailNotificationsEnabled: _emailNotificationsEnabled,
          onSettingsChanged: (notifications, emailNotifications) {
            setState(() {
              _notificationsEnabled = notifications;
              _emailNotificationsEnabled = emailNotifications;
            });
          },
        ),
      ),
    );
  }

  // 통계 화면으로 이동 (메인 네비게이션과 동일)
  void _navigateToStatistics() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => MainScreen(
          user: widget.user,
          initialIndex: 2, // 통계 탭 인덱스
        ),
      ),
    );
  }

  // 계정전환 다이얼로그 표시
  void _showAccountSwitchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.swap_horiz, color: Colors.blue[600]),
            SizedBox(width: 8),
            Text('계정전환'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('다른 계정으로 전환하시겠습니까?'),
            SizedBox(height: 8),
            Text(
              '현재 계정에서 로그아웃하고 새로운 계정으로 로그인할 수 있습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.onSignOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            child: Text('계정전환'),
          ),
        ],
      ),
    );
  }

  // 계정탈퇴 다이얼로그 표시
  void _showAccountDeletionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[600]),
            SizedBox(width: 8),
            Text('계정탈퇴'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '정말로 계정을 탈퇴하시겠습니까?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ 주의사항',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 모든 개인 데이터가 영구적으로 삭제됩니다\n• 참여 중인 방에서 자동으로 나가게 됩니다\n• 등록한 식품 정보가 모두 사라집니다\n• 이 작업은 되돌릴 수 없습니다',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red[600],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
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
              Navigator.pop(context);
              _confirmAccountDeletion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: Text('탈퇴하기'),
          ),
        ],
      ),
    );
  }

  // 계정탈퇴 최종 확인
  void _confirmAccountDeletion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          '최종 확인',
          style: TextStyle(color: Colors.red[700]),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.delete_forever,
              size: 48,
              color: Colors.red[400],
            ),
            SizedBox(height: 16),
            Text(
              '정말로 계정을 삭제하시겠습니까?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              '이 작업은 되돌릴 수 없습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: Text('영구 삭제'),
          ),
        ],
      ),
    );
  }

  // 실제 계정 삭제 처리
  Future<void> _deleteAccount() async {
    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red[600]!),
              ),
              SizedBox(height: 16),
              Text('계정을 삭제하는 중...'),
            ],
          ),
        ),
      );

      // TODO: 실제 계정 삭제 로직 구현
      await Future.delayed(Duration(seconds: 2)); // 임시 딜레이
      
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('계정이 성공적으로 삭제되었습니다.'),
          backgroundColor: Colors.green[600],
        ),
      );
      
      // 로그아웃 처리
      await widget.onSignOut();
      
    } catch (e) {
      Navigator.pop(context); // 로딩 다이얼로그 닫기
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('계정 삭제 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = _nickname ?? widget.user?.displayName ?? widget.user?.email?.split('@')[0] ?? '사용자';
    final userEmail = widget.user?.email?.isNotEmpty == true ? widget.user!.email! : '이메일 미등록';
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '마이페이지',
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 프로필 카드
                  Container(
                    margin: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF4A90E2),
                          Color(0xFF5BA3F5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF4A90E2).withOpacity(0.4),
                          blurRadius: 30,
                          offset: Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Row(
                        children: [
                          // 아바타
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 35,
                              backgroundColor: _avatarColor,
                              child: Icon(
                                _avatarIcon,
                                size: 35,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          
                          SizedBox(width: 20),
                          
                          // 사용자 정보
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  userEmail,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 32),

                  // 메뉴
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '메뉴',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 16),
                        Container(
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
                            children: [
                              _buildMenuTile(
                                icon: Icons.person_outline,
                                title: '프로필',
                                subtitle: '닉네임 및 아바타 변경',
                                onTap: _navigateToAvatarSelection,
                              ),
                              Divider(height: 1),
                              _buildMenuTile(
                                icon: Icons.favorite_outline,
                                title: '선호도',
                                subtitle: '좋아요/싫어요 통계 보기',
                                onTap: _navigateToPreferences,
                              ),
                              Divider(height: 1),
                              _buildMenuTile(
                                icon: Icons.notifications_outlined,
                                title: '알림설정',
                                subtitle: '푸시 알림 및 유통기한 알림',
                                onTap: _navigateToNotificationSettings,
                              ),
                              Divider(height: 1),
                              _buildMenuTile(
                                icon: Icons.bar_chart,
                                title: '통계',
                                subtitle: '식품 등록/소비/폐기 통계',
                                onTap: _navigateToStatistics,
                              ),
                              Divider(height: 1),
                              _buildMenuTile(
                                icon: Icons.swap_horiz,
                                title: '계정전환',
                                subtitle: '다른 계정으로 전환',
                                onTap: _showAccountSwitchDialog,
                              ),
                              Divider(height: 1),
                              _buildMenuTile(
                                icon: Icons.logout,
                                title: '로그아웃',
                                subtitle: '현재 계정에서 로그아웃',
                                onTap: () async {
                                  await widget.onSignOut();
                                },
                                isDestructive: true,
                              ),
                              Divider(height: 1),
                              _buildMenuTile(
                                icon: Icons.delete_forever,
                                title: '계정탈퇴',
                                subtitle: '계정을 영구적으로 삭제',
                                onTap: _showAccountDeletionDialog,
                                isDestructive: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 100), // 하단 여백
                ],
              ),
            ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDestructive 
                      ? Colors.red.withOpacity(0.1)
                      : Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? Colors.red[600] : Colors.blue[600],
                  size: 22,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDestructive ? Colors.red[600] : Colors.black,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
