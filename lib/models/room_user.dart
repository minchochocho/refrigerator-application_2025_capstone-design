import 'package:cloud_firestore/cloud_firestore.dart';

class RoomUser {
  final String id;
  final String userId;
  final String roomId;
  final String roleName;
  final String? role; // 방 내에서의 역할
  final bool isAdmin;
  final DateTime joinedAt;

  RoomUser({
    required this.id,
    required this.userId,
    required this.roomId,
    required this.roleName,
    this.role,
    required this.isAdmin,
    required this.joinedAt,
  });

  // Firestore Document에서 RoomUser 객체로 변환
  factory RoomUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RoomUser(
      id: doc.id,
      userId: data['user_id'] ?? '',
      roomId: data['room_id'] ?? '',
      roleName: data['role_name'] ?? '',
      role: data['role'],
      isAdmin: data['isAdmin'] ?? false,
      joinedAt: (data['joined_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // RoomUser 객체를 Firestore Document로 변환하기 위한 Map
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'room_id': roomId,
      'role_name': roleName,
      'role': role,
      'isAdmin': isAdmin,
      'joined_at': Timestamp.fromDate(joinedAt),
    };
  }

  // 객체 복사 메서드
  RoomUser copyWith({
    String? id,
    String? userId,
    String? roomId,
    String? roleName,
    String? role,
    bool? isAdmin,
    DateTime? joinedAt,
  }) {
    return RoomUser(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      roomId: roomId ?? this.roomId,
      roleName: roleName ?? this.roleName,
      role: role ?? this.role,
      isAdmin: isAdmin ?? this.isAdmin,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
} 