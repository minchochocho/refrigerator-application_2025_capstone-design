import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../expiration_alert/expiration_alert_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final bool notificationsEnabled;
  final bool emailNotificationsEnabled;
  final Function(bool notifications, bool emailNotifications) onSettingsChanged;

  const NotificationSettingsScreen({
    Key? key,
    required this.notificationsEnabled,
    required this.emailNotificationsEnabled,
    required this.onSettingsChanged,
  }) : super(key: key);

  @override
  _NotificationSettingsScreenState createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  late bool _pushNotifications;
  late bool _emailNotifications;
  late bool _expirationAlerts;
  
  String _selectedNotificationTime = '09:00';
  final List<String> _notificationTimes = [
    '08:00', '09:00', '10:00', '11:00', '12:00',
    '18:00', '19:00', '20:00', '21:00', '22:00'
  ];

  @override
  void initState() {
    super.initState();
    _pushNotifications = widget.notificationsEnabled;
    _emailNotifications = widget.emailNotificationsEnabled;
    _expirationAlerts = true;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _pushNotifications = prefs.getBool('push_notifications') ?? _pushNotifications;
        _emailNotifications = prefs.getBool('email_notifications') ?? _emailNotifications;
        _expirationAlerts = prefs.getBool('expiration_alerts') ?? true;
        _selectedNotificationTime = prefs.getString('notification_time') ?? '09:00';
      });
    } catch (e) {
      print('설정 로드 오류: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('push_notifications', _pushNotifications);
      await prefs.setBool('email_notifications', _emailNotifications);
      await prefs.setBool('expiration_alerts', _expirationAlerts);
      await prefs.setString('notification_time', _selectedNotificationTime);
      
      // Firestore Users 컬렉션에 알림 시간 저장 (Cloud Function에서 사용)
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final notificationHour = int.tryParse(_selectedNotificationTime.split(':')[0]) ?? 9;
        await FirebaseFirestore.instance
            .collection('Users')
            .doc(user.uid)
            .set({
          'notificationHour': notificationHour,
        }, SetOptions(merge: true));
        print('알림 시간 Firestore 저장: ${notificationHour}시');
      }
      
      // 부모 위젯에 변경사항 전달
      widget.onSettingsChanged(_pushNotifications, _emailNotifications);

      // 유통기한 알림 설정을 실제 스케줄에 반영
      try {
        final alertService = ExpirationAlertService();
        await alertService.initialize();

        if (_pushNotifications && _expirationAlerts) {
          // 알림을 켠 경우: 현재 식품들 기준으로 다시 스케줄링
          await alertService.updateAllExpirationAlerts();
          print('알림 설정 저장: 유통기한 알림 재스케줄 완료');
        } else {
          // 알림을 끈 경우: 기존 알림 전부 취소
          await alertService.cancelAllAlerts();
          print('알림 설정 저장: 모든 유통기한 알림 취소');
        }
      } catch (e) {
        print('알림 설정 적용 중 오류: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('알림 설정이 저장되었습니다'),
            ],
          ),
          backgroundColor: Colors.green[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('설정 저장 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // 커스텀 앱바 (마이페이지 스타일)
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 심플한 헤더
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // 아이콘
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Color(0xFF6B9FFF).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.notifications_outlined,
                                color: Color(0xFF6B9FFF),
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios, color: Color(0xFF6B9FFF)),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: TextButton(
                  onPressed: _saveSettings,
                  child: Text(
                    '저장',
                    style: TextStyle(
                      color: Color(0xFF6B9FFF),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // 알림 설정 컨텐츠
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            // 기본 알림 설정
            _buildSectionHeader('기본 알림 설정', Icons.notifications),
            SizedBox(height: 16),
            _buildSettingsCard([
              _buildSwitchTile(
                title: '푸시 알림',
                subtitle: '앱 내 알림 수신',
                value: _pushNotifications,
                onChanged: (value) {
                  setState(() {
                    _pushNotifications = value;
                  });
                },
                icon: Icons.notifications_active,
              ),
            ]),

            SizedBox(height: 24),

            // 알림 유형 설정
            _buildSectionHeader('알림 유형', Icons.category),
            SizedBox(height: 16),
            _buildSettingsCard([
              _buildSwitchTile(
                title: '유통기한 알림',
                subtitle: '식품 유통기한 만료 전 알림',
                value: _expirationAlerts,
                onChanged: _pushNotifications ? (value) {
                  setState(() {
                    _expirationAlerts = value;
                  });
                } : null,
                icon: Icons.schedule,
              ),
            ]),

            SizedBox(height: 24),

            // 알림 시간 설정
            _buildSectionHeader('알림 시간', Icons.access_time),
            SizedBox(height: 16),
            _buildSettingsCard([
              _buildTimeSelectorTile(),
            ]),

                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Color(0xFF6B9FFF).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Color(0xFF6B9FFF), size: 20),
        ),
        SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool)? onChanged,
    required IconData icon,
  }) {
    final isEnabled = onChanged != null;
    
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isEnabled ? Color(0xFF6B9FFF) : Colors.grey).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isEnabled ? Color(0xFF6B9FFF) : Colors.grey[400],
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isEnabled ? Color(0xFF1F2937) : Colors.grey[400],
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: isEnabled ? Color(0xFF6B7280) : Colors.grey[400],
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Color(0xFF6B9FFF),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildTimeSelectorTile() {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (_pushNotifications ? Colors.orange : Colors.grey).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.access_time,
          color: _pushNotifications ? Colors.orange[600] : Colors.grey[400],
          size: 20,
        ),
      ),
      title: Text(
        '일일 알림 시간',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _pushNotifications ? Colors.black : Colors.grey[400],
        ),
      ),
      subtitle: Text(
        '매일 $_selectedNotificationTime에 유통기한 확인 알림',
        style: TextStyle(
          fontSize: 14,
          color: _pushNotifications ? Colors.grey[600] : Colors.grey[400],
        ),
      ),
      trailing: DropdownButton<String>(
        value: _selectedNotificationTime,
        onChanged: _pushNotifications ? (String? newValue) {
          if (newValue != null) {
            setState(() {
              _selectedNotificationTime = newValue;
            });
          }
        } : null,
        items: _notificationTimes.map<DropdownMenuItem<String>>((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        underline: SizedBox.shrink(),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.grey[200],
      indent: 16,
      endIndent: 16,
    );
  }
}
