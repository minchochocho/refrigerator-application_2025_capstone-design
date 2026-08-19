import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../utils/icon_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 추가 방법 선택 다이얼로그
class AddMethodDialog extends StatelessWidget {
  final VoidCallback onReceiptScan;
  final VoidCallback onBarcodeScan;
  final VoidCallback onBatchRegistration;
  final VoidCallback onManualAdd;
  
  const AddMethodDialog({
    Key? key,
    required this.onReceiptScan,
    required this.onBarcodeScan,
    required this.onBatchRegistration,
    required this.onManualAdd,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20),
          Text(
            '식품 추가 방법을 선택하세요',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          Column(
            children: [
              _buildMethodTile(
                icon: Icons.receipt_long,
                title: '영수증 스캔',
                subtitle: '카메라/이미지 선택 → 제품명·수량 확인',
                color: Colors.orange,
                onTap: () {
                  Navigator.pop(context);
                  onReceiptScan();
                },
              ),
              SizedBox(height: 12),
              _buildMethodTile(
                icon: Icons.qr_code_scanner,
                title: '바코드 스캔',
                subtitle: '제품 바코드를 스캔하여 자동 등록',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  onBarcodeScan();
                },
              ),
              SizedBox(height: 12),
              _buildMethodTile(
                icon: Icons.playlist_add,
                title: '일괄등록',
                subtitle: '바코드 스캔으로 여러 제품을 한번에 등록',
                color: Colors.green,
                onTap: () {
                  Navigator.pop(context);
                  onBatchRegistration();
                },
              ),
              SizedBox(height: 12),
              _buildMethodTile(
                icon: Icons.add_rounded,
                title: '개별 추가',
                subtitle: '식품을 하나씩 직접 입력하여 추가',
                color: Colors.blue,
                onTap: () {
                  Navigator.pop(context);
                  onManualAdd();
                },
              ),
            ],
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
  
  Widget _buildMethodTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

/// 선호도 상세정보 다이얼로그
class PreferenceDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> ingredient;
  final AuthService authService;
  
  const PreferenceDetailsDialog({
    Key? key,
    required this.ingredient,
    required this.authService,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> preferences = ingredient['preferences'] ?? {};
    final List<String> likes = List<String>.from(preferences['likes'] ?? []);
    final List<String> dislikes = List<String>.from(preferences['dislikes'] ?? []);
    
    return FutureBuilder<Map<String, String>>(
      future: _loadUserNicknames(likes, dislikes),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Dialog(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        final userNicknames = snapshot.data!;
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.poll_outlined, color: Colors.blue[600]),
              SizedBox(width: 8),
              Text('${ingredient['name']} 선호도'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (likes.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.favorite, color: Colors.red[600], size: 18),
                    SizedBox(width: 8),
                    Text(
                      '좋아요 (${likes.length}명)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red[600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ...likes.map((userId) => Padding(
                  padding: EdgeInsets.only(left: 26, bottom: 4),
                  child: Text(
                    '• ${userNicknames[userId] ?? '사용자'}',
                    style: TextStyle(fontSize: 14),
                  ),
                )).toList(),
                SizedBox(height: 16),
              ],
              if (dislikes.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.thumb_down, color: Colors.blue[600], size: 18),
                    SizedBox(width: 8),
                    Text(
                      '싫어요 (${dislikes.length}명)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                ...dislikes.map((userId) => Padding(
                  padding: EdgeInsets.only(left: 26, bottom: 4),
                  child: Text(
                    '• ${userNicknames[userId] ?? '사용자'}',
                    style: TextStyle(fontSize: 14),
                  ),
                )).toList(),
              ],
              if (likes.isEmpty && dislikes.isEmpty)
                Text(
                  '아직 선호도가 표시되지 않았습니다.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('닫기'),
            ),
          ],
        );
      },
    );
  }
  
  Future<Map<String, String>> _loadUserNicknames(List<String> likes, List<String> dislikes) async {
    Map<String, String> userNicknames = {};
    Set<String> allUserIds = {...likes, ...dislikes};
    
    for (String userId in allUserIds) {
      try {
        Map<String, dynamic>? userInfo = await authService.getUserInfo(userId);
        if (userInfo != null) {
          userNicknames[userId] = userInfo['nickname'] ?? '사용자';
        } else {
          userNicknames[userId] = '사용자';
        }
      } catch (e) {
        userNicknames[userId] = '사용자';
      }
    }
    
    return userNicknames;
  }
}

/// 칸 이름 수정 다이얼로그
class CompartmentNameEditDialog extends StatelessWidget {
  final String currentName;
  final VoidCallback onFullSettings;
  final Future<void> Function(String newName) onRename;
  
  const CompartmentNameEditDialog({
    Key? key,
    required this.currentName,
    required this.onFullSettings,
    required this.onRename,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: currentName);
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.edit_outlined, color: Colors.blue[600]),
          SizedBox(width: 8),
          Text('칸 이름 수정'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '이 칸의 이름을 변경하시겠습니까?',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: '칸 이름',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            maxLength: 20,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onFullSettings();
          },
          child: Text('전체 설정'),
        ),
        ElevatedButton(
          onPressed: () async {
            final newName = controller.text.trim();
            if (newName.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('칸 이름을 입력해주세요')),
              );
              return;
            }
            
            Navigator.pop(context);
            await onRename(newName);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text('변경'),
        ),
      ],
    );
  }
}

/// 사용자 정보 다이얼로그 (잠금 정보)
class UserInfoDialog extends StatelessWidget {
  final String userId;
  
  const UserInfoDialog({
    Key? key,
    required this.userId,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserInfo(userId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Dialog(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        
        final userInfo = snapshot.data!;
        final nickname = userInfo['nickname'] ?? '사용자';
        final avatarColor = Color(userInfo['avatarColor'] ?? Colors.blue[400]!.value);
        final avatarIcon = IconUtils.getIconFromCodePoint(userInfo['avatarIcon'] as int?);
        
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.red[600]!, width: 3),
                ),
                child: CircleAvatar(
                  radius: 37,
                  backgroundColor: avatarColor,
                  child: Icon(avatarIcon, size: 40, color: Colors.white),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock, color: Colors.red[600], size: 24),
              ),
              SizedBox(height: 12),
              Text(
                '이 제품은',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              SizedBox(height: 4),
              Text(
                nickname,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                '님이 잠궈두셨습니다',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                '확인',
                style: TextStyle(
                  color: Colors.red[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        return {
          'nickname': userData['nickname'] ?? userData['displayName'] ?? '사용자',
          'avatarColor': userData['avatarColor'] ?? Colors.blue[400]!.value,
          'avatarIcon': userData['avatarIcon'] ?? IconUtils.defaultAvatarIcon.codePoint,
        };
      }
      
      return {
        'nickname': '사용자',
        'avatarColor': Colors.blue[400]!.value,
        'avatarIcon': IconUtils.defaultAvatarIcon.codePoint,
      };
    } catch (e) {
      return {
        'nickname': '사용자',
        'avatarColor': Colors.grey[400]!.value,
        'avatarIcon': IconUtils.defaultAvatarIcon.codePoint,
      };
    }
  }
}

