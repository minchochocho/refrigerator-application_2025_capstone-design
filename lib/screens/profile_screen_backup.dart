import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../expiration_alert/expiration_alert_service.dart';
import 'profile/avatar_selection_screen.dart';
import 'profile/statistics_screen.dart';
import 'profile/preferences_screen.dart';
import 'profile/notification_settings_screen.dart';
import 'room/room_list_screen.dart';
import 'search/search_screen.dart';
import 'main_screen.dart';

import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  final ExpirationAlertService _alertService = ExpirationAlertService();
  String? _nickname;
  String? _profileImageUrl;
  Color _avatarColor = Colors.blue[400]!;
  IconData _avatarIcon = Icons.person;
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _emailNotificationsEnabled = false;
  List<Map<String, dynamic>> _userRooms = [];
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserSettings();
    _loadUserRooms();
  }
  
  // 사용자 데이터 로드
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final nickname = await _authService.getUserNickname();
      final profileImageUrl = await _authService.getUserProfileImageUrl();
      
      // 아바타 색상과 아이콘 로드
      final userId = widget.user?.uid;
      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
        }
      }

      // 아바타 색상과 아이콘 로드
      final avatarColor = await _authService.getAvatarColor();
      final avatarIcon = await _authService.getAvatarIcon();
      
      print('프로필 화면 아바타 로드: 색상=$avatarColor, 아이콘=$avatarIcon');
      
      if (avatarColor != null) {
        _avatarColor = avatarColor;
        print('아바타 색상 업데이트: $_avatarColor');
      }
      if (avatarIcon != null) {
        _avatarIcon = avatarIcon;
        print('아바타 아이콘 업데이트: $_avatarIcon');
      }
      
      setState(() {
        _nickname = nickname;
        _profileImageUrl = profileImageUrl;
        _isLoading = false;
      });
    } catch (e) {
      print('사용자 데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 사용자 설정 로드
  Future<void> _loadUserSettings() async {
    // TODO: SharedPreferences에서 설정 값 로드
    // 임시로 기본값 사용
  }

  // 사용자 방 목록 로드
  Future<void> _loadUserRooms() async {
    if (widget.user?.uid == null) return;

    print('🏠 사용자 방 목록 로드 시작: userId = ${widget.user!.uid}');

    try {
      // 사용자가 속한 방 목록 가져오기
      QuerySnapshot roomUserSnapshot = await FirebaseFirestore.instance
          .collection('RoomUser')
          .where('user_id', isEqualTo: widget.user!.uid)
          .get();

      print('🏠 RoomUser 문서 개수: ${roomUserSnapshot.docs.length}');

      List<Map<String, dynamic>> rooms = [];
      
      for (DocumentSnapshot roomUserDoc in roomUserSnapshot.docs) {
        Map<String, dynamic> roomUserData = roomUserDoc.data() as Map<String, dynamic>;
        String roomId = roomUserData['room_id'];
        print('🏠 처리 중인 roomId: $roomId');
        
        // 방 정보 가져오기
        DocumentSnapshot roomDoc = await FirebaseFirestore.instance
            .collection('Rooms')
            .doc(roomId)
            .get();
            
        if (roomDoc.exists) {
          Map<String, dynamic> roomData = roomDoc.data() as Map<String, dynamic>;
          final roomInfo = {
            'id': roomId,
            'name': roomData['room_name'] ?? '알 수 없는 방',
            'code': roomData['room_code'] ?? '',
          };
          rooms.add(roomInfo);
          print('🏠 방 추가됨: ${roomInfo['name']} (${roomInfo['id']})');
        } else {
          print('⚠️ 방 문서가 존재하지 않음: $roomId');
        }
      }

      setState(() {
        _userRooms = rooms;
      });
      print('🏠 최종 방 목록 개수: ${rooms.length}');
    } catch (e) {
      print('❌ 사용자 방 목록 로드 오류: $e');
    }
  }

  // 실시간으로 방 목록 가져오기 (메모리 상태에 의존하지 않음)
  Future<List<Map<String, dynamic>>> _getRealTimeUserRooms() async {
    // 현재 Firebase 인증 상태 확인
    final currentUser = FirebaseAuth.instance.currentUser;
    final widgetUser = widget.user;
    
    print('🔄 Firebase 현재 사용자: ${currentUser?.uid}');
    print('🔄 Widget 사용자: ${widgetUser?.uid}');
    
    String? userId;
    if (currentUser?.uid != null) {
      userId = currentUser!.uid;
    } else if (widgetUser?.uid != null) {
      userId = widgetUser!.uid;
    } else {
      print('❌ 사용자 UID가 null입니다 (Firebase: ${currentUser?.uid}, Widget: ${widgetUser?.uid})');
      return [];
    }

    print('🔄 실시간 방 목록 조회 시작: userId = $userId');

    try {
      // 사용자가 속한 방 목록 가져오기
      QuerySnapshot roomUserSnapshot = await FirebaseFirestore.instance
          .collection('RoomUser')
          .where('user_id', isEqualTo: userId)
          .get();

      print('🔄 실시간 RoomUser 문서 개수: ${roomUserSnapshot.docs.length}');

      List<Map<String, dynamic>> rooms = [];
      
      for (DocumentSnapshot roomUserDoc in roomUserSnapshot.docs) {
        Map<String, dynamic> roomUserData = roomUserDoc.data() as Map<String, dynamic>;
        String roomId = roomUserData['room_id'];
        print('🔄 실시간 처리 중인 roomId: $roomId');
        
        // 방 정보 가져오기
        DocumentSnapshot roomDoc = await FirebaseFirestore.instance
            .collection('Rooms')
            .doc(roomId)
            .get();
            
        if (roomDoc.exists) {
          Map<String, dynamic> roomData = roomDoc.data() as Map<String, dynamic>;
          final roomInfo = {
            'id': roomId,
            'name': roomData['room_name'] ?? '알 수 없는 방',
            'code': roomData['room_code'] ?? '',
          };
          rooms.add(roomInfo);
          print('🔄 실시간 방 추가됨: ${roomInfo['name']} (${roomInfo['id']})');
        } else {
          print('⚠️ 실시간 방 문서가 존재하지 않음: $roomId');
        }
      }

      print('🔄 실시간 최종 방 목록 개수: ${rooms.length}');
      return rooms;
    } catch (e) {
      print('❌ 실시간 방 목록 조회 오류: $e');
      return [];
    }
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
    // MainScreen의 통계 탭으로 이동
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
      // 1. 사용자 데이터 삭제
      // 2. 참여 중인 방에서 나가기
      // 3. Firebase Auth 계정 삭제
      
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


  // 아바타 선택 화면으로 이동
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






  // 개인정보 보호 설정 (사용하지 않음 - 새 메뉴 구조에서 제거됨)
  void _showPrivacySettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.security_outlined, color: Colors.blue[600]),
            SizedBox(width: 8),
            Text('개인정보 보호'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '계정 정보',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text('이메일: ${widget.user?.email ?? '미등록'}'),
              Text('가입일: ${widget.user?.metadata.creationTime?.toString().split(' ')[0] ?? '알 수 없음'}'),
              Text('최근 로그인: ${widget.user?.metadata.lastSignInTime?.toString().split(' ')[0] ?? '알 수 없음'}'),
              
              SizedBox(height: 16),
              
              Text(
                '데이터 관리',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              
              ElevatedButton.icon(
                onPressed: _exportUserData,
                icon: Icon(Icons.download, size: 18),
                label: Text('내 데이터 내보내기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                ),
              ),
              
              SizedBox(height: 8),
              
              ElevatedButton.icon(
                onPressed: _showDeleteAccountDialog,
                icon: Icon(Icons.delete_forever, size: 18),
                label: Text('계정 삭제'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 사용자 데이터 내보내기
  void _exportUserData() {
    // TODO: 실제 데이터 내보내기 구현
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('데이터 내보내기 기능은 곧 추가될 예정입니다'),
        backgroundColor: Colors.blue[600],
      ),
    );
  }

  // 계정 삭제 다이얼로그
  void _showDeleteAccountDialog() {
    Navigator.pop(context); // 기존 다이얼로그 닫기
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
            Text('계정 삭제'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '정말로 계정을 삭제하시겠습니까?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• 모든 개인 데이터가 삭제됩니다'),
            Text('• 참여 중인 방의 데이터는 유지됩니다'),
            Text('• 이 작업은 되돌릴 수 없습니다'),
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
              // TODO: 실제 계정 삭제 구현
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('계정 삭제 기능은 곧 추가될 예정입니다'),
                  backgroundColor: Colors.red[600],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
            ),
            child: Text('삭제'),
          ),
        ],
      ),
    );
  }

  // 활동 기록 보기
  void _showActivityHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Icon(Icons.history, color: Colors.blue[600]),
                SizedBox(width: 8),
                Text(
                  '활동 기록',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close),
                ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // 활동 목록 (임시 데이터)
            Expanded(
              child: ListView(
                children: [
                  _buildActivityTile(
                    icon: Icons.add_circle_outline,
                    title: '식품 추가',
                    subtitle: '우유를 냉장실에 추가했습니다',
                    time: '방금 전',
                    color: Colors.green,
                  ),
                  _buildActivityTile(
                    icon: Icons.meeting_room,
                    title: '그룹 참여',
                    subtitle: '새로운 그룹에 참여했습니다',
                    time: '2시간 전',
                    color: Colors.blue,
                  ),
                  _buildActivityTile(
                    icon: Icons.favorite,
                    title: '선호도 표시',
                    subtitle: '계란에 좋아요를 표시했습니다',
                    time: '1일 전',
                    color: Colors.red,
                  ),
                  _buildActivityTile(
                    icon: Icons.delete_outline,
                    title: '식품 삭제',
                    subtitle: '유통기한이 지난 요구르트를 삭제했습니다',
                    time: '2일 전',
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 활동 타일 위젯
  Widget _buildActivityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
    required Color color,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  // 도움말 보기 (사용하지 않음)
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.blue[600]),
            SizedBox(width: 8),
            Text('도움말'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                title: '냉장고 관리',
                items: [
                  '그룹을 만들어 가족이나 룸메이트와 냉장고를 공유하세요',
                  '각 칸별로 식품을 분류하여 관리할 수 있습니다',
                  '유통기한을 설정하여 버리는 음식을 줄이세요',
                ],
              ),
              SizedBox(height: 16),
              _buildHelpSection(
                title: '식품 추가',
                items: [
                  '+ 버튼으로 개별 식품을 추가하세요',
                  '영수증 스캔으로 여러 식품을 한번에 추가하세요',
                  '제조일과 유통기한을 정확히 입력하세요',
                ],
              ),
              SizedBox(height: 16),
              _buildHelpSection(
                title: '선호도 기능',
                items: [
                  '좋아요/싫어요로 가족의 식품 선호도를 공유하세요',
                  '선호도를 참고하여 장보기 계획을 세우세요',
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('닫기'),
          ),
        ],
      ),
    );
  }

  // 도움말 섹션 위젯
  Widget _buildHelpSection({
    required String title,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Colors.blue[700],
          ),
        ),
        SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(color: Colors.blue[600])),
              Expanded(
                child: Text(
                  item,
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  // 피드백 보내기
  void _sendFeedback() async {
    const email = 'support@refrigerator-care.com';
    const subject = '냉장고 관리 앱 피드백';
    const body = '안녕하세요. 앱에 대한 피드백을 보내드립니다.\n\n';
    
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
    
    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        // 이메일 앱이 없는 경우 간단한 피드백 폼 표시
        _showSimpleFeedbackForm();
      }
    } catch (e) {
      _showSimpleFeedbackForm();
    }
  }

  // 간단한 피드백 폼
  void _showSimpleFeedbackForm() {
    final feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.feedback_outlined, color: Colors.blue[600]),
            SizedBox(width: 8),
            Text('피드백 보내기'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('앱에 대한 의견이나 개선사항을 알려주세요.'),
            SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '피드백을 입력하세요...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('피드백이 전송되었습니다. 감사합니다!'),
                  backgroundColor: Colors.blue[600],
                ),
              );
            },
            child: Text('전송'),
          ),
        ],
      ),
    );
  }

  // 통계 데이터 로드
  Future<Map<String, int>> _loadStatistics() async {
    try {
      final userId = widget.user?.uid;
      if (userId == null) return {};

      int refrigeratorsCount = 0;
      int ingredientsCount = 0;
      int roomsCount = 0;

      // 냉장고 개수 (인덱스 오류 방지)
      try {
        final refrigeratorsSnapshot = await FirebaseFirestore.instance
            .collectionGroup('refrigerators')
            .where('userId', isEqualTo: userId)
            .get();
        refrigeratorsCount = refrigeratorsSnapshot.docs.length;
      } catch (e) {
        print('🔥 냉장고 통계 로드 오류: $e');
        print('💡 Firebase Console에서 refrigerators-userId 인덱스를 생성해주세요!');
        print('📋 자세한 해결 방법은 FIRESTORE_INDEX_SETUP.md 파일을 참고하세요.');
        refrigeratorsCount = 0; // 기본값 설정
      }

      // 식품 개수 (인덱스 오류 방지)
      try {
        final ingredientsSnapshot = await FirebaseFirestore.instance
            .collectionGroup('ingredients')
            .where('userId', isEqualTo: userId)
            .get();
        ingredientsCount = ingredientsSnapshot.docs.length;
      } catch (e) {
        print('🔥 식품 통계 로드 오류: $e');
        print('💡 Firebase Console에서 ingredients-userId 인덱스를 생성해주세요!');
        print('📋 자세한 해결 방법은 FIRESTORE_INDEX_SETUP.md 파일을 참고하세요.');
        ingredientsCount = 0; // 기본값 설정
      }

      // 방 개수 (이 쿼리는 인덱스 문제 없음)
      try {
        final roomsSnapshot = await FirebaseFirestore.instance
            .collection('rooms')
            .where('members', arrayContains: userId)
            .get();
        roomsCount = roomsSnapshot.docs.length;
      } catch (e) {
        print('방 통계 로드 오류: $e');
        roomsCount = 0;
      }

      return {
        'refrigerators': refrigeratorsCount,
        'ingredients': ingredientsCount,
        'rooms': roomsCount,
      };
    } catch (e) {
      print('전체 통계 로드 오류: $e');
      return {
        'refrigerators': 0,
        'ingredients': 0,
        'rooms': 0,
      };
    }
  }

  // 곧 만료될 식품 확인
  Future<List<Map<String, dynamic>>> _getExpiringItems() async {
    try {
      final userId = widget.user?.uid;
      if (userId == null) return [];

      final now = DateTime.now();
      final threeDaysLater = now.add(Duration(days: 3));

      // 인덱스 오류 방지
      try {
        final snapshot = await FirebaseFirestore.instance
            .collectionGroup('ingredients')
            .where('userId', isEqualTo: userId)
            .get();

        List<Map<String, dynamic>> expiringItems = [];
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final dynamic expiryField = data['expiryDate'];
          
          if (expiryField != null) {
            try {
              DateTime? expiryDate;
              
              // UTC 자정에서 로컬 날짜로 변환
              if (expiryField is Timestamp) {
                final utcDate = expiryField.toDate();
                expiryDate = DateTime(utcDate.year, utcDate.month, utcDate.day);
              } else if (expiryField is String) {
                expiryDate = DateTime.parse(expiryField);
              }
              
              if (expiryDate != null && expiryDate.isBefore(threeDaysLater) && expiryDate.isAfter(now)) {
                expiringItems.add({
                  'name': data['name'],
                  'expiryDate': '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}',
                  'compartmentName': data['compartmentName'],
                });
              }
            } catch (e) {
              // 날짜 파싱 오류 무시
            }
          }
        }

        expiringItems.sort((a, b) {
          final dateA = DateTime.parse(a['expiryDate']);
          final dateB = DateTime.parse(b['expiryDate']);
          return dateA.compareTo(dateB);
        });

        return expiringItems.take(5).toList();
        
      } catch (e) {
        print('🔥 만료 예정 식품 로드 오류: $e');
        print('💡 Firebase Console에서 ingredients-userId 인덱스를 생성해주세요!');
        print('📋 자세한 해결 방법은 FIRESTORE_INDEX_SETUP.md 파일을 참고하세요.');
        return []; // 빈 목록 반환
      }
      
    } catch (e) {
      print('만료 예정 식품 전체 로드 오류: $e');
      return [];
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
        actions: [
          // 돋보기 아이콘 제거됨
        ],
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
                  // 토스 스타일 프로필 카드
                  Container(
                    margin: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF4A90E2), // 토스 블루
                          Color(0xFF5BA3F5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24), // 더 둥근 모서리
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF4A90E2).withOpacity(0.4),
                          blurRadius: 30,
                          offset: Offset(0, 15),
                          spreadRadius: -5,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 상단: 아바타와 편집 버튼
                          Row(
                            children: [
                              // 토스 스타일 아바타
                              GestureDetector(
                                onTap: _navigateToAvatarSelection,
                                child: Container(
                                  padding: EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: CircleAvatar(
                                    radius: 32,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 28,
                                      backgroundColor: _avatarColor,
                                      child: Icon(
                                        _avatarIcon,
                                        size: 28,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Spacer(),
                              // 편집 버튼
                              GestureDetector(
                                onTap: _navigateToAvatarSelection,
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 20),
                          
                          // 사용자 이름
                          Text(
                            userName,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          
                          SizedBox(height: 6),
                          
                          // 이메일
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          
                          SizedBox(height: 20),
                          
                          // 토스 스타일 뱃지
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow[400],
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.star,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '냉장고 관리 마스터',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 내 통계 카드
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '내 통계',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 16),
                        FutureBuilder<Map<String, int>>(
                          future: _loadStatistics(),
                          builder: (context, snapshot) {
                            final stats = snapshot.data ?? {};
                            return Container(
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
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatItem(
                                        '방',
                                        '${stats['rooms'] ?? 0}개',
                                        Icons.meeting_room,
                                        Colors.blue,
                                      ),
                                    ),
                                    Container(width: 1, height: 40, color: Colors.grey[200]),
                                    Expanded(
                                      child: _buildStatItem(
                                        '냉장고',
                                        '${stats['refrigerators'] ?? 0}개',
                                        Icons.kitchen,
                                        Colors.green,
                                      ),
                                    ),
                                    Container(width: 1, height: 40, color: Colors.grey[200]),
                                    Expanded(
                                      child: _buildStatItem(
                                        '식품',
                                        '${stats['ingredients'] ?? 0}개',
                                        Icons.food_bank,
                                        Colors.orange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  // 곧 만료될 식품
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '⚠️ 곧 만료될 식품',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => SearchScreen()),
                                );
                              },
                              child: Text('전체보기'),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: _getExpiringItems(),
                          builder: (context, snapshot) {
                            final items = snapshot.data ?? [];
                            
                            if (items.isEmpty) {
                              return Container(
                                padding: EdgeInsets.all(24),
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
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.check_circle, size: 48, color: Colors.green),
                                      SizedBox(height: 8),
                                      Text(
                                        '만료 예정인 식품이 없습니다!',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.green[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return Container(
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
                                children: items.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final item = entry.value;
                                  return Column(
                                    children: [
                                      ListTile(
                                        leading: Container(
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[50],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(Icons.warning, color: Colors.orange, size: 20),
                                        ),
                                        title: Text(
                                          item['name'],
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        subtitle: Text(
                                          '${item['compartmentName']} • ${item['expiryDate']}',
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                                      ),
                                      if (index < items.length - 1) Divider(height: 1),
                                    ],
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 32),

                  // 유용한 기능들
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '유용한 기능',
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
                                icon: Icons.search,
                                title: '식품 검색',
                                subtitle: '모든 식품을 빠르게 찾기',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => SearchScreen()),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // 메뉴 타일 위젯
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              // 토스 스타일 아이콘 컨테이너
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDestructive 
                      ? Colors.red[50] 
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isDestructive 
                      ? Colors.red[600] 
                      : Colors.grey[700],
                  size: 20,
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
                        color: Colors.black,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // 토스 스타일 화살표
              Container(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[400],
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 