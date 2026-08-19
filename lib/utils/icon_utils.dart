import 'package:flutter/material.dart';

/// 아바타 아이콘 유틸리티 클래스
/// Tree shaking 문제를 해결하기 위해 미리 정의된 아이콘들을 사용
class IconUtils {
  // 사용 가능한 아바타 아이콘들 (미리 정의됨)
  static const List<IconData> avatarIcons = [
    Icons.person,
    Icons.face,
    Icons.emoji_emotions,
    Icons.mood,
    Icons.sentiment_satisfied,
    Icons.child_care,
    Icons.pets,
    Icons.favorite,
    Icons.star,
    Icons.local_florist,
    Icons.cake,
    Icons.coffee,
    Icons.restaurant,
    Icons.sports_basketball,
    Icons.music_note,
    Icons.palette,
    Icons.camera_alt,
    Icons.book,
    Icons.school,
    Icons.work,
    Icons.home,
    Icons.flight,
    Icons.beach_access,
    Icons.nature,
  ];

  /// 아이콘 코드포인트를 IconData로 변환
  /// Tree shaking을 위해 미리 정의된 아이콘들만 사용
  static IconData getIconFromCodePoint(int? codePoint) {
    if (codePoint == null) return Icons.person;
    
    // 미리 정의된 아이콘 중에서 찾기
    for (final icon in avatarIcons) {
      if (icon.codePoint == codePoint) {
        return icon;
      }
    }
    
    // 찾지 못한 경우 기본 아이콘 반환
    return Icons.person;
  }

  /// IconData를 코드포인트로 변환
  static int getCodePointFromIcon(IconData icon) {
    return icon.codePoint;
  }

  /// 기본 아바타 아이콘
  static const IconData defaultAvatarIcon = Icons.person;
}
