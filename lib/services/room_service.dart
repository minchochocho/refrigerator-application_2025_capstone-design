import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/room.dart';
import '../models/room_user.dart';
import '../models/refrigerator.dart';
import 'refrigerator_service.dart';

class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _collection = 'Rooms';

  // 컬렉션 참조
  CollectionReference get _roomsCollection => _firestore.collection('Rooms');
  CollectionReference get _roomUserCollection => _firestore.collection('RoomUser');

  // 현재 로그인한 사용자의 UID 가져오기
  String? get currentUserId => _auth.currentUser?.uid;

  // 랜덤 6자리 그룹 코드 생성
  String _generateRoomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    Random random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // 방 생성
  Future<Room?> createRoom(String roomName) async {
    if (currentUserId == null) {
      throw Exception('로그인이 필요합니다');
    }

    // 6자리 랜덤 그룹 코드 생성
    String roomCode = _generateRoomCode();
    
    // 코드 중복 검사
    bool isCodeExist = await _checkRoomCodeExists(roomCode);
    while (isCodeExist) {
      roomCode = _generateRoomCode();
      isCodeExist = await _checkRoomCodeExists(roomCode);
    }

    try {
      // 그룹 문서 생성 및 데이터 추가
      final roomData = {
        'room_name': roomName,
        'room_code': roomCode,
        'room_creator': currentUserId,
        'memberIds': [currentUserId],
        'refrigerators': [],
        'created_at': Timestamp.now(),
      };
      
      // 문서 추가
      final docRef = await _firestore.collection(_collection).add(roomData);
      
      // RoomUser 컬렉션에도 멤버십 추가
      await _roomUserCollection.add({
        'user_id': currentUserId,
        'room_id': docRef.id,
        'role_name': 'admin',  // 그룹 생성자는 관리자 역할
        'joined_at': Timestamp.now(),
      });

      // 생성된 방 문서 가져오기
      final doc = await docRef.get();
      
      // Room 모델로 변환하여 반환
      final data = doc.data() as Map<String, dynamic>;
      return Room(
        id: doc.id,
        roomName: data['room_name'] ?? '',
        roomCode: data['room_code'] ?? '',
        roomCreator: data['room_creator'] ?? '',
        memberIds: List<String>.from(data['memberIds'] ?? []),
        refrigerators: [], // 새 방에는 냉장고가 없음
        createdAt: (data['created_at'] as Timestamp).toDate(),
      );
    } catch (e) {
      print('그룹 생성 중 오류 발생: $e');
      return null;
    }
  }

  // 방 정보 가져오기
  Future<Room?> getRoom(String roomId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(roomId).get();
      if (!doc.exists) return null;
      return Room.fromFirestore(doc);
    } catch (e) {
      print('방 정보 조회 중 오류 발생: $e');
      return null;
    }
  }

  // 방에 냉장고 추가
  Future<bool> addRefrigeratorToRoom(String roomId, Refrigerator refrigerator) async {
    try {
      final roomRef = _firestore.collection(_collection).doc(roomId);
      final room = await roomRef.get();
      
      if (!room.exists) return false;

      final List<dynamic> refrigerators = room.data()?['refrigerators'] ?? [];
      refrigerators.add(refrigerator.toMap());

      await roomRef.update({
        'refrigerators': refrigerators,
      });

      return true;
    } catch (e) {
      print('냉장고 추가 중 오류 발생: $e');
      return false;
    }
  }

  // 방의 냉장고 목록 업데이트
  Future<bool> updateRoomRefrigerators(String roomId, List<Refrigerator> refrigerators) async {
    try {
      await _firestore.collection(_collection).doc(roomId).update({
        'refrigerators': refrigerators.map((r) => r.toMap()).toList(),
      });
      return true;
    } catch (e) {
      print('냉장고 목록 업데이트 중 오류 발생: $e');
      return false;
    }
  }

  // 방에 멤버 추가
  Future<bool> addMemberToRoom(String roomId, String memberId) async {
    try {
      final roomRef = _firestore.collection(_collection).doc(roomId);
      final room = await roomRef.get();
      
      if (!room.exists) return false;

      final List<dynamic> memberIds = room.data()?['memberIds'] ?? [];
      if (!memberIds.contains(memberId)) {
        memberIds.add(memberId);
        await roomRef.update({
          'memberIds': memberIds,
        });
      }

      return true;
    } catch (e) {
      print('멤버 추가 중 오류 발생: $e');
      return false;
    }
  }

  // 방에서 멤버 제거
  Future<bool> removeMemberFromRoom(String roomId, String memberId) async {
    try {
      final roomRef = _firestore.collection(_collection).doc(roomId);
      final room = await roomRef.get();
      
      if (!room.exists) return false;

      final List<dynamic> memberIds = room.data()?['memberIds'] ?? [];
      memberIds.remove(memberId);
      
      await roomRef.update({
        'memberIds': memberIds,
      });

      // 냉장고 멤버 동기화
      final refrigeratorService = RefrigeratorService();
      await refrigeratorService.syncRoomMembersToRefrigerators(roomId);

      print('✅ 방 멤버 제거 완료 및 냉장고 멤버 동기화 완료');
      return true;
    } catch (e) {
      print('멤버 제거 중 오류 발생: $e');
      return false;
    }
  }

  // 방 삭제
  Future<bool> deleteRoom(String roomId) async {
    try {
      print('🗑️ 방 삭제 시작: roomId=$roomId');
      
      // 1. 해당 방의 모든 냉장고 조회
      QuerySnapshot refrigeratorsSnapshot = await _firestore
          .collection('Refrigerators')
          .where('room_id', isEqualTo: roomId)
          .get();
      
      print('📦 삭제할 냉장고 ${refrigeratorsSnapshot.docs.length}개 발견');
      
      // 2. 각 냉장고와 그 안의 모든 데이터 삭제
      for (var refrigeratorDoc in refrigeratorsSnapshot.docs) {
        final refrigeratorId = refrigeratorDoc.id;
        print('  🔹 냉장고 삭제 중: $refrigeratorId');
        
        // 냉장고의 모든 칸 조회
        QuerySnapshot compartmentsSnapshot = await _firestore
            .collection('Refrigerators')
            .doc(refrigeratorId)
            .collection('compartments')
            .get();
        
        // 각 칸의 모든 재료 삭제
        WriteBatch batch = _firestore.batch();
        int ops = 0;
        
        for (var compartmentDoc in compartmentsSnapshot.docs) {
          // 칸의 재료들 조회
          QuerySnapshot ingredientsSnapshot = await compartmentDoc.reference
              .collection('ingredients')
              .get();
          
          // 재료 삭제
          for (var ingredientDoc in ingredientsSnapshot.docs) {
            batch.delete(ingredientDoc.reference);
            ops++;
            
            // 배치 작업이 500개를 넘으면 커밋
            if (ops >= 450) {
              await batch.commit();
              batch = _firestore.batch();
              ops = 0;
            }
          }
          
          // 칸 삭제
          batch.delete(compartmentDoc.reference);
          ops++;
        }
        
        // 남은 배치 작업 커밋
        if (ops > 0) {
          await batch.commit();
        }
        
        // 냉장고 문서 삭제
        await refrigeratorDoc.reference.delete();
        print('  ✅ 냉장고 삭제 완료: $refrigeratorId');
      }
      
      // 3. RoomUser 컬렉션에서 해당 방의 모든 멤버십 삭제
      QuerySnapshot roomUserDocs = await _roomUserCollection
          .where('room_id', isEqualTo: roomId)
          .get();
      
      for (var doc in roomUserDocs.docs) {
        await doc.reference.delete();
      }
      
      // 4. 방 문서 삭제
      await _firestore.collection(_collection).doc(roomId).delete();
      
      print('✅ 방 및 관련 데이터가 모두 삭제되었습니다: roomId=$roomId');
      return true;
    } catch (e) {
      print('❌ 방 삭제 중 오류 발생: $e');
      return false;
    }
  }

  // 방 코드로 입장하기
  Future<bool> joinRoomByCode(String roomCode) async {
    if (currentUserId == null) {
      throw Exception('로그인이 필요합니다');
    }

    try {
      // 방 코드로 방 검색
      QuerySnapshot roomQuery = await _roomsCollection
          .where('room_code', isEqualTo: roomCode)
          .limit(1)
          .get();

      if (roomQuery.docs.isEmpty) {
        throw Exception('존재하지 않는 방 코드입니다');
      }

      DocumentReference roomRef = roomQuery.docs.first.reference;
      String roomId = roomRef.id;

      // 이미 참여 중인지 확인
      QuerySnapshot existingMembership = await _roomUserCollection
          .where('user_id', isEqualTo: currentUserId)
          .where('room_id', isEqualTo: roomId)
          .get();

      if (existingMembership.docs.isNotEmpty) {
        throw Exception('이미 참여 중인 방입니다');
      }

      // RoomUser 컬렉션에 멤버로 추가 (Timestamp.now() 사용)
      await _roomUserCollection.add({
        'user_id': currentUserId,
        'room_id': roomId,
        'role_name': 'member',
        'joined_at': Timestamp.now(),
      });

      // 방의 memberIds 배열에도 추가
      Map<String, dynamic> roomData = roomQuery.docs.first.data() as Map<String, dynamic>;
      List<String> memberIds = List<String>.from(roomData['memberIds'] ?? []);
      if (!memberIds.contains(currentUserId)) {
        memberIds.add(currentUserId!);
        await roomRef.update({'memberIds': memberIds});
      }

      // 냉장고 멤버 동기화
      final refrigeratorService = RefrigeratorService();
      await refrigeratorService.syncRoomMembersToRefrigerators(roomId);

      print('✅ 그룹 참여 완료 및 냉장고 멤버 동기화 완료');
      return true;
    } catch (e) {
      print('그룹 참여 오류: $e');
      rethrow; // 에러를 UI에서 처리할 수 있도록 전달
    }
  }

  // 참여 중인 방 목록 가져오기 (실시간 업데이트 지원)
  Stream<List<Room>> getUserRooms() {
    if (currentUserId == null) {
      print('getUserRooms: 사용자가 로그인되지 않음');
      return Stream.value([]);
    }

    try {
      // 사용자가 참여한 RoomUser 문서 조회
      return _roomUserCollection
          .where('user_id', isEqualTo: currentUserId)
          .snapshots()
          .asyncMap((roomUserSnapshot) async {
        try {
          List<Room> rooms = [];
          
          // 참여한 방이 없으면 빈 목록 반환
          if (roomUserSnapshot.docs.isEmpty) {
            print('getUserRooms: 참여 중인 방 없음');
            return rooms;
          }
          
          // 참여 중인 모든 방의 ID 추출
          List<String> roomIds = [];
          for (var doc in roomUserSnapshot.docs) {
            try {
              final data = doc.data() as Map<String, dynamic>;
              if (data.containsKey('room_id') && data['room_id'] != null) {
                roomIds.add(data['room_id'] as String);
              }
            } catch (e) {
              print('방 ID 추출 중 오류: $e');
            }
          }
              
          // 중복 제거
          roomIds = roomIds.toSet().toList();
          print('참여 중인 방 ID: $roomIds');
          
          // 각 방 정보를 실시간으로 조회하기 위해 별도 스트림 사용
          // 하지만 asyncMap에서는 간단하게 현재 스냅샷만 조회
          for (String roomId in roomIds) {
            try {
              DocumentSnapshot roomSnapshot = await _roomsCollection.doc(roomId).get();
              if (roomSnapshot.exists) {
                rooms.add(Room.fromFirestore(roomSnapshot));
              }
            } catch (e) {
              print('방 정보 조회 중 오류 (ID: $roomId): $e');
            }
          }
          
          // 생성일 기준 최신순 정렬
          rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          
          print('조회된 방 개수: ${rooms.length}');
          return rooms;
        } catch (e) {
          print('방 목록 처리 중 오류: $e');
          return <Room>[];
        }
      }).handleError((error) {
        print('방 목록 스트림 오류: $error');
        return <Room>[];
      });
    } catch (e) {
      print('getUserRooms 메서드 오류: $e');
      return Stream.value([]);
    }
  }

  // 참여 중인 방을 한 번에 실시간 조회 (지연/엇갈림 없이 동시 표시)
  Stream<List<Room>> getUserRoomsWithRealTimeUpdates() {
    if (currentUserId == null) {
      print('getUserRoomsWithRealTimeUpdates: 사용자가 로그인되지 않음');
      return Stream.value(<Room>[]);
    }

    // Rooms 컬렉션에서 현재 사용자가 멤버로 포함된 문서를 직접 구독
    // 서버 스냅샷 한 번으로 모든 방이 함께 전달되어, 일부만 먼저 보이는 현상을 방지
    return _roomsCollection
        .where('memberIds', arrayContains: currentUserId)
        .snapshots()
        .map((query) {
          final rooms = query.docs.map((doc) => Room.fromFirestore(doc)).toList();
          rooms.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return rooms;
        })
        .handleError((error) {
          print('getUserRoomsWithRealTimeUpdates 스트림 오류: $error');
          return <Room>[];
        });
  }

  // 방 코드 중복 확인
  Future<bool> _checkRoomCodeExists(String roomCode) async {
    QuerySnapshot query = await _roomsCollection
        .where('room_code', isEqualTo: roomCode)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  // 방 나가기
  Future<bool> leaveRoom(String roomId) async {
    if (currentUserId == null) {
      throw Exception('로그인이 필요합니다');
    }

    try {
      // 그룹 생성자인지 확인
      DocumentSnapshot roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) {
        throw Exception('방을 찾을 수 없습니다');
      }

      Map<String, dynamic> roomData = roomDoc.data() as Map<String, dynamic>;
      String roomCreator = roomData['room_creator'] ?? '';
      
      if (roomCreator == currentUserId) {
        throw Exception('그룹 생성자는 그룹을 나갈 수 없습니다. 그룹을 삭제해주세요.');
      }

      // 사용자의 멤버십 찾기
      QuerySnapshot membershipQuery = await _roomUserCollection
          .where('user_id', isEqualTo: currentUserId)
          .where('room_id', isEqualTo: roomId)
          .get();

      if (membershipQuery.docs.isEmpty) {
        throw Exception('그룹에 참여하지 않은 상태입니다');
      }

      String membershipId = membershipQuery.docs.first.id;

      // 방의 memberIds 배열에서 제거
      List<String> memberIds = List<String>.from(roomData['memberIds'] ?? []);
      memberIds.remove(currentUserId);
      await _roomsCollection.doc(roomId).update({'memberIds': memberIds});

      // 방 멤버십 삭제
      await _roomUserCollection.doc(membershipId).delete();

      // 냉장고 멤버 동기화
      final refrigeratorService = RefrigeratorService();
      await refrigeratorService.syncRoomMembersToRefrigerators(roomId);

      return true;
    } catch (e) {
      print('방 나가기 오류: $e');
      rethrow;
    }
  }

  // 방 접근 권한 체크
  Future<bool> _isUserAuthorized(String roomId, String userId, {bool adminRequired = false}) async {
    try {
      // 방 문서 가져오기
      DocumentSnapshot roomDoc = await _firestore.collection('Rooms').doc(roomId).get();
      if (!roomDoc.exists) return false;
      
      // 사용자 권한 확인
      QuerySnapshot memberSnapshot = await _firestore
          .collection('RoomUser')
          .where('room_id', isEqualTo: roomId)
          .where('user_id', isEqualTo: userId)
          .get();
      
      if (memberSnapshot.docs.isEmpty) return false;
      
      // 관리자 권한 필요한 경우 추가 확인
      if (adminRequired) {
        return memberSnapshot.docs.first.get('isAdmin') == true;
      }
      
      return true;
    } catch (e) {
      print('권한 확인 오류: $e');
      return false;
    }
  }

  // 방 멤버의 역할 설정하기
  Future<bool> setUserRole(String roomId, String userId, String role) async {
    if (_auth.currentUser == null) return false;
    
    try {
      // 현재 사용자가 이 방에 대한 권한이 있는지 확인 (관리자 또는 본인만 설정 가능)
      final isAdmin = await _isUserAuthorized(roomId, _auth.currentUser!.uid, adminRequired: true);
      final isSelf = _auth.currentUser!.uid == userId;
      
      if (!isAdmin && !isSelf) {
        print('역할 설정 권한 없음');
        return false;
      }
      
      // 사용자 멤버십 찾기
      QuerySnapshot memberSnapshot = await _firestore
          .collection('RoomUser')
          .where('room_id', isEqualTo: roomId)
          .where('user_id', isEqualTo: userId)
          .get();
      
      if (memberSnapshot.docs.isEmpty) {
        print('해당 사용자가 방에 존재하지 않음');
        return false;
      }
      
      // 역할 업데이트
      await _firestore.collection('RoomUsers').doc(memberSnapshot.docs.first.id).update({
        'role': role,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('사용자 역할 업데이트 성공: $role');
      return true;
    } catch (e) {
      print('역할 설정 오류: $e');
      return false;
    }
  }

  // 방 멤버의 역할 가져오기
  Future<String?> getUserRole(String roomId, String userId) async {
    try {
      // 사용자 멤버십 찾기
      QuerySnapshot memberSnapshot = await _firestore
          .collection('RoomUser')
          .where('room_id', isEqualTo: roomId)
          .where('user_id', isEqualTo: userId)
          .get();
      
      if (memberSnapshot.docs.isEmpty) {
        return null;
      }
      
      // 역할 반환
      return memberSnapshot.docs.first.get('role') as String?;
    } catch (e) {
      print('역할 조회 오류: $e');
      return null;
    }
  }

  // 본인 역할 설정하기
  Future<bool> setMyRole(String roomId, String role) async {
    if (_auth.currentUser == null) return false;
    return setUserRole(roomId, _auth.currentUser!.uid, role);
  }

  // 본인 역할 가져오기
  Future<String?> getMyRole(String roomId) async {
    if (_auth.currentUser == null) return null;
    return getUserRole(roomId, _auth.currentUser!.uid);
  }

  // 방 이름 업데이트
  Future<bool> updateRoomName(String roomId, String newRoomName) async {
    if (currentUserId == null) {
      return false;
    }

    try {
      // 방 정보 가져오기
      final roomDoc = await _roomsCollection.doc(roomId).get();
      if (!roomDoc.exists) {
        print('방을 찾을 수 없습니다: roomId=$roomId');
        return false;
      }

      // 방장인지 확인
      final roomData = roomDoc.data() as Map<String, dynamic>;
      final roomCreator = roomData['room_creator'];
      
      if (roomCreator != currentUserId) {
        print('방 이름 수정 권한이 없습니다. 방장만 수정할 수 있습니다.');
        return false;
      }

      // 방 이름 업데이트
      await _roomsCollection.doc(roomId).update({
        'room_name': newRoomName,
      });

      // RoomUser 문서들의 updated_at 필드를 업데이트하여 스트림에서 변경 감지
      final roomUserDocs = await _roomUserCollection
          .where('room_id', isEqualTo: roomId)
          .get();
      
      for (var doc in roomUserDocs.docs) {
        await doc.reference.update({
          'updated_at': Timestamp.now(),
        });
      }

      print('방 이름 업데이트 완료: $newRoomName (RoomUser 트리거 완료)');
      return true;
    } catch (e) {
      print('방 이름 업데이트 오류: $e');
      return false;
    }
  }
} 