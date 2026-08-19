import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../utils/icon_utils.dart';
import 'profile/avatar_selection_screen.dart';
import 'profile/preferences_screen.dart';
import 'profile/notification_settings_screen.dart';
import 'profile/app_info_screen.dart';
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
  Color _backgroundColor = Color(0xFF6B9FFF); // 기본 배경색
  
  // 아이콘 매핑
  static const Map<int, IconData> iconMapping = {
    0xE491: Icons.person,  // person
    0xE87C: Icons.face,    // face
    0xE853: Icons.account_circle,  // account_circle
    0xE815: Icons.sentiment_satisfied,  // sentiment_satisfied
    0xE814: Icons.emoji_emotions,  // emoji_emotions
    0xE7F2: Icons.mood,    // mood
    0xE813: Icons.sentiment_very_satisfied,  // sentiment_very_satisfied
    0xE56E: Icons.child_care,  // child_care
    0xE338: Icons.sports_esports,  // sports_esports
    0xE80C: Icons.school,  // school
    0xE8F9: Icons.work,    // work
    0xE87D: Icons.favorite,  // favorite
    0xE838: Icons.star,    // star
    0xE91D: Icons.pets,    // pets
    0xE406: Icons.nature,  // nature
    0xE3A9: Icons.local_florist,  // local_florist
    0xE405: Icons.music_note,  // music_note
    0xE332: Icons.sports_soccer,  // sports_soccer
    0xE28A: Icons.fitness_center,  // fitness_center
    0xE56C: Icons.restaurant,  // restaurant
    0xE541: Icons.coffee,  // coffee
    0xE7E9: Icons.cake,    // cake
    0xE507: Icons.beach_access,  // beach_access
    0xE539: Icons.flight,  // flight
  };
  bool _isLoading = true;
  bool _notificationsEnabled = true;
  bool _emailNotificationsEnabled = false;
  bool _isEditingNickname = false;
  bool _isEditingEmail = false;
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  // 선호도 통계
  int _totalLikes = 0;
  int _totalDislikes = 0;
  bool _isLoadingPreferences = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    _migrateOldIngredientsIfNeeded();
    // user가 준비된 후 선호도 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.user != null) {
        _loadPreferencesCount();
      }
    });
  }
  
  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 위젯이 업데이트될 때마다 선호도를 다시 로드
    if (widget.user != null && oldWidget.user != widget.user) {
      _loadPreferencesCount();
    }
  }
  
  // 기존 재료들에 preferences 필드 추가 (한 번만 실행)
  Future<void> _migrateOldIngredientsIfNeeded() async {
    try {
      // SharedPreferences로 마이그레이션 실행 여부 확인
      final prefs = await SharedPreferences.getInstance();
      final hasRunMigration = prefs.getBool('preferences_migration_done') ?? false;
      
      if (hasRunMigration) {
        print('선호도 마이그레이션 이미 완료됨');
        return;
      }
      
      print('🔄 선호도 필드 마이그레이션 시작...');
      
      final refrigeratorsSnapshot = await FirebaseFirestore.instance
          .collection('Refrigerators')
            .get();
        
      int updatedCount = 0;
      
      for (var refrigeratorDoc in refrigeratorsSnapshot.docs) {
        final compartmentsSnapshot = await refrigeratorDoc.reference
            .collection('compartments')
            .get();

        for (var compartmentDoc in compartmentsSnapshot.docs) {
          final ingredientsSnapshot = await compartmentDoc.reference
              .collection('ingredients')
              .get();

          for (var ingredientDoc in ingredientsSnapshot.docs) {
            final data = ingredientDoc.data();
            
            // preferences 필드가 없으면 추가
            if (!data.containsKey('preferences')) {
              await ingredientDoc.reference.set(
                {
                  'preferences': {
                    'likes': [],
                    'dislikes': [],
                  }
                },
                SetOptions(merge: true),
              );
              updatedCount++;
            }
          }
        }
      }
      
      // 마이그레이션 완료 표시
      await prefs.setBool('preferences_migration_done', true);
      
      print('✅ 선호도 마이그레이션 완료: $updatedCount개 재료 업데이트');
    } catch (e) {
      print('❌ 선호도 마이그레이션 오류: $e');
    }
  }

  // 선호도 통계 아이템 위젯
  Widget _buildPreferenceStatItem(String label, int count, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }


  // 닉네임 인라인 편집 시작
  void _startEditingNickname() {
    setState(() {
      _isEditingEmail = false; // 이메일 편집 해제
      _isEditingNickname = true;
      _nicknameController.text = _nickname ?? '';
    });
  }

  // 닉네임 저장
  Future<void> _saveNickname(String newNickname) async {
    if (newNickname.trim().isEmpty) {
      setState(() {
        _isEditingNickname = false;
      });
      return;
    }

    try {
      await _authService.updateUserNickname(newNickname.trim());
      setState(() {
        _nickname = newNickname.trim();
        _isEditingNickname = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('닉네임이 변경되었습니다'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() {
        _isEditingNickname = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('닉네임 변경에 실패했습니다'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 이메일 인라인 편집 시작
  void _startEditingEmail() {
      setState(() {
      _isEditingNickname = false; // 닉네임 편집 해제
      _isEditingEmail = true;
      _emailController.text = widget.user?.email ?? '';
    });
  }

  // 이메일 저장 (Firebase Auth의 이메일 변경은 복잡하므로 일단 UI만)
  Future<void> _saveEmail(String newEmail) async {
    if (newEmail.trim().isEmpty) {
      setState(() {
        _isEditingEmail = false;
      });
      return;
    }

    // 이메일 형식 검증
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(newEmail.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('올바른 이메일 형식을 입력해주세요'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
      }

      setState(() {
      _isEditingEmail = false;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('이메일 변경은 현재 지원되지 않습니다'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 선호도 카운트 로드
  Future<void> _loadPreferencesCount() async {
    if (widget.user == null) {
      print('⚠️ 선호도 로드 실패: 사용자 정보 없음');
      return;
    }
    
    setState(() {
      _isLoadingPreferences = true;
    });

    try {
      final currentUserId = widget.user!.uid;
      print('🔍 선호도 로드 시작: 사용자 ID = $currentUserId');
      
      int likesCount = 0;
      int dislikesCount = 0;
      int totalIngredientsChecked = 0;
      int ingredientsWithPreferences = 0;

      // 사용자가 접근 가능한 냉장고만 조회 (member_ids 에 포함된 경우)
      final firestore = FirebaseFirestore.instance;
      final refrigeratorsSnapshot = await firestore
          .collection('Refrigerators')
          .where('member_ids', arrayContains: currentUserId)
          .get();

      print('   냉장고 개수: ${refrigeratorsSnapshot.docs.length}');

      for (var refrigeratorDoc in refrigeratorsSnapshot.docs) {
        final refrigeratorData = refrigeratorDoc.data() as Map<String, dynamic>;
        final refrigeratorName = refrigeratorData['name'] ?? '알 수 없음';
        final String roomId = (refrigeratorData['room_id'] ?? '').toString();
        final compartmentNames = refrigeratorData['compartment_names'] as List<dynamic>?;
        
        print('   냉장고: $refrigeratorName (방 ID: $roomId)');

        // 방이 삭제되었으면 이 냉장고는 선호도 통계에서 제외
        if (roomId.isNotEmpty) {
          try {
            final roomDoc = await firestore.collection('Rooms').doc(roomId).get();
            if (!roomDoc.exists) {
              print('      ⚠️ 방이 삭제됨, 선호도에서 제외: $refrigeratorName');
              continue;
            }
          } catch (e) {
            print('      ⚠️ 방 확인 실패, 선호도에서 제외: $refrigeratorName (error: $e)');
            continue;
          }
        }
        print('      칸 이름 목록: $compartmentNames');
        
        // compartment_names가 없으면 해당 냉장고 건너뜀
        if (compartmentNames == null || compartmentNames.isEmpty) {
          print('      ⚠️ compartment_names 없음, 건너뜀');
          continue;
        }
        
        // compartment_names 배열의 인덱스를 기반으로 각 칸 조회
        for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
          // 각 칸의 모든 재료를 순회
          final ingredientsSnapshot = await refrigeratorDoc.reference
              .collection('compartments')
              .doc(compartmentIndex.toString())  // 인덱스로 직접 접근
              .collection('ingredients')
              .get();
          
          print('         칸 $compartmentIndex (${compartmentNames[compartmentIndex]}): 재료 ${ingredientsSnapshot.docs.length}개');

          for (var ingredientDoc in ingredientsSnapshot.docs) {
            totalIngredientsChecked++;
            final data = ingredientDoc.data();
            final ingredientName = data['name'] ?? '알 수 없음';
            final preferences = data['preferences'] as Map<String, dynamic>?;

            if (preferences != null) {
              ingredientsWithPreferences++;
              final likes = List<String>.from(preferences['likes'] ?? []);
              final dislikes = List<String>.from(preferences['dislikes'] ?? []);

              print('   재료: $ingredientName');
              print('      likes: ${likes.length}개 (포함: ${likes.contains(currentUserId)})');
              print('      dislikes: ${dislikes.length}개 (포함: ${dislikes.contains(currentUserId)})');

              if (likes.contains(currentUserId)) {
                likesCount++;
                print('      ✅ 이 사용자가 좋아요함!');
              }
              if (dislikes.contains(currentUserId)) {
                dislikesCount++;
                print('      ✅ 이 사용자가 싫어요함!');
              }
        } else {
              print('   재료: $ingredientName - preferences 필드 없음');
            }
          }
        }
      }

      setState(() {
        _totalLikes = likesCount;
        _totalDislikes = dislikesCount;
        _isLoadingPreferences = false;
      });

      print('');
      print('═══════════════════════════════════════');
      print('✅ 선호도 로드 완료:');
      print('   - 냉장고 개수: ${refrigeratorsSnapshot.docs.length}');
      print('   - 총 재료 수: $totalIngredientsChecked');
      print('   - preferences 있는 재료: $ingredientsWithPreferences');
      print('   - 좋아요: $likesCount개');
      print('   - 싫어요: $dislikesCount개');
      print('═══════════════════════════════════════');
      print('');
      
      // 재료가 0개인 경우 추가 진단
      if (totalIngredientsChecked == 0) {
        print('⚠️ 경고: 재료가 0개입니다. Firestore 구조를 확인해주세요:');
        print('   1. Refrigerators 컬렉션에 문서가 있는지');
        print('   2. 각 냉장고 문서에 compartments 서브컬렉션이 있는지');
        print('   3. 각 compartment 문서에 ingredients 서브컬렉션이 있는지');
        print('');
        
        // 첫 번째 냉장고의 구조를 상세히 출력
        if (refrigeratorsSnapshot.docs.isNotEmpty) {
          final firstFridge = refrigeratorsSnapshot.docs.first;
          print('📦 첫 번째 냉장고 상세 정보:');
          print('   ID: ${firstFridge.id}');
          print('   데이터: ${firstFridge.data()}');
          
          final compartments = await firstFridge.reference.collection('compartments').get();
          print('   compartments 개수: ${compartments.docs.length}');
          
          if (compartments.docs.isNotEmpty) {
            for (var comp in compartments.docs) {
              final ingredients = await comp.reference.collection('ingredients').get();
              print('      칸 ${comp.id}: ingredients ${ingredients.docs.length}개');
              if (ingredients.docs.isNotEmpty) {
                print('         첫 번째 재료 예시: ${ingredients.docs.first.data()}');
              }
            }
          }
        }
      }
    } catch (e) {
      print('❌ 선호도 데이터 로드 오류: $e');
      setState(() {
        _isLoadingPreferences = false;
      });
    }
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
            final dynamic iconValue = userData['avatarIcon'];
            IconData resolvedIcon = Icons.person;

            // 1) 기존(레거시) 매핑 값이면 iconMapping 사용
            if (iconValue is int && iconMapping.containsKey(iconValue)) {
              resolvedIcon = iconMapping[iconValue]!;
            }
            // 2) 아니라면 Material 아이콘 코드포인트로 간주하고 IconUtils로 변환
            else if (iconValue is int) {
              resolvedIcon = IconUtils.getIconFromCodePoint(iconValue);
            }

            _avatarIcon = resolvedIcon;
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


  // 선호도 화면으로 이동
  void _navigateToPreferences() async {
    // FirebaseAuth에서 현재 사용자를 직접 가져옴
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PreferencesScreen(user: currentUser),
      ),
    );
    
    // 선호도 화면에서 돌아온 후 데이터 새로고침
    if (mounted && widget.user != null) {
      _loadPreferencesCount();
    }
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

  // 배경색 선택 다이얼로그
  void _showBackgroundColorPicker() {
    final List<Color> backgroundColors = [
      Color(0xFF6B9FFF), // 기본 블루
      Color(0xFF8B5CF6), // 보라
      Color(0xFFEC4899), // 핑크
      Color(0xFF10B981), // 그린
      Color(0xFFF59E0B), // 오렌지
      Color(0xFFEF4444), // 레드
      Color(0xFF6366F1), // 인디고
      Color(0xFF06B6D4), // 시안
      Color(0xFF84CC16), // 라임
      Color(0xFFF97316), // 앰버
      Color(0xFF8B5A2B), // 브라운
      Color(0xFF6B7280), // 그레이
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette, color: Color(0xFF1F2937)),
                SizedBox(width: 12),
                Text(
                  '배경색 선택',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                childAspectRatio: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: backgroundColors.length,
              itemBuilder: (context, index) {
                final color = backgroundColors[index];
                final isSelected = _backgroundColor == color;
                
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _backgroundColor = color;
                      });
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isSelected 
                                ? color.withOpacity(0.5)
                                : Colors.black.withOpacity(0.1),
                            blurRadius: isSelected ? 12 : 4,
                            offset: Offset(0, isSelected ? 4 : 2),
            ),
          ],
        ),
                      child: isSelected ? Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 24,
                      ) : null,
                    ),
                ),
              );
            },
          ),
            
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 아바타 정보를 Firestore에 저장
  Future<void> _persistAvatar() async {
    try {
      final success = await _authService.setColorAvatar(_avatarColor, _avatarIcon);
      if (!mounted) return;

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('아바타 저장 중 오류가 발생했습니다'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ 아바타 저장 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('아바타 저장 중 오류가 발생했습니다'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 아바타 편집 바텀 시트
  void _showAvatarEditBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
          child: DefaultTabController(
            length: 2,
            child: Column(
        children: [
                // 헤더
          Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // 드래그 핸들
                      Container(
                        width: 40,
                        height: 4,
            decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      Row(
              children: [
                          Icon(Icons.edit, color: Color(0xFF1F2937)),
                          SizedBox(width: 12),
                Text(
                            '아바타 편집',
                  style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Spacer(),
                          TextButton(
                            onPressed: () async {
                              // 선택된 아바타 정보를 Firestore에 저장
                              await _persistAvatar();
                              if (!mounted) return;
                              setState(() {}); // 메인 화면 업데이트
                              Navigator.pop(context);
                            },
                            child: Text(
                              '완료',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B9FFF),
                              ),
                            ),
                          ),
        ],
      ),
                      
                      SizedBox(height: 20),
                      
                      // 미리보기
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: _avatarColor,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: _avatarColor.withOpacity(0.3),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          _avatarIcon,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 탭 바
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                  ),
                  child: TabBar(
                    indicatorColor: Color(0xFF6B9FFF),
                    labelColor: Color(0xFF6B9FFF),
                    unselectedLabelColor: Colors.grey[500],
                    tabs: [
                      Tab(text: '아이콘'),
                      Tab(text: '색상'),
                    ],
                  ),
                ),
                
                // 탭 뷰
                Expanded(
                  child: TabBarView(
      children: [
                      _buildIconSelection(setModalState),
                      _buildColorSelection(setModalState),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 닉네임 편집 다이얼로그
  void _showNicknameEditDialog() {
    final TextEditingController controller = TextEditingController(text: _nickname);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.edit, color: Color(0xFF6B9FFF)),
            SizedBox(width: 8),
            Text('닉네임 변경'),
          ],
        ),
        content: TextField(
          controller: controller,
              decoration: InputDecoration(
            hintText: '새 닉네임을 입력하세요',
                border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
                ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xFF6B9FFF)),
              ),
            ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _nickname = controller.text.trim();
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6B9FFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text('저장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 아이콘 선택 위젯
  Widget _buildIconSelection(StateSetter setModalState) {
    final List<IconData> avatarIcons = [
      Icons.person, Icons.face, Icons.account_circle, Icons.sentiment_satisfied,
      Icons.emoji_emotions, Icons.mood, Icons.sentiment_very_satisfied, Icons.child_care,
      Icons.sports_esports, Icons.school, Icons.work, Icons.favorite,
      Icons.star, Icons.pets, Icons.nature, Icons.local_florist,
      Icons.music_note, Icons.sports_soccer, Icons.fitness_center, Icons.restaurant,
      Icons.coffee, Icons.cake, Icons.beach_access, Icons.flight,
    ];

    return Container(
      padding: EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: avatarIcons.length,
        itemBuilder: (context, index) {
          final icon = avatarIcons[index];
          final isSelected = _avatarIcon == icon;
          
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setModalState(() {
                  _avatarIcon = icon;
                });
              },
              borderRadius: BorderRadius.circular(28),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: isSelected ? _avatarColor : Colors.grey[100],
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isSelected ? _avatarColor.withOpacity(0.3) : Colors.grey[200]!,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected 
                          ? _avatarColor.withOpacity(0.4)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: isSelected ? 12 : 8,
                      offset: Offset(0, isSelected ? 6 : 2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey[600],
                  size: 32,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 색상 선택 위젯
  Widget _buildColorSelection(StateSetter setModalState) {
    final List<Map<String, dynamic>> colorAvatars = [
      {'color': Colors.red[400]!, 'name': '레드'},
      {'color': Colors.pink[400]!, 'name': '핑크'},
      {'color': Colors.purple[400]!, 'name': '보라'},
      {'color': Colors.deepPurple[400]!, 'name': '딥퍼플'},
      {'color': Colors.indigo[400]!, 'name': '인디고'},
      {'color': Colors.blue[400]!, 'name': '블루'},
      {'color': Colors.lightBlue[400]!, 'name': '라이트블루'},
      {'color': Colors.cyan[400]!, 'name': '시안'},
      {'color': Colors.teal[400]!, 'name': '틸'},
      {'color': Colors.green[400]!, 'name': '그린'},
      {'color': Colors.lightGreen[400]!, 'name': '라이트그린'},
      {'color': Colors.lime[400]!, 'name': '라임'},
      {'color': Colors.yellow[400]!, 'name': '옐로우'},
      {'color': Colors.amber[400]!, 'name': '앰버'},
      {'color': Colors.orange[400]!, 'name': '오렌지'},
      {'color': Colors.deepOrange[400]!, 'name': '딥오렌지'},
      {'color': Colors.brown[400]!, 'name': '브라운'},
      {'color': Colors.grey[400]!, 'name': '그레이'},
      {'color': Colors.blueGrey[400]!, 'name': '블루그레이'},
      {'color': Colors.black87, 'name': '블랙'},
    ];

    return Container(
      padding: EdgeInsets.all(20),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: colorAvatars.length,
        itemBuilder: (context, index) {
          final colorData = colorAvatars[index];
          final color = colorData['color'] as Color;
          final isSelected = _avatarColor == color;
          
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                setModalState(() {
                  _avatarColor = color;
                });
              },
              borderRadius: BorderRadius.circular(28),
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                      color: isSelected 
                          ? color.withOpacity(0.4)
                          : Colors.black.withOpacity(0.04),
                      blurRadius: isSelected ? 12 : 8,
                      offset: Offset(0, isSelected ? 6 : 2),
                        ),
                      ],
                    ),
                      child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                    Container(
                      width: 40,
                      height: 40,
                                  decoration: BoxDecoration(
                        color: color,
                                    shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.grey[200]!,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: isSelected ? Icon(
                        Icons.check,
                                        color: Colors.white,
                        size: 20,
                      ) : null,
                    ),
                    SizedBox(height: 8),
                    Text(
                      colorData['name'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? color : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 종합 프로필 편집 바텀 시트
  void _showCompleteProfileEditBottomSheet() {
    final TextEditingController nicknameController = TextEditingController(text: _nickname);
    final TextEditingController emailController = TextEditingController(text: widget.user?.email ?? '');
    
    showModalBottomSheet(
      context: context,
        backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
                                    color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // 드래그 핸들
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Icon(Icons.person, color: Color(0xFF1F2937)),
                          SizedBox(width: 12),
                          Text(
                            '프로필 편집',
          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Spacer(),
                          TextButton(
                            onPressed: () async {
                              final newNickname = nicknameController.text.trim();

                              // 닉네임/아바타를 Firestore에 저장
                              if (newNickname.isNotEmpty) {
                                await _authService.updateUserNickname(newNickname);
                              }
                              await _persistAvatar();

                              if (!mounted) return;
                              setState(() {
                                _nickname = newNickname;
                                // 이메일은 실제로는 Firebase Auth를 통해 변경해야 함
                              });
                              Navigator.pop(context);
                            },
                            child: Text(
                              '완료',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B9FFF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 탭 바
                  Container(
                    decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                    ),
                  ),
                  child: TabBar(
                    indicatorColor: Color(0xFF6B9FFF),
                    labelColor: Color(0xFF6B9FFF),
                    unselectedLabelColor: Colors.grey[500],
                    isScrollable: true,
                    tabs: [
                      Tab(text: '기본정보'),
                      Tab(text: '아이콘'),
                      Tab(text: '색상'),
                      Tab(text: '배경'),
                    ],
                  ),
                ),
                
                // 탭 뷰
                Expanded(
                  child: TabBarView(
                              children: [
                      _buildBasicInfoTab(nicknameController, emailController, setModalState),
                      _buildIconSelection(setModalState),
                      _buildColorSelection(setModalState),
                      _buildBackgroundSelection(setModalState),
                    ],
                  ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  // 기본정보 탭
  Widget _buildBasicInfoTab(TextEditingController nicknameController, TextEditingController emailController, StateSetter setModalState) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
          // 프로필 미리보기
          Center(
                                child: Container(
              width: 100,
              height: 100,
                                  decoration: BoxDecoration(
                color: _avatarColor,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: _avatarColor.withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
                                  ),
                                      child: Icon(
                                        _avatarIcon,
                size: 50,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
          
          SizedBox(height: 32),
          
          // 닉네임 입력
                                Text(
            '닉네임',
                                  style: TextStyle(
              fontSize: 16,
                                    fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: nicknameController,
            decoration: InputDecoration(
              hintText: '닉네임을 입력하세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF6B9FFF)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          
          SizedBox(height: 24),
          
          // 이메일 입력
                          Text(
            '이메일',
                            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          SizedBox(height: 8),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: '이메일을 입력하세요',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF6B9FFF)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              suffixIcon: Icon(Icons.email_outlined, color: Colors.grey[400]),
            ),
          ),
          
          SizedBox(height: 16),
          
          // 이메일 변경 안내
                          Container(
            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
                            ),
                            child: Row(
                              children: [
                Icon(Icons.info_outline, color: Colors.blue[600], size: 20),
                                SizedBox(width: 8),
                                    Expanded(
                  child: Text(
                    '이메일 변경은 보안을 위해 별도 인증이 필요할 수 있습니다.',
                                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[700],
                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
    );
  }

  // 배경색 선택 탭
  Widget _buildBackgroundSelection(StateSetter setModalState) {
    final List<Color> backgroundColors = [
      Color(0xFF6B9FFF), // 기본 블루
      Color(0xFF8B5CF6), // 보라
      Color(0xFFEC4899), // 핑크
      Color(0xFF10B981), // 그린
      Color(0xFFF59E0B), // 오렌지
      Color(0xFFEF4444), // 레드
      Color(0xFF6366F1), // 인디고
      Color(0xFF06B6D4), // 시안
      Color(0xFF84CC16), // 라임
      Color(0xFFF97316), // 앰버
      Color(0xFF8B5A2B), // 브라운
      Color(0xFF6B7280), // 그레이
    ];

    return Container(
      padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
            '배경색을 선택하세요',
                          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
                          ),
                        ),
                        SizedBox(height: 16),
          
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: backgroundColors.length,
              itemBuilder: (context, index) {
                final color = backgroundColors[index];
                final isSelected = _backgroundColor == color;
                
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setModalState(() {
                        _backgroundColor = color;
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 3,
                        ),
                                boxShadow: [
                                  BoxShadow(
                            color: isSelected 
                                ? color.withOpacity(0.5)
                                : Colors.black.withOpacity(0.1),
                            blurRadius: isSelected ? 12 : 4,
                            offset: Offset(0, isSelected ? 4 : 2),
                                  ),
                                ],
                              ),
                      child: isSelected ? Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 32,
                      ) : null,
                                ),
                              ),
                            );
                          },
            ),
                        ),
                      ],
                    ),
                              );
                            }

  @override
  Widget build(BuildContext context) {
    final userName = _nickname ?? widget.user?.displayName ?? widget.user?.email?.split('@')[0] ?? '사용자';
    final bool isGuestUser = widget.user?.isAnonymous ?? false;
    final userEmail = widget.user?.email?.isNotEmpty == true ? widget.user!.email! : '이메일 미등록';
    final String displayEmail = isGuestUser ? '비회원' : userEmail;
    
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
                strokeWidth: 3,
              ),
            )
          : CustomScrollView(
              slivers: [
                // 커스텀 앱바
                SliverAppBar(
                  expandedHeight: 280, // 프로필 편집 버튼과 선호도 카드 제거, 여유 공간 추가
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    background: GestureDetector(
                      onTap: () {
                        // 배경 클릭 시 편집 모드 해제
                        if (_isEditingNickname || _isEditingEmail) {
                          setState(() {
                            _isEditingNickname = false;
                            _isEditingEmail = false;
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                        ),
                        child: SafeArea(
                          child: Padding(
                          padding: EdgeInsets.fromLTRB(24, 16, 24, 24), // 위쪽 패딩 증가
                    child: Column(
                      children: [
                              // 헤더 - 마이페이지 제목 중앙, 톱니바퀴 오른쪽
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                                  // 왼쪽 여백용 투명 컨테이너
                                  Container(width: 40, height: 40),
                                  
                                  // 중앙 제목
                            Text(
                                    '마이페이지',
                              style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black87,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  
                                  // 오른쪽 톱니바퀴 - 앱 정보
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AppInfoScreen(),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.settings,
                                        color: Colors.grey[600],
                                        size: 22,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                              
                              SizedBox(height: 16), // 간격 줄임 24 → 16
                              
                              // 프로필 정보 - 인스타그램 스타일
                              Column(
                                children: [
                                  // 아바타 - 선택한 색상 톤의 테두리
                                  GestureDetector(
                                    onTap: () {
                                      // 편집 모드 해제 후 아바타 편집
                                      setState(() {
                                        _isEditingNickname = false;
                                        _isEditingEmail = false;
                                      });
                                      _showAvatarEditBottomSheet();
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _avatarColor.withOpacity(0.8),
                                            _avatarColor,
                                            _avatarColor.withOpacity(0.6),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Container(
                                        padding: EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                          borderRadius: BorderRadius.circular(47),
                                        ),
                                        child: Container(
                                          width: 90,
                                          height: 90,
                                          decoration: BoxDecoration(
                                            color: _avatarColor,
                                            borderRadius: BorderRadius.circular(45),
                                          ),
                                          child: Icon(
                                            _avatarIcon,
                                            size: 45,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  SizedBox(height: 14), // 간격 줄임 16 → 14
                                  
                                  // 닉네임 - 인라인 편집 가능
                                  _isEditingNickname
                                      ? Container(
                                          width: 200,
                                          child: TextField(
                                            controller: _nicknameController,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black87,
                                              letterSpacing: -0.3,
                                            ),
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: Colors.grey[300]!),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(color: _avatarColor, width: 2),
                                              ),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), // 세로 패딩 줄임 8 → 4
                                              filled: true,
                                              fillColor: Colors.white,
                                              isDense: true, // 컴팩트 모드
                                            ),
                                            autofocus: true,
                                            onSubmitted: (value) => _saveNickname(value),
                                            onEditingComplete: () => _saveNickname(_nicknameController.text),
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: _startEditingNickname,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4), // 일반 상태도 동일하게 조정
                                          decoration: BoxDecoration(
                                              color: Colors.transparent,
                                            borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.transparent,
                                                width: 2,
                                              ),
                                            ),
                                            child: Text(
                                              _nickname ?? '닉네임 없음',
                                              style: TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black87,
                                                letterSpacing: -0.3,
                                              ),
                                            ),
                                          ),
                                        ),
                                  
                                  SizedBox(height: 6), // 간격 줄임 8 → 6
                                  
                                  // 이메일 - 인라인 편집 가능
                                  _isEditingEmail
                                      ? Container(
                                          width: 250,
                                          child: TextField(
                                            controller: _emailController,
                                            textAlign: TextAlign.center,
                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                              letterSpacing: -0.1,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            decoration: InputDecoration(
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(25),
                                                borderSide: BorderSide(color: Colors.grey[300]!),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(25),
                                                borderSide: BorderSide(color: _avatarColor, width: 1.5),
                                              ),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                              filled: true,
                                              fillColor: Colors.white,
                                              isDense: true,
                                              hintText: 'example@email.com',
                                              hintStyle: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 14,
                                              ),
                                            ),
                                            keyboardType: TextInputType.emailAddress,
                                            autofocus: true,
                                            onSubmitted: (value) => _saveEmail(value),
                                            onEditingComplete: () => _saveEmail(_emailController.text),
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: _startEditingEmail,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                                              color: Colors.grey[200]?.withOpacity(0.8),
                                              borderRadius: BorderRadius.circular(25),
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                                width: 0.5,
                                              ),
                                            ),
                                            child: Text(
                                              displayEmail,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                                letterSpacing: -0.1,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
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
                  ),
                ),
                
                // 메뉴 섹션
                SliverToBoxAdapter(
                  child: GestureDetector(
                    onTap: () {
                      // 메뉴 영역 클릭 시 편집 모드 해제
                      if (_isEditingNickname || _isEditingEmail) {
                        setState(() {
                          _isEditingNickname = false;
                          _isEditingEmail = false;
                        });
                      }
                    },
                    child: Padding(
                      padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 20),
                        
                        // 메인 메뉴들
                        _buildMenuSection(
                          title: '계정 관리',
                          items: [
                            _buildModernMenuTile(
                                icon: Icons.person_outline,
                              title: '프로필',
                              subtitle: '닉네임, 아바타, 이메일, 배경색 변경',
                              color: Color(0xFF6366F1),
                              onTap: _showCompleteProfileEditBottomSheet,
                            ),
                            _buildModernMenuTile(
                              icon: Icons.notifications_outlined,
                              title: '알림설정',
                              subtitle: '푸시 알림 및 유통기한 알림',
                              color: Color(0xFF8B5CF6),
                              onTap: _navigateToNotificationSettings,
                              ),
                            ],
                          ),
                        
                        SizedBox(height: 24),
                        
                        // 데이터 메뉴들
                        _buildMenuSection(
                          title: '데이터 & 분석',
                          items: [
                            _buildModernMenuTile(
                              icon: Icons.favorite_outline,
                              title: '선호도',
                              subtitle: '좋아요/싫어요 통계',
                              color: Color(0xFFEC4899),
                              onTap: _navigateToPreferences,
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 24),
                        
                        // 계정 메뉴들
                        _buildMenuSection(
                          title: '계정 설정',
                          items: [
                            _buildModernMenuTile(
                              icon: Icons.swap_horiz_rounded,
                              title: '계정전환',
                              subtitle: '다른 계정으로 전환',
                              color: Color(0xFF0EA5E9),
                              onTap: _showAccountSwitchDialog,
                            ),
                            _buildModernMenuTile(
                              icon: Icons.logout_rounded,
                                title: '로그아웃',
                              subtitle: '현재 계정에서 로그아웃',
                              color: Color(0xFFF59E0B),
                                onTap: () async {
                                  await widget.onSignOut();
                                },
                            ),
                            _buildModernMenuTile(
                              icon: Icons.delete_forever_rounded,
                              title: '계정탈퇴',
                              subtitle: '계정을 영구적으로 삭제',
                              color: Color(0xFFEF4444),
                              onTap: _showAccountDeletionDialog,
                                isDestructive: true,
                              ),
                            ],
                          ),
                        
                        SizedBox(height: 100),
                      ],
                    ),
                  ),
              ),
                ),
                ],
            ),
    );
  }

  // 메뉴 섹션 빌더
  Widget _buildMenuSection({
    required String title,
    required List<Widget> items,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
              letterSpacing: -0.2,
            ),
          ),
        ),
        Container(
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
          child: Column(children: items),
        ),
      ],
    );
  }

  // 모던한 메뉴 타일
  Widget _buildModernMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              // 아이콘 컨테이너
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              
              SizedBox(width: 16),
              
              // 텍스트 정보
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 화살표
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 기존 메뉴 타일 (호환성을 위해 유지)
  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return _buildModernMenuTile(
      icon: icon,
      title: title,
      subtitle: subtitle,
      color: isDestructive ? Color(0xFFEF4444) : Color(0xFF6366F1),
      onTap: onTap,
      isDestructive: isDestructive,
    );
  }
}
