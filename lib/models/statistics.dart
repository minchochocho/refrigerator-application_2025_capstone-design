import 'package:cloud_firestore/cloud_firestore.dart';

/// 방 기준 누적 통계 모델
class RoomStatistics {
  final String roomId;
  final int totalRegisteredItems; // 등록한 식품 개수
  final int expiredItems; // 유통기한 만료 식품 수량
  final int consumedBeforeExpiry; // 유통기한 만료 전 소비량
  final int consumedAfterExpiry; // 유통기한 만료 후 소비량
  final int discardedBeforeExpiry; // 유통기한 만료 전 폐기량
  final int discardedAfterExpiry; // 유통기한 만료 후 폐기량
  final Map<String, int> userRegistrationCount; // 사용자별 식품 등록 개수
  final DateTime lastUpdated;
  final DateTime currentMonth; // 현재 월 (비교용)

  RoomStatistics({
    required this.roomId,
    this.totalRegisteredItems = 0,
    this.expiredItems = 0,
    this.consumedBeforeExpiry = 0,
    this.consumedAfterExpiry = 0,
    this.discardedBeforeExpiry = 0,
    this.discardedAfterExpiry = 0,
    this.userRegistrationCount = const {},
    DateTime? lastUpdated,
    DateTime? currentMonth,
  }) : this.lastUpdated = lastUpdated ?? DateTime.now(),
       this.currentMonth = currentMonth ?? DateTime(DateTime.now().year, DateTime.now().month);

  /// Firestore에서 데이터를 가져올 때 사용
  factory RoomStatistics.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RoomStatistics(
      roomId: doc.id,
      totalRegisteredItems: data['total_registered_items'] ?? 0,
      expiredItems: data['expired_items'] ?? 0,
      consumedBeforeExpiry: data['consumed_before_expiry'] ?? 0,
      consumedAfterExpiry: data['consumed_after_expiry'] ?? 0,
      discardedBeforeExpiry: data['discarded_before_expiry'] ?? 0,
      discardedAfterExpiry: data['discarded_after_expiry'] ?? 0,
      userRegistrationCount: Map<String, int>.from(data['user_registration_count'] ?? {}),
      lastUpdated: (data['last_updated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentMonth: (data['current_month'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Firestore에 저장할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'total_registered_items': totalRegisteredItems,
      'expired_items': expiredItems,
      'consumed_before_expiry': consumedBeforeExpiry,
      'consumed_after_expiry': consumedAfterExpiry,
      'discarded_before_expiry': discardedBeforeExpiry,
      'discarded_after_expiry': discardedAfterExpiry,
      'user_registration_count': userRegistrationCount,
      'last_updated': Timestamp.fromDate(lastUpdated),
      'current_month': Timestamp.fromDate(currentMonth),
    };
  }

  /// 전체 소비량 계산
  int get totalConsumed => consumedBeforeExpiry + consumedAfterExpiry;

  /// 전체 폐기량 계산
  int get totalDiscarded => discardedBeforeExpiry + discardedAfterExpiry;

  /// 새로운 데이터로 업데이트된 통계 반환
  RoomStatistics copyWith({
    int? totalRegisteredItems,
    int? expiredItems,
    int? consumedBeforeExpiry,
    int? consumedAfterExpiry,
    int? discardedBeforeExpiry,
    int? discardedAfterExpiry,
    Map<String, int>? userRegistrationCount,
    DateTime? lastUpdated,
    DateTime? currentMonth,
  }) {
    return RoomStatistics(
      roomId: this.roomId,
      totalRegisteredItems: totalRegisteredItems ?? this.totalRegisteredItems,
      expiredItems: expiredItems ?? this.expiredItems,
      consumedBeforeExpiry: consumedBeforeExpiry ?? this.consumedBeforeExpiry,
      consumedAfterExpiry: consumedAfterExpiry ?? this.consumedAfterExpiry,
      discardedBeforeExpiry: discardedBeforeExpiry ?? this.discardedBeforeExpiry,
      discardedAfterExpiry: discardedAfterExpiry ?? this.discardedAfterExpiry,
      userRegistrationCount: userRegistrationCount ?? this.userRegistrationCount,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      currentMonth: currentMonth ?? this.currentMonth,
    );
  }
}

/// 식품 액션 타입 (소비/폐기)
enum FoodActionType { consumed, discarded }

/// 식품 액션 기록 모델
class FoodActionRecord {
  final String id;
  final String roomId;
  final String refrigeratorName;
  final String ingredientName;
  final String userId;
  final FoodActionType actionType;
  final DateTime actionDate;
  final DateTime expiryDate;
  final bool wasExpired; // 유통기한 만료 여부

  FoodActionRecord({
    required this.id,
    required this.roomId,
    required this.refrigeratorName,
    required this.ingredientName,
    required this.userId,
    required this.actionType,
    required this.actionDate,
    required this.expiryDate,
    required this.wasExpired,
  });

  /// Firestore에서 데이터를 가져올 때 사용
  factory FoodActionRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return FoodActionRecord(
      id: doc.id,
      roomId: data['room_id'] ?? '',
      refrigeratorName: data['refrigerator_name'] ?? '',
      ingredientName: data['ingredient_name'] ?? '',
      userId: data['user_id'] ?? '',
      actionType: data['action_type'] == 'consumed' 
          ? FoodActionType.consumed 
          : FoodActionType.discarded,
      actionDate: (data['action_date'] as Timestamp).toDate(),
      expiryDate: (data['expiry_date'] as Timestamp).toDate(),
      wasExpired: data['was_expired'] ?? false,
    );
  }

  /// Firestore에 저장할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'room_id': roomId,
      'refrigerator_name': refrigeratorName,
      'ingredient_name': ingredientName,
      'user_id': userId,
      'action_type': actionType == FoodActionType.consumed ? 'consumed' : 'discarded',
      'action_date': Timestamp.fromDate(actionDate),
      'expiry_date': Timestamp.fromDate(expiryDate),
      'was_expired': wasExpired,
    };
  }
}
