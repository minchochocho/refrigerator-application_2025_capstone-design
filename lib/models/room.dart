import 'package:cloud_firestore/cloud_firestore.dart';
import 'refrigerator.dart';

class Room {
  final String id;
  final String roomName;
  final String roomCode;
  final String roomCreator;
  final List<String> memberIds;
  final List<Refrigerator> refrigerators;
  final DateTime createdAt;

  Room({
    required this.id,
    required this.roomName,
    required this.roomCode,
    required this.roomCreator,
    required this.memberIds,
    required this.refrigerators,
    required this.createdAt,
  });

  // Firestore Document에서 Room 객체로 변환
  factory Room.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    // refrigerators 필드 처리 변경
    List<Refrigerator> parsedRefrigerators = [];
    if (data.containsKey('refrigerators') && data['refrigerators'] != null) {
      final refrigeratorsData = data['refrigerators'] as List<dynamic>;
      parsedRefrigerators = refrigeratorsData.map((r) {
        if (r is DocumentSnapshot) {
          return Refrigerator.fromFirestore(r);
        } else if (r is Map<String, dynamic>) {
          return Refrigerator.fromMap(r);
        } else {
          // 기본값 반환
          return Refrigerator(
            id: '',
            name: '',
            roomId: doc.id,
            layout: 'vertical',
          );
        }
      }).toList();
    }
    
    return Room(
      id: doc.id,
      roomName: data['room_name'] ?? '',
      roomCode: data['room_code'] ?? '',
      roomCreator: data['room_creator'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      refrigerators: parsedRefrigerators,
      createdAt: (data['created_at'] as Timestamp).toDate(),
    );
  }

  // Room 객체를 Firestore Document로 변환하기 위한 Map
  Map<String, dynamic> toMap() {
    return {
      'room_name': roomName,
      'room_code': roomCode,
      'room_creator': roomCreator,
      'memberIds': memberIds,
      'refrigerators': refrigerators.map((r) => r.toMap()).toList(),
      'created_at': Timestamp.fromDate(createdAt),
    };
  }

  // 객체 복사 메서드
  Room copyWith({
    String? id,
    String? roomName,
    String? roomCode,
    String? roomCreator,
    List<String>? memberIds,
    List<Refrigerator>? refrigerators,
    DateTime? createdAt,
  }) {
    return Room(
      id: id ?? this.id,
      roomName: roomName ?? this.roomName,
      roomCode: roomCode ?? this.roomCode,
      roomCreator: roomCreator ?? this.roomCreator,
      memberIds: memberIds ?? this.memberIds,
      refrigerators: refrigerators ?? this.refrigerators,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 