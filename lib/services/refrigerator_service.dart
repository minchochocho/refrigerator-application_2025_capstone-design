import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/refrigerator.dart';
import '../expiration_alert/expiration_alert_service.dart';
import '../expiration_alert/expiration_alert_model.dart';
import 'statistics_service.dart';
import 'dart:math' as math;

class RefrigeratorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ExpirationAlertService _alertService = ExpirationAlertService();
  final StatisticsService _statisticsService = StatisticsService();

  // 컬렉션 참조
  CollectionReference get _refrigeratorsCollection => _firestore.collection('Refrigerators');

  // 현재 로그인한 사용자의 UID 가져오기
  String? get currentUserId => _auth.currentUser?.uid;

  // 사용자의 냉장고 목록 가져오기 (개인 + 공유)
  Stream<List<Refrigerator>> getUserRefrigerators() {
    if (currentUserId == null) {
      return Stream.value([]);
    }

    try {
      // 사용자가 소유하거나 멤버로 등록된 냉장고 조회
      return _refrigeratorsCollection
          .where(Filter.or(
            Filter('owner_id', isEqualTo: currentUserId),
            Filter('member_ids', arrayContains: currentUserId),
          ))
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => Refrigerator.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      print('냉장고 목록 조회 오류: $e');
      return Stream.value([]);
    }
  }

  // 개인 냉장고 가져오기
  Future<Refrigerator?> getPersonalRefrigerator() async {
    if (currentUserId == null) {
      return null;
    }

    try {
      // 현재 사용자의 개인 냉장고 조회
      QuerySnapshot snapshot = await _refrigeratorsCollection
          .where('owner_id', isEqualTo: currentUserId)
          .where('type', isEqualTo: 'personal')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        // 개인 냉장고가 없으면 생성
        return await createPersonalRefrigerator();
      }

      return Refrigerator.fromFirestore(snapshot.docs.first);
    } catch (e) {
      print('개인 냉장고 조회 오류: $e');
      return null;
    }
  }

  // 개인 냉장고 생성
  Future<Refrigerator?> createPersonalRefrigerator() async {
    if (currentUserId == null) {
      return null;
    }

    try {
      // 냉장고 데이터 생성
      DocumentReference refrigeratorRef = await _refrigeratorsCollection.add({
        'name': '내 냉장고',
        'owner_id': currentUserId,
        'member_ids': [currentUserId],
        'capacity': 20,
        'item_count': 0,
        'created_at': Timestamp.now(),
        'type': 'personal',
        'room_id': currentUserId, // 개인 냉장고는 사용자 ID를 roomId로 사용
        'compartment_names': ['냉장실', '냉동실'], // 기본 2칸 구성
        'layout': 'vertical', // 기본 세로 레이아웃
        'compartment_theme': 'green',
        'compartment_colors': ['green','blue'],
      });

      // 생성된 냉장고 정보 조회 및 반환
      DocumentSnapshot refrigeratorSnapshot = await refrigeratorRef.get();
      return Refrigerator.fromFirestore(refrigeratorSnapshot);
    } catch (e) {
      print('개인 냉장고 생성 오류: $e');
      return null;
    }
  }

  // 공유 냉장고 생성
  Future<Refrigerator?> createSharedRefrigerator(String name) async {
    if (currentUserId == null) {
      return null;
    }

    try {
      // 냉장고 데이터 생성
      DocumentReference refrigeratorRef = await _refrigeratorsCollection.add({
        'name': name,
        'owner_id': currentUserId,
        'member_ids': [currentUserId],
        'capacity': 30,
        'item_count': 0,
        'created_at': Timestamp.now(),
        'type': 'shared',
      });

      // 생성된 냉장고 정보 조회 및 반환
      DocumentSnapshot refrigeratorSnapshot = await refrigeratorRef.get();
      return Refrigerator.fromFirestore(refrigeratorSnapshot);
    } catch (e) {
      print('공유 냉장고 생성 오류: $e');
      return null;
    }
  }

  // 냉장고 삭제
  Future<bool> deleteRefrigerator(String refrigeratorId) async {
    if (currentUserId == null) {
      return false;
    }

    try {
      // 냉장고 문서 조회
      DocumentSnapshot refrigeratorSnapshot = await _refrigeratorsCollection.doc(refrigeratorId).get();
      if (!refrigeratorSnapshot.exists) {
        return false;
      }

      final Map<String, dynamic> data = refrigeratorSnapshot.data() as Map<String, dynamic>;

      // 개인 냉장고는 삭제 불가
      if (data['type'] == 'personal') {
        return false;
      }

      // 권한 확인: 소유자, 냉장고 멤버, 또는 해당 방의 방장인 경우 허용
      bool canDelete = data['owner_id'] == currentUserId;
      final List<String> memberIds = List<String>.from(data['member_ids'] ?? []);
      if (!canDelete && memberIds.contains(currentUserId)) {
        canDelete = true;
      }

      final String? roomId = data['room_id'] as String?;
      if (!canDelete && roomId != null) {
        try {
          final roomDoc = await _firestore.collection('Rooms').doc(roomId).get();
          if (roomDoc.exists) {
            final roomData = roomDoc.data() as Map<String, dynamic>;
            if (roomData['room_creator'] == currentUserId) {
              canDelete = true;
            }
          }
        } catch (e) {
          print('방 문서 조회 실패(삭제 권한 확인 중): $e');
        }
      }
      if (!canDelete) {
        print('삭제 권한 없음: user=$currentUserId fridge=$refrigeratorId');
        return false;
      }

      // 칸/재료 전체 삭제 (일괄 배치로 안정성 향상)
      final compartmentsSnapshot = await _firestore
          .collection('Refrigerators')
          .doc(refrigeratorId)
          .collection('compartments')
          .get();

      WriteBatch batch = _firestore.batch();
      int ops = 0;

      Future<void> commitIfNeeded() async {
        if (ops >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          ops = 0;
        }
      }

      for (final compartmentDoc in compartmentsSnapshot.docs) {
        try {
          final ingredientsSnapshot = await compartmentDoc.reference
              .collection('ingredients')
              .get();
          for (final ingredient in ingredientsSnapshot.docs) {
            batch.delete(ingredient.reference);
            ops++;
            await commitIfNeeded();
          }
          batch.delete(compartmentDoc.reference);
          ops++;
          await commitIfNeeded();
        } catch (e) {
          // 일부 칸 삭제 실패해도 계속 진행하여 최대한 정리
          print('칸 삭제 중 오류(${compartmentDoc.id}): $e');
        }
      }

      if (ops > 0) {
        await batch.commit();
      }

      // 냉장고 문서 삭제
      await _refrigeratorsCollection.doc(refrigeratorId).delete();
      return true;
    } catch (e) {
      print('냉장고 삭제 오류: $e');
      return false;
    }
  }

  // 냉장고 멤버 추가
  Future<bool> addMember(String refrigeratorId, String userId) async {
    if (currentUserId == null) {
      return false;
    }

    try {
      // 냉장고 문서 조회
      DocumentSnapshot refrigeratorSnapshot = await _refrigeratorsCollection.doc(refrigeratorId).get();
      
      if (!refrigeratorSnapshot.exists) {
        return false;
      }

      Map<String, dynamic> data = refrigeratorSnapshot.data() as Map<String, dynamic>;
      
      // 현재 사용자가 소유자인지 확인
      if (data['owner_id'] != currentUserId) {
        return false;
      }

      // 개인 냉장고에는 멤버 추가 불가
      if (data['type'] == 'personal') {
        return false;
      }

      // 이미 멤버인지 확인
      List<String> memberIds = List<String>.from(data['member_ids'] ?? []);
      if (memberIds.contains(userId)) {
        return true; // 이미 멤버임
      }

      // 멤버 추가
      memberIds.add(userId);
      await _refrigeratorsCollection.doc(refrigeratorId).update({
        'member_ids': memberIds,
      });

      return true;
    } catch (e) {
      print('냉장고 멤버 추가 오류: $e');
      return false;
    }
  }

  // 냉장고 멤버 제거
  Future<bool> removeMember(String refrigeratorId, String userId) async {
    if (currentUserId == null) {
      return false;
    }

    try {
      // 냉장고 문서 조회
      DocumentSnapshot refrigeratorSnapshot = await _refrigeratorsCollection.doc(refrigeratorId).get();
      
      if (!refrigeratorSnapshot.exists) {
        return false;
      }

      Map<String, dynamic> data = refrigeratorSnapshot.data() as Map<String, dynamic>;
      
      // 현재 사용자가 소유자인지 확인
      if (data['owner_id'] != currentUserId) {
        return false;
      }

      // 소유자는 제거 불가
      if (userId == data['owner_id']) {
        return false;
      }

      // 멤버 제거
      List<String> memberIds = List<String>.from(data['member_ids'] ?? []);
      memberIds.remove(userId);
      await _refrigeratorsCollection.doc(refrigeratorId).update({
        'member_ids': memberIds,
      });

      return true;
    } catch (e) {
      print('냉장고 멤버 제거 오류: $e');
      return false;
    }
  }

  // 방에 냉장고 생성 (새로운 메소드)
  Future<Refrigerator?> createRefrigeratorForRoom(
    String roomId,
    String name,
    {
      int? templateIndex,
      required List<String> compartmentNames,
      required String layout,
    }
  ) async {
    if (currentUserId == null) {
      return null;
    }

    try {
      // 방 정보 가져오기
      DocumentSnapshot roomDoc = await _firestore.collection('Rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        print('방을 찾을 수 없습니다: $roomId');
        return null;
      }

      Map<String, dynamic> roomData = roomDoc.data() as Map<String, dynamic>;
      List<String> roomMemberIds = List<String>.from(roomData['memberIds'] ?? []);

      // 방의 모든 멤버들을 냉장고 멤버로 추가 (통합 로직 사용)
      List<String> allRoomMembers = await getAllRoomMembers(roomId);
      Set<String> memberIds = {currentUserId!}; // 냉장고 생성자
      memberIds.addAll(allRoomMembers); // 방의 모든 멤버

      // 냉장고 데이터 생성
      // 기본 색상: 칸 이름에 '냉동'이 포함되면 하늘색(blue), 아니면 연두색(green)
      final List<String> defaultColors = compartmentNames
          .map((n) => n.contains('냉동') ? 'blue' : 'green')
          .toList();

      DocumentReference refrigeratorRef = await _refrigeratorsCollection.add({
        'name': name,
        'owner_id': currentUserId,
        'member_ids': memberIds.toList(), // 방의 모든 멤버를 냉장고 멤버로 추가
        'capacity': layout == 'single' ? 10 : 30, // 미니 냉장고는 용량 작게
        'item_count': 0,
        'created_at': Timestamp.now(),
        'type': 'shared',
        'room_id': roomId, // 방 연결 정보
        'compartment_names': compartmentNames,
        'layout': layout,
        'compartment_theme': 'green',
        'compartment_colors': defaultColors,
      });

      print('냉장고 생성 완료: ${memberIds.length}명의 멤버 추가');

      // 생성된 냉장고 정보 조회 및 반환
      DocumentSnapshot refrigeratorSnapshot = await refrigeratorRef.get();
      return Refrigerator.fromFirestore(refrigeratorSnapshot);
    } catch (e) {
      print('방 냉장고 생성 오류: $e');
      return null;
    }
  }

  // 방의 모든 멤버 조회 (통합 함수)
  Future<List<String>> getAllRoomMembers(String roomId) async {
    try {
      // 1. Room의 memberIds 조회
      DocumentSnapshot roomDoc = await _firestore.collection('Rooms').doc(roomId).get();
      if (!roomDoc.exists) {
        print('방을 찾을 수 없습니다: $roomId');
        return [];
      }

      Map<String, dynamic> roomData = roomDoc.data() as Map<String, dynamic>;
      List<String> roomMemberIds = List<String>.from(roomData['memberIds'] ?? []);
      String? roomCreator = roomData['room_creator'];

      // 2. RoomUser 컬렉션에서 활성 멤버 조회
      QuerySnapshot roomUsers = await _firestore
          .collection('RoomUser')
          .where('room_id', isEqualTo: roomId)
          .get();
      List<String> roomUserIds = roomUsers.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['user_id'] as String)
          .toList();

      // 3. 모든 멤버 ID 통합 (중복 제거)
      Set<String> allMemberIds = {};
      allMemberIds.addAll(roomMemberIds);
      allMemberIds.addAll(roomUserIds);
      if (roomCreator != null) {
        allMemberIds.add(roomCreator); // 방 생성자 포함
      }

      print('방 $roomId의 모든 멤버: ${allMemberIds.length}명');
      return allMemberIds.toList();
    } catch (e) {
      print('방 멤버 조회 오류: $e');
      return [];
    }
  }

  // 방 멤버 변경 시 냉장고 멤버 동기화 (강화된 버전)
  Future<bool> syncRoomMembersToRefrigerators(String roomId) async {
    if (currentUserId == null) {
      return false;
    }

    try {
      // 방의 모든 멤버 가져오기 (개선된 로직)
      List<String> allRoomMembers = await getAllRoomMembers(roomId);
      
      if (allRoomMembers.isEmpty) {
        print('방 $roomId에 멤버가 없습니다');
        return false;
      }

      // 해당 방의 모든 냉장고 가져오기
      QuerySnapshot refrigeratorsSnapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .get();

      // 각 냉장고의 멤버 목록 업데이트
      for (DocumentSnapshot refrigeratorDoc in refrigeratorsSnapshot.docs) {
        Map<String, dynamic> refrigeratorData = refrigeratorDoc.data() as Map<String, dynamic>;
        String ownerId = refrigeratorData['owner_id'] ?? '';
        
        // 냉장고 소유자와 방의 모든 멤버들을 포함
        Set<String> memberIds = {ownerId};
        memberIds.addAll(allRoomMembers);

        // 냉장고 멤버 목록 업데이트
        await _refrigeratorsCollection.doc(refrigeratorDoc.id).update({
          'member_ids': memberIds.toList(),
        });

        print('냉장고 ${refrigeratorDoc.id} 멤버 동기화: ${memberIds.length}명');
      }

      print('방 $roomId의 냉장고 멤버 동기화 완료: ${allRoomMembers.length}명');
      return true;
    } catch (e) {
      print('냉장고 멤버 동기화 오류: $e');
      return false;
    }
  }

  // 사용자가 방에 접근할 수 있는 냉장고 목록 가져오기 (수정된 메소드)
  Stream<List<Refrigerator>> getRoomRefrigerators(String roomId) {
    try {
      return _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => Refrigerator.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      print('방 냉장고 목록 조회 오류: $e');
      return Stream.value([]);
    }
  }

  // 사용자가 특정 냉장고에 접근할 수 있는지 확인 (새로운 메소드)
  Future<bool> canUserAccessRefrigerator(String refrigeratorId) async {
    if (currentUserId == null) {
      return false;
    }

    try {
      DocumentSnapshot refrigeratorDoc = await _refrigeratorsCollection.doc(refrigeratorId).get();
      if (!refrigeratorDoc.exists) {
        return false;
      }

      Map<String, dynamic> data = refrigeratorDoc.data() as Map<String, dynamic>;
      List<String> memberIds = List<String>.from(data['member_ids'] ?? []);
      
      // 사용자가 냉장고 멤버에 포함되어 있는지 확인
      return memberIds.contains(currentUserId);
    } catch (e) {
      print('냉장고 접근 권한 확인 오류: $e');
      return false;
    }
  }

  // 냉장고 칸에 재료 추가
  Future<bool> addIngredient(
    String roomId,
    String refrigeratorName,
    int compartmentIndex,
    Map<String, dynamic> ingredientData,
  ) async {
    if (currentUserId == null) {
      print('재료 추가 오류: 사용자가 로그인되지 않음');
      return false;
    }

    try {
      print('재료 추가 시도: roomId=$roomId, refrigeratorName=$refrigeratorName, compartmentIndex=$compartmentIndex');
      
      // 해당 냉장고 찾기
      QuerySnapshot refrigeratorSnapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();
      
      print('냉장고 검색 결과: ${refrigeratorSnapshot.docs.length}개');
      
      if (refrigeratorSnapshot.docs.isEmpty) {
        print('냉장고를 찾을 수 없습니다: roomId=$roomId, name=$refrigeratorName');
        return false;
      }

      // 냉장고 문서 ID
      String refrigeratorId = refrigeratorSnapshot.docs.first.id;
      print('냉장고 ID: $refrigeratorId');
      
      // 재료 ID 생성
      String ingredientId = DateTime.now().millisecondsSinceEpoch.toString();
      ingredientData['id'] = ingredientId;
      
      // 등록자 정보 추가
      if (currentUserId != null) {
        ingredientData['registeredBy'] = currentUserId;
      }
      
      // 잠금 관련 필드 추가
      ingredientData['isLocked'] = false;
      ingredientData['lockedBy'] = null;
      
      print('재료 데이터: $ingredientData');
      
      // 냉장고/칸/재료 경로에 재료 저장
      await _firestore
          .collection('Refrigerators')
          .doc(refrigeratorId)
          .collection('compartments')
          .doc(compartmentIndex.toString())
          .collection('ingredients')
          .doc(ingredientId)
          .set(ingredientData);
      
      print('재료 저장 완료');
      
      // 냉장고 아이템 수 업데이트
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot refrigeratorDoc = await transaction.get(
          _refrigeratorsCollection.doc(refrigeratorId)
        );
        
        if (refrigeratorDoc.exists) {
          int currentCount = (refrigeratorDoc.data() as Map<String, dynamic>)['item_count'] ?? 0;
          transaction.update(
            _refrigeratorsCollection.doc(refrigeratorId),
            {'item_count': currentCount + 1}
          );
          print('아이템 수 업데이트: ${currentCount + 1}');
        }
      });
      
      // 유통기한 알림 스케줄링
      await _scheduleExpirationAlert(
        ingredientId: ingredientId,
        ingredientData: ingredientData,
        refrigeratorName: refrigeratorName,
        compartmentIndex: compartmentIndex,
      );

      // 통계 업데이트 (식품 등록)
      if (currentUserId != null) {
        await _statisticsService.recordFoodRegistration(roomId, currentUserId!);
      }
      
      print('재료 추가 성공');
      return true;
    } catch (e) {
      print('재료 추가 오류: $e');
      return false;
    }
  }
  
  // 냉장고 칸에서 재료 삭제
  Future<bool> deleteIngredient(
    String roomId,
    String refrigeratorName,
    int compartmentIndex,
    String ingredientId,
  ) async {
    if (currentUserId == null) {
      return false;
    }

    try {
      // 해당 냉장고 찾기
      QuerySnapshot refrigeratorSnapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();
      
      if (refrigeratorSnapshot.docs.isEmpty) {
        print('냉장고를 찾을 수 없습니다');
        return false;
      }

      // 냉장고 문서 ID
      String refrigeratorId = refrigeratorSnapshot.docs.first.id;
      
      // 냉장고/칸/재료 경로에서 재료 삭제
      await _firestore
          .collection('Refrigerators')
          .doc(refrigeratorId)
          .collection('compartments')
          .doc(compartmentIndex.toString())
          .collection('ingredients')
          .doc(ingredientId)
          .delete();
      
      // 냉장고 아이템 수 업데이트
      await _firestore.runTransaction((transaction) async {
        DocumentSnapshot refrigeratorDoc = await transaction.get(
          _refrigeratorsCollection.doc(refrigeratorId)
        );
        
        if (refrigeratorDoc.exists) {
          int currentCount = (refrigeratorDoc.data() as Map<String, dynamic>)['item_count'] ?? 0;
          transaction.update(
            _refrigeratorsCollection.doc(refrigeratorId),
            {'item_count': math.max(0, currentCount - 1)}
          );
        }
      });
      
      // 해당 재료의 알림 취소
      await _alertService.cancelAlertsForIngredient(ingredientId);
      
      return true;
    } catch (e) {
      print('재료 삭제 오류: $e');
      return false;
    }
  }
  
  // 냉장고 칸의 재료 목록 실시간 스트림 (신규)
  Stream<List<Map<String, dynamic>>> getIngredientsForCompartmentStream(
    String roomId,
    String refrigeratorName,
    int compartmentIndex,
  ) async* {
    try {
      // 먼저 냉장고 ID 찾기 (한 번만)
      QuerySnapshot refrigeratorSnapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();
      
      if (refrigeratorSnapshot.docs.isEmpty) {
        print('냉장고를 찾을 수 없습니다');
        yield <Map<String, dynamic>>[];
        return;
      }

      String refrigeratorId = refrigeratorSnapshot.docs.first.id;
      print('실시간 스트림 시작: $refrigeratorId / 칸 $compartmentIndex');
      
      // 재료 컬렉션 실시간 스트림
      await for (final snapshot in _refrigeratorsCollection
          .doc(refrigeratorId)
          .collection('compartments')
          .doc(compartmentIndex.toString())
          .collection('ingredients')
          .orderBy('created_at', descending: true)
          .snapshots(includeMetadataChanges: true)) {
        
        final ingredients = snapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        
        print('재료 데이터 업데이트됨: ${ingredients.length}개');
        // 각 재료의 이미지 경로도 로그로 출력
        for (var ingredient in ingredients) {
          if (ingredient['imagePath'] != null) {
            print('     ${ingredient['name']}: ${ingredient['imagePath']}');
          }
        }
        yield ingredients;
      }
    } catch (e) {
      print('재료 스트림 조회 오류: $e');
      yield <Map<String, dynamic>>[];
    }
  }

  // 냉장고 칸의 모든 재료 조회 (기존 메서드 - 하위 호환성 유지)
  Future<List<Map<String, dynamic>>> getIngredientsForCompartment(
    String roomId,
    String refrigeratorName,
    int compartmentIndex,
  ) async {
    try {
      // 해당 냉장고 찾기
      QuerySnapshot refrigeratorSnapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();
      
      if (refrigeratorSnapshot.docs.isEmpty) {
        print('냉장고를 찾을 수 없습니다');
        return [];
      }

      // 냉장고 문서 ID
      String refrigeratorId = refrigeratorSnapshot.docs.first.id;
      
      // 냉장고/칸/재료 경로에서 모든 재료 조회
      QuerySnapshot ingredientsSnapshot = await _firestore
          .collection('Refrigerators')
          .doc(refrigeratorId)
          .collection('compartments')
          .doc(compartmentIndex.toString())
          .collection('ingredients')
          .orderBy('created_at', descending: true)
          .get();
      
      // 재료 목록 변환
      return ingredientsSnapshot.docs
          .map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id; // ID 포함
            return data;
          })
          .toList();
    } catch (e) {
      print('재료 조회 오류: $e');
      return [];
    }
  }

  // 방 ID와 냉장고 이름으로 냉장고 ID 조회
  Future<String?> getRefrigeratorIdByRoomAndName(String roomId, String refrigeratorName) async {
    try {
      QuerySnapshot snapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) {
        return null;
      }
      
      return snapshot.docs.first.id;
    } catch (e) {
      print('냉장고 ID 조회 오류: $e');
      return null;
    }
  }

  // 재료 선호도 업데이트 (좋아요/싫어요)
  Future<bool> updateIngredientPreferences(
    String roomId,
    String refrigeratorName,
    int compartmentIndex,
    String ingredientId,
    Map<String, dynamic> preferences,
  ) async {
    if (currentUserId == null) {
      print('선호도 업데이트 실패: 사용자 인증 없음');
      return false;
    }

    try {
      // 해당 냉장고 찾기
      QuerySnapshot refrigeratorSnapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();
      
      if (refrigeratorSnapshot.docs.isEmpty) {
        print('선호도 업데이트 실패: 냉장고를 찾을 수 없습니다');
        return false;
      }

      // 냉장고 문서 ID
      String refrigeratorId = refrigeratorSnapshot.docs.first.id;
      
      final ingredientRef = _firestore
          .collection('Refrigerators')
          .doc(refrigeratorId)
          .collection('compartments')
          .doc(compartmentIndex.toString())
          .collection('ingredients')
          .doc(ingredientId);
      
      // 재료 문서 존재 확인
      final ingredientDoc = await ingredientRef.get();
      
      if (!ingredientDoc.exists) {
        print('선호도 업데이트 실패: 재료를 찾을 수 없습니다');
        return false;
      }
      
      // 재료의 선호도 정보 업데이트 (set with merge로 필드가 없어도 생성)
      await ingredientRef.set(
        {'preferences': preferences},
        SetOptions(merge: true),
      );
      
      print('✅ 선호도 업데이트 성공: $ingredientId');
      print('   likes: ${preferences['likes']?.length ?? 0}, dislikes: ${preferences['dislikes']?.length ?? 0}');
      
      return true;
    } catch (e) {
      print('❌ 선호도 업데이트 오류: $e');
      return false;
    }
  }

  // 냉장고 칸 이름 업데이트
  Future<bool> updateCompartmentNames(String roomId, String refrigeratorName, List<String> newCompartmentNames) async {
    if (currentUserId == null) {
      return false;
    }

    try {
      // 해당 냉장고 찾기
      QuerySnapshot refrigeratorSnapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();
      
      if (refrigeratorSnapshot.docs.isEmpty) {
        print('냉장고를 찾을 수 없습니다: roomId=$roomId, name=$refrigeratorName');
        return false;
      }

      DocumentSnapshot refrigeratorDoc = refrigeratorSnapshot.docs.first;
      String refrigeratorId = refrigeratorDoc.id;
      
      // 사용자 권한 확인 (냉장고 멤버인지)
      Map<String, dynamic> data = refrigeratorDoc.data() as Map<String, dynamic>;
      List<String> memberIds = List<String>.from(data['member_ids'] ?? []);
      
      if (!memberIds.contains(currentUserId)) {
        print('냉장고 수정 권한이 없습니다');
        return false;
      }

      // 칸 이름 업데이트
      await _refrigeratorsCollection.doc(refrigeratorId).update({
        'compartment_names': newCompartmentNames,
      });

      print('냉장고 칸 이름 업데이트 완료: $newCompartmentNames');
      return true;
    } catch (e) {
      print('냉장고 칸 이름 업데이트 오류: $e');
      return false;
    }
  }

  // 칸 색상 테마 업데이트 ('green' | 'blue')
  Future<bool> updateCompartmentTheme(String roomId, String refrigeratorName, String theme) async {
    if (currentUserId == null) {
      return false;
    }

    try {
      // 해당 냉장고 찾기
      QuerySnapshot refrigeratorSnapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();

      if (refrigeratorSnapshot.docs.isEmpty) {
        print('냉장고를 찾을 수 없습니다: roomId=$roomId, name=$refrigeratorName');
        return false;
      }

      DocumentSnapshot refrigeratorDoc = refrigeratorSnapshot.docs.first;

      // 사용자 권한 확인 (냉장고 멤버인지)
      Map<String, dynamic> data = refrigeratorDoc.data() as Map<String, dynamic>;
      List<String> memberIds = List<String>.from(data['member_ids'] ?? []);
      if (!memberIds.contains(currentUserId)) {
        print('냉장고 수정 권한이 없습니다');
        return false;
      }

      await _refrigeratorsCollection.doc(refrigeratorDoc.id).update({
        'compartment_theme': theme,
      });
      print('칸 색상 테마 업데이트 완료: $theme');
      return true;
    } catch (e) {
      print('칸 색상 테마 업데이트 오류: $e');
      return false;
    }
  }

  // 칸별 색상 배열 업데이트 (각 칸 색상 개별 지정)
  Future<bool> updateCompartmentColors(String roomId, String refrigeratorName, List<String> colors) async {
    if (currentUserId == null) {
      return false;
    }

    try {
      final snapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return false;

      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final memberIds = List<String>.from(data['member_ids'] ?? []);
      if (!memberIds.contains(currentUserId)) return false;

      // 길이 보정: firestore에는 정확히 칸 수만큼 저장
      final newColors = List<String>.from(colors);
      final names = List<String>.from(data['compartment_names'] ?? []);
      final needed = names.length;
      while (newColors.length < needed) {
        final name = names[newColors.length];
        newColors.add(name.contains('냉동') ? 'blue' : 'green');
      }
      if (newColors.length > needed) {
        newColors.removeRange(needed, newColors.length);
      }

      await _refrigeratorsCollection.doc(doc.id).update({
        'compartment_colors': newColors,
      });
      return true;
    } catch (e) {
      print('칸별 색상 업데이트 오류: $e');
      return false;
    }
  }

  // --- ID 기반 업데이트 (실시간 입력 반영용) ---
  Future<bool> updateRefrigeratorNameById(String refrigeratorId, String newName) async {
    try {
      await _refrigeratorsCollection.doc(refrigeratorId).update({'name': newName});
      return true;
    } catch (e) {
      print('ID 기반 냉장고 이름 업데이트 오류: $e');
      return false;
    }
  }

  Future<bool> updateCompartmentNamesById(String refrigeratorId, List<String> newNames) async {
    try {
      await _refrigeratorsCollection.doc(refrigeratorId).update({'compartment_names': newNames});
      return true;
    } catch (e) {
      print('ID 기반 칸 이름 업데이트 오류: $e');
      return false;
    }
  }

  Future<bool> updateCompartmentColorsById(String refrigeratorId, List<String> colors) async {
    try {
      await _refrigeratorsCollection.doc(refrigeratorId).update({'compartment_colors': colors});
      return true;
    } catch (e) {
      print('ID 기반 칸 색상 업데이트 오류: $e');
      return false;
    }
  }

  // 냉장고 정보 조회 (roomId와 냉장고 이름으로)
  Future<Refrigerator?> getRefrigeratorByRoomAndName(String roomId, String refrigeratorName) async {
    try {
      QuerySnapshot refrigeratorSnapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();
      
      if (refrigeratorSnapshot.docs.isEmpty) {
        print('냉장고를 찾을 수 없습니다: roomId=$roomId, name=$refrigeratorName');
        return null;
      }

      return Refrigerator.fromFirestore(refrigeratorSnapshot.docs.first);
    } catch (e) {
      print('냉장고 정보 조회 오류: $e');
      return null;
    }
  }

  // 냉장고 이름 업데이트
  Future<bool> updateRefrigeratorName(String roomId, String oldName, String newName) async {
    if (currentUserId == null) {
      return false;
    }

    try {
      // 해당 냉장고 찾기
      QuerySnapshot refrigeratorSnapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: oldName)
          .limit(1)
          .get();
      
      if (refrigeratorSnapshot.docs.isEmpty) {
        print('냉장고를 찾을 수 없습니다: roomId=$roomId, name=$oldName');
        return false;
      }

      DocumentSnapshot refrigeratorDoc = refrigeratorSnapshot.docs.first;
      String refrigeratorId = refrigeratorDoc.id;
      
      // 사용자 권한 확인 (냉장고 멤버인지)
      Map<String, dynamic> data = refrigeratorDoc.data() as Map<String, dynamic>;
      List<String> memberIds = List<String>.from(data['member_ids'] ?? []);
      
      if (!memberIds.contains(currentUserId)) {
        print('냉장고 수정 권한이 없습니다');
        return false;
      }

      // 냉장고 이름 업데이트
      await _refrigeratorsCollection.doc(refrigeratorId).update({
        'name': newName,
      });

      print('냉장고 이름 업데이트 완료: $oldName -> $newName');
      return true;
    } catch (e) {
      print('냉장고 이름 업데이트 오류: $e');
      return false;
    }
  }

  // 냉장고 칸에서 재료 수정
  Future<bool> updateIngredient(
    String roomId,
    String refrigeratorName,
    int compartmentIndex,
    String ingredientId,
    Map<String, dynamic> ingredientData,
  ) async {
    if (currentUserId == null) {
      print('재료 수정 오류: 사용자가 로그인되지 않음');
      return false;
    }

    try {
      print('재료 수정 시도: roomId=$roomId, refrigeratorName=$refrigeratorName, compartmentIndex=$compartmentIndex, ingredientId=$ingredientId');
      
      // 해당 냉장고 찾기
      QuerySnapshot refrigeratorSnapshot = await _refrigeratorsCollection
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();
      
      print('냉장고 검색 결과: ${refrigeratorSnapshot.docs.length}개');
      
      if (refrigeratorSnapshot.docs.isEmpty) {
        print('냉장고를 찾을 수 없습니다: roomId=$roomId, name=$refrigeratorName');
        return false;
      }

      // 냉장고 문서 ID
      String refrigeratorId = refrigeratorSnapshot.docs.first.id;
      print('냉장고 ID: $refrigeratorId');
      
      // 재료 데이터에 수정 시간 추가
      ingredientData['updated_at'] = Timestamp.now();
      
      print('수정할 재료 데이터: $ingredientData');
      
      // 냉장고/칸/재료 경로에서 재료 수정
      await _firestore
          .collection('Refrigerators')
          .doc(refrigeratorId)
          .collection('compartments')
          .doc(compartmentIndex.toString())
          .collection('ingredients')
          .doc(ingredientId)
          .update(ingredientData);
      
      print('재료 수정 완료');
      // 유통기한 변경 시 알림 재스케줄링
      await _scheduleExpirationAlert(
        ingredientId: ingredientId,
        ingredientData: ingredientData,
        refrigeratorName: refrigeratorName,
        compartmentIndex: compartmentIndex,
      );
      return true;
    } catch (e) {
      print('재료 수정 오류: $e');
      return false;
    }
  }

  // 유통기한 알림 스케줄링 헬퍼 메서드
  Future<void> _scheduleExpirationAlert({
    required String ingredientId,
    required Map<String, dynamic> ingredientData,
    required String refrigeratorName,
    required int compartmentIndex,
  }) async {
    try {
      final dynamic expiryField = ingredientData['expiryDate'];

      DateTime? expiryDate;
      if (expiryField is Timestamp) {
        expiryDate = expiryField.toDate();
      } else if (expiryField is DateTime) {
        expiryDate = expiryField;
      } else if (expiryField is String) {
        expiryDate = DateTime.tryParse(expiryField);
      }

      // 유통기한이 유효하지 않은 경우, 기존 알림만 정리하고 종료
      if (expiryDate == null) {
        print('⚠️ 유통기한이 없어 알림을 스케줄링하지 않습니다. 기존 알림을 취소합니다. ingredientId=$ingredientId');
        await _alertService.cancelAlertsForIngredient(ingredientId);
        return;
      }

      final ingredientName = ingredientData['name'] ?? '';
      final compartmentName = 'compartment_$compartmentIndex'; // TODO: 실제 칸 이름 가져오기
      
      print('🚀 refrigerator_service에서 알림 스케줄링 시작: $ingredientName');
      print('   유통기한: $expiryDate');
      
      await _alertService.scheduleExpirationAlerts(
        ingredientId: ingredientId,
        ingredientName: ingredientName,
        expiryDate: expiryDate,
        refrigeratorName: refrigeratorName,
        compartmentName: compartmentName,
        // 사용자 설정(시간/ON-OFF)을 사용해 스케줄링
        alertSettings: await _alertService.loadUserAlertSettings(),
      );
      
      print('refrigerator_service 알림 스케줄링 완료: $ingredientName (만료일: $expiryDate)');
    } catch (e) {
      print('알림 스케줄링 오류: $e');
    }
  }

  /// 식품 잠금 (등록자만 가능)
  Future<bool> lockIngredient({
    required String roomId,
    required String refrigeratorName,
    required int compartmentIndex,
    required String ingredientId,
  }) async {
    try {
      if (currentUserId == null) {
        print('❌ 사용자 ID가 없습니다');
        return false;
      }

      // 냉장고 찾기
      QuerySnapshot refrigeratorSnapshot = await _firestore
          .collection('Refrigerators')
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();

      if (refrigeratorSnapshot.docs.isEmpty) {
        print('❌ 냉장고를 찾을 수 없습니다');
        return false;
      }

      String refrigeratorId = refrigeratorSnapshot.docs.first.id;

      // 식품 문서 참조
      DocumentReference ingredientRef = _firestore
          .collection('Refrigerators')
          .doc(refrigeratorId)
          .collection('compartments')
          .doc(compartmentIndex.toString())
          .collection('ingredients')
          .doc(ingredientId);

      // 식품 정보 확인
      DocumentSnapshot ingredientDoc = await ingredientRef.get();
      if (!ingredientDoc.exists) {
        print('❌ 식품을 찾을 수 없습니다');
        return false;
      }

      Map<String, dynamic> ingredientData = ingredientDoc.data() as Map<String, dynamic>;
      String? registeredBy = ingredientData['registeredBy'];

      // 등록자만 잠금 가능
      if (registeredBy != currentUserId) {
        print('❌ 등록자만 잠금할 수 있습니다');
        return false;
      }

      // 잠금 설정
      await ingredientRef.update({
        'isLocked': true,
        'lockedBy': currentUserId,
        'lockedAt': Timestamp.now(),
      });

      print('식품 잠금 완료: ${ingredientData['name']}');
      return true;
    } catch (e) {
      print('❌ 식품 잠금 오류: $e');
      return false;
    }
  }

  /// 식품 잠금 해제 (등록자만 가능)
  Future<bool> unlockIngredient({
    required String roomId,
    required String refrigeratorName,
    required int compartmentIndex,
    required String ingredientId,
  }) async {
    try {
      if (currentUserId == null) {
        print('❌ 사용자 ID가 없습니다');
        return false;
      }

      // 냉장고 찾기
      QuerySnapshot refrigeratorSnapshot = await _firestore
          .collection('Refrigerators')
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();

      if (refrigeratorSnapshot.docs.isEmpty) {
        print('❌ 냉장고를 찾을 수 없습니다');
        return false;
      }

      String refrigeratorId = refrigeratorSnapshot.docs.first.id;

      // 식품 문서 참조
      DocumentReference ingredientRef = _firestore
          .collection('Refrigerators')
          .doc(refrigeratorId)
          .collection('compartments')
          .doc(compartmentIndex.toString())
          .collection('ingredients')
          .doc(ingredientId);

      // 식품 정보 확인
      DocumentSnapshot ingredientDoc = await ingredientRef.get();
      if (!ingredientDoc.exists) {
        print('❌ 식품을 찾을 수 없습니다');
        return false;
      }

      Map<String, dynamic> ingredientData = ingredientDoc.data() as Map<String, dynamic>;
      String? lockedBy = ingredientData['lockedBy'];

      // 잠금한 사용자만 해제 가능
      if (lockedBy != currentUserId) {
        print('❌ 잠금한 사용자만 해제할 수 있습니다');
        return false;
      }

      // 잠금 해제
      await ingredientRef.update({
        'isLocked': false,
        'lockedBy': null,
        'unlockedAt': Timestamp.now(),
      });

      print('식품 잠금 해제 완료: ${ingredientData['name']}');
      return true;
    } catch (e) {
      print('❌ 식품 잠금 해제 오류: $e');
      return false;
    }
  }

  /// 사용자가 특정 식품에 대한 권한이 있는지 확인
  bool canUserManageIngredient(Map<String, dynamic> ingredientData) {
    if (currentUserId == null) return false;
    
    bool isLocked = ingredientData['isLocked'] ?? false;
    String? registeredBy = ingredientData['registeredBy'];
    
    // 잠금되지 않은 경우 모든 사용자가 관리 가능
    if (!isLocked) return true;
    
    // 잠금된 경우 등록자만 관리 가능
    return registeredBy == currentUserId;
  }

  /// 사용자가 특정 식품을 잠금할 수 있는지 확인 (등록자만 가능)
  bool canUserLockIngredient(Map<String, dynamic> ingredientData) {
    if (currentUserId == null) return false;
    
    String? registeredBy = ingredientData['registeredBy'];
    bool isLocked = ingredientData['isLocked'] ?? false;
    
    // 이미 잠금된 경우 잠금 불가
    if (isLocked) return false;
    
    // 등록자만 잠금 가능
    return registeredBy == currentUserId;
  }

  /// 사용자가 특정 식품을 잠금 해제할 수 있는지 확인 (잠금한 사용자만 가능)
  bool canUserUnlockIngredient(Map<String, dynamic> ingredientData) {
    if (currentUserId == null) return false;
    
    bool isLocked = ingredientData['isLocked'] ?? false;
    String? lockedBy = ingredientData['lockedBy'];
    
    // 잠금되지 않은 경우 해제 불가
    if (!isLocked) return false;
    
    // 잠금한 사용자만 해제 가능
    return lockedBy == currentUserId;
  }
} 