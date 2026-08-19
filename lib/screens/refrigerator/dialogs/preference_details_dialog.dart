import 'package:flutter/material.dart';

import '../../../services/auth_service.dart';

Future<void> showPreferenceDetailsDialog(
  BuildContext context, {
  required Map<String, dynamic> ingredient,
  required AuthService authService,
}) async {
  final Map<String, dynamic> preferences = ingredient['preferences'] ?? {};
  final List<String> likes = List<String>.from(preferences['likes'] ?? []);
  final List<String> dislikes = List<String>.from(preferences['dislikes'] ?? []);

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

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
    ),
  );
}


