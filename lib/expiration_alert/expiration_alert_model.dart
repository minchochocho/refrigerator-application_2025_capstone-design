import 'package:cloud_firestore/cloud_firestore.dart';

/// 유통기한 알림 데이터 모델
class ExpirationAlert {
  final String ingredientId;
  final String ingredientName;
  final DateTime expiryDate;
  final String refrigeratorName;
  final String compartmentName;
  final int daysLeft;
  final AlertType alertType;

  ExpirationAlert({
    required this.ingredientId,
    required this.ingredientName,
    required this.expiryDate,
    required this.refrigeratorName,
    required this.compartmentName,
    required this.daysLeft,
    required this.alertType,
  });

  /// 알림 긴급도에 따른 색상
  AlertSeverity get severity {
    if (daysLeft < 0) return AlertSeverity.expired;
    if (daysLeft == 0) return AlertSeverity.today;
    if (daysLeft == 1) return AlertSeverity.tomorrow;
    if (daysLeft <= 3) return AlertSeverity.warning;
    return AlertSeverity.normal;
  }

  /// 알림 메시지 생성
  String get message {
    switch (daysLeft) {
      case 0:
        return '$ingredientName이(가) 오늘 만료됩니다!';
      case 1:
        return '$ingredientName이(가) 내일 만료됩니다.';
      case < 0:
        return '$ingredientName이(가) ${-daysLeft}일 전에 만료되었습니다!';
      default:
        return '$ingredientName이(가) ${daysLeft}일 후 만료됩니다.';
    }
  }
}

/// 알림 타입
enum AlertType {
  dayBefore,  // 1일 전 알림
  dayOf,      // 당일 알림
  expired,    // 만료됨
}

/// 알림 심각도
enum AlertSeverity {
  expired,    // 만료됨 (빨강)
  today,      // 오늘 (주황)
  tomorrow,   // 내일 (노랑)
  warning,    // 경고 (연노랑)
  normal,     // 일반 (초록)
}

/// 알림 설정 모델
class AlertSettings {
  final bool enableNotifications;
  final bool enableDayBeforeAlert;
  final bool enableDayOfAlert;
  final int alertHour; // 알림 시간 (24시간 형식)
  final int alertMinute;
  final bool isTestMode; // 테스트 모드 (3분 간격 알림)
  final int testIntervalMinutes; // 테스트 모드 간격 (분)

    AlertSettings({
    this.enableNotifications = true,
    this.enableDayBeforeAlert = true,
    this.enableDayOfAlert = true,
    this.alertHour = 9, // 기본 오전 9시
    this.alertMinute = 0, // 기본 0분
    this.isTestMode = false, // 기본값은 일반 모드
    this.testIntervalMinutes = 3, // 기본 테스트 간격 3분
  });

  Map<String, dynamic> toMap() {
    return {
      'enableNotifications': enableNotifications,
      'enableDayBeforeAlert': enableDayBeforeAlert,
      'enableDayOfAlert': enableDayOfAlert,
      'alertHour': alertHour,
      'alertMinute': alertMinute,
      'isTestMode': isTestMode,
      'testIntervalMinutes': testIntervalMinutes,
    };
  }

  factory AlertSettings.fromMap(Map<String, dynamic> map) {
    return AlertSettings(
      enableNotifications: map['enableNotifications'] ?? true,
      enableDayBeforeAlert: map['enableDayBeforeAlert'] ?? true,
      enableDayOfAlert: map['enableDayOfAlert'] ?? true,
      alertHour: map['alertHour'] ?? 9,
      alertMinute: map['alertMinute'] ?? 0,
      isTestMode: map['isTestMode'] ?? false,
      testIntervalMinutes: map['testIntervalMinutes'] ?? 3,
    );
  }
} 