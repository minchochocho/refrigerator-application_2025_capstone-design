import 'package:cloud_firestore/cloud_firestore.dart';

class Refrigerator {
  final String id;
  final String name;
  final String ownerId;
  final List<String> memberIds;
  final int capacity;
  final int itemCount;
  final DateTime createdAt;
  final String type; // 'personal' 또는 'shared'
  final List<String> compartmentNames; // 냉장고 칸 이름 추가
  final String layout; // 냉장고 레이아웃 타입 (vertical, horizontal, single)
  final String roomId; // 냉장고가 속한 방의 ID
  final String compartmentTheme; // 칸 색상 테마: 'green' | 'blue'
  final List<String> compartmentColors; // 칸별 색상 코드(이름 문자열)

  Refrigerator({
    required this.id,
    required this.name,
    this.ownerId = '',
    this.memberIds = const [],
    this.capacity = 20,
    this.itemCount = 0,
    DateTime? createdAt,
    this.type = 'personal',
    required this.roomId,
    this.compartmentNames = const [], // 기본값 빈 배열
    this.layout = 'vertical', // 기본값 vertical
    this.compartmentTheme = 'green',
    this.compartmentColors = const [],
  }) : this.createdAt = createdAt ?? DateTime.now();

  // Firestore Document에서 Refrigerator 객체로 변환
  factory Refrigerator.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Refrigerator(
      id: doc.id,
      name: data['name'] ?? '',
      ownerId: data['owner_id'] ?? '',
      memberIds: List<String>.from(data['member_ids'] ?? []),
      capacity: data['capacity'] ?? 20,
      itemCount: data['item_count'] ?? 0,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'personal',
      roomId: data['room_id'] ?? '',
      compartmentNames: List<String>.from(data['compartment_names'] ?? []),
      layout: data['layout'] ?? 'vertical',
      compartmentTheme: data['compartment_theme'] ?? 'green',
      compartmentColors: List<String>.from(data['compartment_colors'] ?? []),
    );
  }

  // Map 형태의 데이터에서 Refrigerator 객체로 변환 (추가)
  factory Refrigerator.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return Refrigerator(
      id: id,
      name: data['name'] ?? '',
      ownerId: data['owner_id'] ?? '',
      memberIds: List<String>.from(data['member_ids'] ?? []),
      capacity: data['capacity'] ?? 20,
      itemCount: data['item_count'] ?? 0,
      createdAt: (data['created_at'] is Timestamp)
          ? (data['created_at'] as Timestamp).toDate()
          : DateTime.now(),
      type: data['type'] ?? 'personal',
      roomId: data['room_id'] ?? '',
      compartmentNames: List<String>.from(data['compartment_names'] ?? []),
      layout: data['layout'] ?? 'vertical',
      compartmentTheme: data['compartment_theme'] ?? 'green',
      compartmentColors: List<String>.from(data['compartment_colors'] ?? []),
    );
  }

  // Refrigerator 객체를 Firestore 문서로 변환하기 위한 Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'owner_id': ownerId,
      'member_ids': memberIds,
      'capacity': capacity,
      'item_count': itemCount,
      'created_at': Timestamp.fromDate(createdAt),
      'type': type,
      'room_id': roomId,
      'compartment_names': compartmentNames,
      'layout': layout,
      'compartment_theme': compartmentTheme,
      'compartment_colors': compartmentColors,
    };
  }

  // 복사본 생성
  Refrigerator copyWith({
    String? id,
    String? name,
    String? ownerId,
    List<String>? memberIds,
    int? capacity,
    int? itemCount,
    DateTime? createdAt,
    String? type,
    String? roomId,
    List<String>? compartmentNames,
    String? layout,
    String? compartmentTheme,
    List<String>? compartmentColors,
  }) {
    return Refrigerator(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      memberIds: memberIds ?? this.memberIds,
      capacity: capacity ?? this.capacity,
      itemCount: itemCount ?? this.itemCount,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
      roomId: roomId ?? this.roomId,
      compartmentNames: compartmentNames ?? this.compartmentNames,
      layout: layout ?? this.layout,
      compartmentTheme: compartmentTheme ?? this.compartmentTheme,
      compartmentColors: compartmentColors ?? this.compartmentColors,
    );
  }
} 