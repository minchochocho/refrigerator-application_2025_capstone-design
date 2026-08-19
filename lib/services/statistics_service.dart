import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import '../models/statistics.dart';

class StatisticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 현재 사용자 ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// 방의 통계 데이터 가져오기 (현재 월)
  Future<RoomStatistics?> getRoomStatistics(String roomId) async {
    print('getRoomStatistics 시작: roomId = $roomId');
    
    try {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      final docId = '${roomId}_${currentMonth.year}_${currentMonth.month}';
      print('통계 문서 ID: $docId');
      
      DocumentSnapshot doc = await _firestore
          .collection('RoomStatistics')
          .doc(docId)
          .get();

      if (doc.exists) {
        print(' 통계 문서 존재함');
        final stats = RoomStatistics.fromFirestore(doc);
        print(' 통계 데이터: 등록=${stats.totalRegisteredItems}, 소비=${stats.totalConsumed}, 폐기=${stats.totalDiscarded}');
        return stats;
      } else {
        print(' 통계 문서가 존재하지 않음 - 빈 통계 생성');
        // 통계가 없으면 빈 통계 생성
        return RoomStatistics(
          roomId: roomId,
          currentMonth: currentMonth,
        );
      }
    } catch (e) {
      print('❌ 통계 데이터 가져오기 오류: $e');
      return null;
    }
  }

  /// 특정 월의 통계 데이터 가져오기
  Future<RoomStatistics?> getRoomStatisticsByMonth(String roomId, DateTime month) async {
    print(' getRoomStatisticsByMonth 시작: roomId = $roomId, month = ${month.year}-${month.month}');
    
    try {
      final docId = '${roomId}_${month.year}_${month.month}';
      print('통계 문서 ID: $docId');
      
      DocumentSnapshot doc = await _firestore
          .collection('RoomStatistics')
          .doc(docId)
          .get();

      if (doc.exists) {
        print(' 통계 문서 존재함');
        final stats = RoomStatistics.fromFirestore(doc);
        print(' 통계 데이터: 등록=${stats.totalRegisteredItems}, 소비=${stats.totalConsumed}, 폐기=${stats.totalDiscarded}');
        return stats;
      } else {
        print(' 통계 문서가 존재하지 않음 - 빈 통계 생성');
        return RoomStatistics(
          roomId: roomId,
          currentMonth: month,
        );
      }
    } catch (e) {
      print('❌ 통계 데이터 가져오기 오류: $e');
      return null;
    }
  }

  /// 누적 통계 데이터 가져오기 (모든 월 합산)
  Future<RoomStatistics?> getCumulativeRoomStatistics(String roomId) async {
    print(' getCumulativeRoomStatistics 시작: roomId = $roomId');
    
    try {
      // 해당 방의 모든 월별 통계 문서 가져오기
      QuerySnapshot querySnapshot = await _firestore
          .collection('RoomStatistics')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${roomId}_')
          .where(FieldPath.documentId, isLessThan: '${roomId}_Z')
          .get();

      if (querySnapshot.docs.isEmpty) {
        print(' 누적 통계 문서가 존재하지 않음 - 빈 통계 생성');
        return RoomStatistics(
          roomId: roomId,
          currentMonth: DateTime.now(),
        );
      }

      // 모든 월별 통계를 합산
      int totalRegisteredItems = 0;
      int totalExpiredItems = 0;
      int totalConsumedBeforeExpiry = 0;
      int totalConsumedAfterExpiry = 0;
      int totalDiscardedBeforeExpiry = 0;
      int totalDiscardedAfterExpiry = 0;
      Map<String, int> combinedUserRegistrationCount = {};
      DateTime latestUpdate = DateTime(2000); // 가장 오래된 날짜로 초기화

      for (DocumentSnapshot doc in querySnapshot.docs) {
        final stats = RoomStatistics.fromFirestore(doc);
        
        totalRegisteredItems += stats.totalRegisteredItems;
        totalExpiredItems += stats.expiredItems;
        totalConsumedBeforeExpiry += stats.consumedBeforeExpiry;
        totalConsumedAfterExpiry += stats.consumedAfterExpiry;
        totalDiscardedBeforeExpiry += stats.discardedBeforeExpiry;
        totalDiscardedAfterExpiry += stats.discardedAfterExpiry;

        // 사용자별 등록 수 합산
        stats.userRegistrationCount.forEach((userId, count) {
          combinedUserRegistrationCount[userId] = 
              (combinedUserRegistrationCount[userId] ?? 0) + count;
        });

        // 가장 최근 업데이트 시간 찾기
        if (stats.lastUpdated.isAfter(latestUpdate)) {
          latestUpdate = stats.lastUpdated;
        }
      }

      final cumulativeStats = RoomStatistics(
        roomId: roomId,
        totalRegisteredItems: totalRegisteredItems,
        expiredItems: totalExpiredItems,
        consumedBeforeExpiry: totalConsumedBeforeExpiry,
        consumedAfterExpiry: totalConsumedAfterExpiry,
        discardedBeforeExpiry: totalDiscardedBeforeExpiry,
        discardedAfterExpiry: totalDiscardedAfterExpiry,
        userRegistrationCount: combinedUserRegistrationCount,
        lastUpdated: latestUpdate,
        currentMonth: DateTime.now(), // 현재 시간으로 설정
      );

      print(' 누적 통계 데이터: 등록=${cumulativeStats.totalRegisteredItems}, 소비=${cumulativeStats.totalConsumed}, 폐기=${cumulativeStats.totalDiscarded}');
      return cumulativeStats;
    } catch (e) {
      print('❌ 누적 통계 데이터 가져오기 오류: $e');
      return null;
    }
  }

  /// 특정 방의 통계가 있는 월 목록 가져오기
  Future<List<DateTime>> getAvailableStatisticsMonths(String roomId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('RoomStatistics')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: '${roomId}_')
          .where(FieldPath.documentId, isLessThan: '${roomId}_Z')
          .get();

      List<DateTime> months = [];
      
      for (DocumentSnapshot doc in querySnapshot.docs) {
        final stats = RoomStatistics.fromFirestore(doc);
        months.add(stats.currentMonth);
      }

      // 최신 월부터 정렬
      months.sort((a, b) => b.compareTo(a));
      
      return months;
    } catch (e) {
      print('❌ 통계 월 목록 가져오기 오류: $e');
      return [];
    }
  }

  /// 이전 달 통계 데이터 가져오기 (비교용)
  Future<RoomStatistics?> getPreviousMonthStatistics(String roomId) async {
    try {
      final now = DateTime.now();
      final previousMonth = DateTime(now.year, now.month - 1);
      
      DocumentSnapshot doc = await _firestore
          .collection('RoomStatistics')
          .doc('${roomId}_${previousMonth.year}_${previousMonth.month}')
          .get();

      if (doc.exists) {
        return RoomStatistics.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('이전 달 통계 데이터 가져오기 오류: $e');
      return null;
    }
  }

  /// 식품 등록 시 통계 업데이트
  Future<void> recordFoodRegistration(String roomId, String userId) async {
    try {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      final docId = '${roomId}_${currentMonth.year}_${currentMonth.month}';

      await _firestore.runTransaction((transaction) async {
        DocumentReference docRef = _firestore
            .collection('RoomStatistics')
            .doc(docId);

        DocumentSnapshot snapshot = await transaction.get(docRef);
        
        RoomStatistics stats;
        if (snapshot.exists) {
          stats = RoomStatistics.fromFirestore(snapshot);
        } else {
          stats = RoomStatistics(
            roomId: roomId,
            currentMonth: currentMonth,
          );
        }

        // 전체 등록 수 증가
        final updatedStats = stats.copyWith(
          totalRegisteredItems: stats.totalRegisteredItems + 1,
          lastUpdated: now,
        );

        // 사용자별 등록 수 증가
        Map<String, int> userCount = Map.from(updatedStats.userRegistrationCount);
        userCount[userId] = (userCount[userId] ?? 0) + 1;

        final finalStats = updatedStats.copyWith(
          userRegistrationCount: userCount,
        );

        transaction.set(docRef, finalStats.toFirestore());
      });
    } catch (e) {
      print('식품 등록 통계 업데이트 오류: $e');
    }
  }

  /// 식품 소비/폐기 기록 및 통계 업데이트
  Future<void> recordFoodAction({
    required String roomId,
    required String refrigeratorName,
    required String ingredientName,
    required String ingredientId,
    required DateTime expiryDate,
    required FoodActionType actionType,
  }) async {
    if (currentUserId == null) {
      print('❌ recordFoodAction: currentUserId가 null입니다');
      return;
    }

    print(' recordFoodAction 시작:');
    print('   roomId: $roomId');
    print('   refrigeratorName: $refrigeratorName');
    print('   ingredientName: $ingredientName');
    print('   actionType: $actionType');
    print('   currentUserId: $currentUserId');

    try {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      
      // 날짜만으로 만료 여부 판정 (시간 무시)
      final expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
      final nowDateOnly = DateTime(now.year, now.month, now.day);
      final wasExpired = expiryDateOnly.isBefore(nowDateOnly);

      // 1. 액션 기록 저장
      await _firestore.collection('FoodActionRecords').add(
        FoodActionRecord(
          id: '', // Firestore가 자동 생성
          roomId: roomId,
          refrigeratorName: refrigeratorName,
          ingredientName: ingredientName,
          userId: currentUserId!,
          actionType: actionType,
          actionDate: now,
          expiryDate: expiryDate,
          wasExpired: wasExpired,
        ).toFirestore(),
      );

      // 2. 통계 업데이트
      final docId = '${roomId}_${currentMonth.year}_${currentMonth.month}';
      print(' 통계 문서 ID: $docId');
      
      await _firestore.runTransaction((transaction) async {
        DocumentReference docRef = _firestore
            .collection('RoomStatistics')
            .doc(docId);

        DocumentSnapshot snapshot = await transaction.get(docRef);
        
        RoomStatistics stats;
        if (snapshot.exists) {
          stats = RoomStatistics.fromFirestore(snapshot);
        } else {
          stats = RoomStatistics(
            roomId: roomId,
            currentMonth: currentMonth,
          );
        }

        RoomStatistics updatedStats;

        if (actionType == FoodActionType.consumed) {
          // 소비 기록
          if (wasExpired) {
            updatedStats = stats.copyWith(
              consumedAfterExpiry: stats.consumedAfterExpiry + 1,
              lastUpdated: now,
            );
          } else {
            updatedStats = stats.copyWith(
              consumedBeforeExpiry: stats.consumedBeforeExpiry + 1,
              lastUpdated: now,
            );
          }
        } else {
          // 폐기 기록
          if (wasExpired) {
            updatedStats = stats.copyWith(
              discardedAfterExpiry: stats.discardedAfterExpiry + 1,
              lastUpdated: now,
            );
          } else {
            updatedStats = stats.copyWith(
              discardedBeforeExpiry: stats.discardedBeforeExpiry + 1,
              lastUpdated: now,
            );
          }
        }

        transaction.set(docRef, updatedStats.toFirestore());
        print(' 통계 업데이트 완료');
      });
      
      print(' recordFoodAction 완료');
    } catch (e) {
      print('❌ 식품 액션 기록 오류: $e');
      rethrow;
    }
  }

  /// 만료된 식품을 자동으로 추적하여 통계에 반영
  Future<void> trackExpiredItems(String roomId) async {
    try {
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      print(' 만료 식품 추적 시작: ${now.toString()}');
      
      // 기존 만료 기록 조회 (디버깅용)
      await _debugExpiredRecords(roomId, currentMonth);
      
      // 방의 모든 냉장고에서 식품 가져오기
      final refrigeratorsSnapshot = await _firestore
          .collection('Refrigerators')
          .where('room_id', isEqualTo: roomId)
          .get();

      if (refrigeratorsSnapshot.docs.isEmpty) {
        print('❌ 방에 냉장고가 없습니다: $roomId');
        return;
      }

      Set<String> processedIngredients = {}; // 중복 처리 방지
      int newlyExpiredCount = 0;

      for (final refrigeratorDoc in refrigeratorsSnapshot.docs) {
        final refrigeratorData = refrigeratorDoc.data();
        final refrigeratorName = refrigeratorData['name'] as String;
        final compartmentNames = List<String>.from(
          refrigeratorData['compartment_names'] ?? []
        );

        // 각 칸에서 재료 가져오기
        for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
          final ingredientsSnapshot = await refrigeratorDoc.reference
              .collection('compartments')
              .doc(compartmentIndex.toString())
              .collection('ingredients')
              .get();

          for (final ingredientDoc in ingredientsSnapshot.docs) {
            final ingredientData = ingredientDoc.data();
            final ingredientId = ingredientDoc.id;
            final ingredientName = ingredientData['name'] ?? '알 수 없는 식품';
            
            // 중복 처리 방지
            final uniqueKey = '${refrigeratorName}_${compartmentIndex}_${ingredientId}';
            if (processedIngredients.contains(uniqueKey)) {
              continue;
            }
            processedIngredients.add(uniqueKey);

            DateTime? expiryDate;
            final dynamic expiryField = ingredientData['expiryDate'];
            
            if (expiryField is Timestamp) {
              final utcDate = expiryField.toDate();
              final kstOffset = Duration(hours: 9);
              expiryDate = utcDate.add(kstOffset);
            } else if (expiryField is String) {
              expiryDate = DateTime.tryParse(expiryField);
            }

            if (expiryDate == null) continue;

            // 날짜만으로 만료 여부 판정
            final expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
            final nowDateOnly = DateTime(now.year, now.month, now.day);
            final isExpired = expiryDateOnly.isBefore(nowDateOnly);
            
            if (isExpired) {
              // 이미 만료 처리된 식품인지 확인
              final existingRecord = await _firestore
                  .collection('ExpiredItemRecords')
                  .where('roomId', isEqualTo: roomId)
                  .where('ingredientId', isEqualTo: ingredientId)
                  .where('refrigeratorName', isEqualTo: refrigeratorName)
                  .where('compartmentIndex', isEqualTo: compartmentIndex)
                  .limit(1)
                  .get();
              
              if (existingRecord.docs.isEmpty) {
                // 새로 만료된 식품 - 기록 추가
                await _firestore.collection('ExpiredItemRecords').add({
                  'roomId': roomId,
                  'ingredientId': ingredientId,
                  'ingredientName': ingredientName,
                  'refrigeratorName': refrigeratorName,
                  'compartmentIndex': compartmentIndex,
                  'expiryDate': Timestamp.fromDate(expiryDate),
                  'expiredDate': Timestamp.fromDate(now),
                  'month': currentMonth,
                });
                
                newlyExpiredCount++;
                print('📅 새로 만료된 식품: $ingredientName (${expiryDateOnly.toString().split(' ')[0]})');
              }
            }
          }
        }
      }

      // 통계 업데이트 (새로 만료된 식품이 있는 경우)
      if (newlyExpiredCount > 0) {
        final docId = '${roomId}_${currentMonth.year}_${currentMonth.month}';
        
        await _firestore.runTransaction((transaction) async {
          DocumentReference docRef = _firestore
              .collection('RoomStatistics')
              .doc(docId);

          DocumentSnapshot snapshot = await transaction.get(docRef);
          
          RoomStatistics stats;
          if (snapshot.exists) {
            stats = RoomStatistics.fromFirestore(snapshot);
          } else {
            stats = RoomStatistics(
              roomId: roomId,
              currentMonth: currentMonth,
            );
          }

          final updatedStats = stats.copyWith(
            expiredItems: stats.expiredItems + newlyExpiredCount,
            lastUpdated: now,
          );

          transaction.set(docRef, updatedStats.toFirestore());
        });
        
        print(' 만료 식품 통계 업데이트: +$newlyExpiredCount개');
      } else {
        print(' 새로 만료된 식품 없음');
      }
      
    } catch (e) {
      print('❌ 만료 식품 추적 오류: $e');
    }
  }

  /// 만료 기록 디버깅 (어떤 식품이 누적되었는지 확인)
  Future<void> _debugExpiredRecords(String roomId, DateTime currentMonth) async {
    try {
      print(' === 만료 기록 디버깅 시작 ===');
      
      // 현재 달의 만료 기록 조회
      final expiredRecords = await _firestore
          .collection('ExpiredItemRecords')
          .where('roomId', isEqualTo: roomId)
          .where('month', isEqualTo: Timestamp.fromDate(currentMonth))
          .get();
      
      print(' 이번 달 만료 기록 총 ${expiredRecords.docs.length}개');
      
      if (expiredRecords.docs.isNotEmpty) {
        for (int i = 0; i < expiredRecords.docs.length; i++) {
          final record = expiredRecords.docs[i].data();
          final ingredientName = record['ingredientName'];
          final expiryDate = (record['expiryDate'] as Timestamp).toDate();
          final expiredDate = (record['expiredDate'] as Timestamp).toDate();
          final refrigeratorName = record['refrigeratorName'];
          
          print('${i + 1}. 🍎 $ingredientName');
          print('   📅 유통기한: ${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}');
          print('   ⏰ 만료 처리일: ${expiredDate.year}-${expiredDate.month.toString().padLeft(2, '0')}-${expiredDate.day.toString().padLeft(2, '0')}');
          print('   🏠 냉장고: $refrigeratorName');
          print('');
        }
      } else {
        print(' 이번 달 만료 기록이 없습니다.');
      }
      
      // 현재 통계 확인 및 동기화
      final docId = '${roomId}_${currentMonth.year}_${currentMonth.month}';
      final statsDoc = await _firestore.collection('RoomStatistics').doc(docId).get();
      
      if (statsDoc.exists) {
        final stats = RoomStatistics.fromFirestore(statsDoc);
        print(' 현재 통계의 만료된 식품 수: ${stats.expiredItems}개');
        
        // ExpiredItemRecords와 통계가 불일치하는 경우 수정
        final actualExpiredCount = expiredRecords.docs.length;
        if (stats.expiredItems != actualExpiredCount) {
          print(' 통계 불일치 감지: 통계=${stats.expiredItems}, 실제기록=${actualExpiredCount}');
          print(' 통계를 실제 기록에 맞춰 수정합니다...');
          
          final updatedStats = stats.copyWith(
            expiredItems: actualExpiredCount,
            lastUpdated: DateTime.now(),
          );
          
          await _firestore.collection('RoomStatistics').doc(docId).set(updatedStats.toFirestore());
          print(' 통계 동기화 완료: ${actualExpiredCount}개');
        }
      } else {
        print(' 현재 달 통계 문서가 없습니다.');
      }
      
      print(' === 만료 기록 디버깅 완료 ===\n');
    } catch (e) {
      print('❌ 만료 기록 디버깅 오류: $e');
    }
  }

  /// 만료 기록 초기화 (디버깅용 - 필요시 사용)
  Future<void> resetExpiredRecords(String roomId) async {
    try {
      print(' 만료 기록 초기화 시작...');
      
      // ExpiredItemRecords에서 해당 방의 기록 모두 삭제
      final expiredRecords = await _firestore
          .collection('ExpiredItemRecords')
          .where('roomId', isEqualTo: roomId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in expiredRecords.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      // 현재 달 통계의 expiredItems도 0으로 초기화
      final now = DateTime.now();
      final currentMonth = DateTime(now.year, now.month);
      final docId = '${roomId}_${currentMonth.year}_${currentMonth.month}';
      
      await _firestore.runTransaction((transaction) async {
        DocumentReference docRef = _firestore
            .collection('RoomStatistics')
            .doc(docId);

        DocumentSnapshot snapshot = await transaction.get(docRef);
        
        if (snapshot.exists) {
          RoomStatistics stats = RoomStatistics.fromFirestore(snapshot);
          final updatedStats = stats.copyWith(
            expiredItems: 0,
            lastUpdated: now,
          );
          transaction.set(docRef, updatedStats.toFirestore());
        }
      });
      
      print(' 만료 기록 초기화 완료');
      print('삭제된 기록: ${expiredRecords.docs.length}개');
    } catch (e) {
      print('❌ 만료 기록 초기화 오류: $e');
    }
  }

  /// 방의 모든 냉장고에서 현재 만료된 식품 수 계산
  Future<int> getCurrentExpiredItemsCount(String roomId) async {
    try {
      final now = DateTime.now();
      print(' 현재 시간: ${now.toString()}');
      print(' 기기 날짜: ${now.year}년 ${now.month}월 ${now.day}일');
      print('⏰ 기기 타입: ${Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : '에뮬레이터'}');
      int expiredCount = 0;

      // 방의 모든 냉장고 조회
      QuerySnapshot refrigeratorsSnapshot = await _firestore
          .collection('Refrigerators')
          .where('room_id', isEqualTo: roomId)
          .get();

      for (DocumentSnapshot refrigeratorDoc in refrigeratorsSnapshot.docs) {
        Map<String, dynamic> refrigeratorData = refrigeratorDoc.data() as Map<String, dynamic>;
        List<String> compartmentNames = List<String>.from(
          refrigeratorData['compartment_names'] ?? []
        );

        // 각 칸에서 만료된 식품 확인
        for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
          QuerySnapshot ingredientsSnapshot = await refrigeratorDoc.reference
              .collection('compartments')
              .doc(compartmentIndex.toString())
              .collection('ingredients')
              .get();

          for (DocumentSnapshot ingredientDoc in ingredientsSnapshot.docs) {
            Map<String, dynamic> ingredientData = ingredientDoc.data() as Map<String, dynamic>;
            final String ingredientName = ingredientData['name'] ?? '알 수 없는 식품';
            
            DateTime? expiryDate;
            final dynamic expiryField = ingredientData['expiryDate'];
            
            print(' 식품 검사: $ingredientName');
            print('   원본 유통기한 데이터: $expiryField (타입: ${expiryField.runtimeType})');
            
            if (expiryField is Timestamp) {
              final utcDate = expiryField.toDate();
              
              // UTC 자정에서 로컬 날짜로 변환
              expiryDate = DateTime(utcDate.year, utcDate.month, utcDate.day);
              
              print('   Timestamp 변환 결과: ${expiryDate.toString()}');
              print('   📅 저장된 날짜 (UTC): ${utcDate.year}-${utcDate.month.toString().padLeft(2, '0')}-${utcDate.day.toString().padLeft(2, '0')} ${utcDate.hour}:${utcDate.minute}');
              print('   📅 로컬 날짜: ${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}');
            } else if (expiryField is String) {
              expiryDate = DateTime.tryParse(expiryField);
              print('   String 파싱 결과: ${expiryDate?.toString() ?? 'null'}');
            } else {
              print('    알 수 없는 유통기한 형식');
            }

            if (expiryDate != null) {
              // 날짜만 비교 (시간과 타임존 무시)
              final expiryDateOnly = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
              final nowDateOnly = DateTime(now.year, now.month, now.day);
              
              print('    비교용 유통기한: ${expiryDateOnly.toString().split(' ')[0]}');
              print('    비교용 현재날짜: ${nowDateOnly.toString().split(' ')[0]}');
              
              // 유통기한 기준 선택
              // 옵션 1 (일반적): 당일까지 OK, 다음날부터 만료
              final isExpired = expiryDateOnly.isBefore(nowDateOnly);
              
              // 옵션 2 (관대): 유통기한 +1일까지 OK, 2일 후부터 만료  
              // final isExpired = nowDateOnly.difference(expiryDateOnly).inDays > 1;
              final daysDifference = nowDateOnly.difference(expiryDateOnly).inDays;
              
              print('   유통기한 (날짜만): ${expiryDateOnly.toString().split(' ')[0]}');
              print('   현재 날짜: ${nowDateOnly.toString().split(' ')[0]}');
              print('   만료 여부: $isExpired (당일까지 OK, 다음날부터 만료)');
              print('   차이: ${daysDifference}일 ${daysDifference > 0 ? '지남' : daysDifference == 0 ? '당일' : '남음'}');
              
              if (isExpired) {
                expiredCount++;
                print('   ❌ 만료된 식품으로 카운트');
              } else {
                print('    신선한 식품');
              }
            } else {
              print('    유통기한 파싱 실패 - 카운트하지 않음');
            }
            print('');
          }
        }
      }

      print('🏁 총 만료된 식품 수: $expiredCount개');
      return expiredCount;
    } catch (e) {
      print('❌ 만료된 식품 수 계산 오류: $e');
      return 0;
    }
  }

  /// 사용자별 식품 등록 순위 가져오기 (현재 월 기준)
  Future<List<Map<String, dynamic>>> getUserRegistrationRanking(String roomId) async {
    try {
      final stats = await getRoomStatistics(roomId);
      if (stats == null) return [];

      List<Map<String, dynamic>> ranking = [];
      
      for (String userId in stats.userRegistrationCount.keys) {
        int count = stats.userRegistrationCount[userId] ?? 0;
        if (count > 0) {
          // 사용자 정보 가져오기
          DocumentSnapshot userDoc = await _firestore
              .collection('Users')
              .doc(userId)
              .get();
          
          String nickname = '알 수 없음';
          if (userDoc.exists) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            nickname = userData['nickname'] ?? '사용자';
          }

          ranking.add({
            'userId': userId,
            'nickname': nickname,
            'count': count,
          });
        }
      }

      // 등록 수 기준으로 내림차순 정렬
      ranking.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      return ranking;
    } catch (e) {
      print('사용자 등록 순위 가져오기 오류: $e');
      return [];
    }
  }

  /// 사용자별 식품 등록 순위 가져오기 (특정 월 기준)
  Future<List<Map<String, dynamic>>> getUserRegistrationRankingForMonth(String roomId, DateTime month) async {
    try {
      final stats = await getRoomStatisticsByMonth(roomId, month);
      if (stats == null) return [];

      List<Map<String, dynamic>> ranking = [];
      
      for (String userId in stats.userRegistrationCount.keys) {
        int count = stats.userRegistrationCount[userId] ?? 0;
        if (count > 0) {
          // 사용자 정보 가져오기
          DocumentSnapshot userDoc = await _firestore
              .collection('Users')
              .doc(userId)
              .get();
          
          String nickname = '알 수 없음';
          if (userDoc.exists) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            nickname = userData['nickname'] ?? '사용자';
          }

          ranking.add({
            'userId': userId,
            'nickname': nickname,
            'count': count,
          });
        }
      }

      // 등록 수 기준으로 내림차순 정렬
      ranking.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      return ranking;
    } catch (e) {
      print('특정 월 사용자 등록 순위 가져오기 오류: $e');
      return [];
    }
  }

  /// 사용자별 식품 등록 순위 가져오기 (누적 기준)
  Future<List<Map<String, dynamic>>> getCumulativeUserRegistrationRanking(String roomId) async {
    try {
      final stats = await getCumulativeRoomStatistics(roomId);
      if (stats == null) return [];

      List<Map<String, dynamic>> ranking = [];
      
      for (String userId in stats.userRegistrationCount.keys) {
        int count = stats.userRegistrationCount[userId] ?? 0;
        if (count > 0) {
          // 사용자 정보 가져오기
          DocumentSnapshot userDoc = await _firestore
              .collection('Users')
              .doc(userId)
              .get();
          
          String nickname = '알 수 없음';
          if (userDoc.exists) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            nickname = userData['nickname'] ?? '사용자';
          }

          ranking.add({
            'userId': userId,
            'nickname': nickname,
            'count': count,
          });
        }
      }

      // 등록 수 기준으로 내림차순 정렬
      ranking.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      return ranking;
    } catch (e) {
      print('누적 사용자 등록 순위 가져오기 오류: $e');
      return [];
    }
  }

  /// 통계 비교 데이터 가져오기 (전월 대비)
  Future<Map<String, dynamic>> getStatisticsComparison(String roomId) async {
    try {
      final currentStats = await getRoomStatistics(roomId);
      final previousStats = await getPreviousMonthStatistics(roomId);

      if (currentStats == null) {
        return {};
      }

      Map<String, dynamic> comparison = {
        'current': {
          'totalRegistered': currentStats.totalRegisteredItems,
          'totalConsumed': currentStats.totalConsumed,
          'totalDiscarded': currentStats.totalDiscarded,
          'expiredItems': currentStats.expiredItems,
          'consumedBeforeExpiry': currentStats.consumedBeforeExpiry,
          'consumedAfterExpiry': currentStats.consumedAfterExpiry,
          'discardedBeforeExpiry': currentStats.discardedBeforeExpiry,
          'discardedAfterExpiry': currentStats.discardedAfterExpiry,
        },
        'changes': {},
      };

      if (previousStats != null) {
        comparison['previous'] = {
          'totalRegistered': previousStats.totalRegisteredItems,
          'totalConsumed': previousStats.totalConsumed,
          'totalDiscarded': previousStats.totalDiscarded,
          'expiredItems': previousStats.expiredItems,
          'consumedBeforeExpiry': previousStats.consumedBeforeExpiry,
          'consumedAfterExpiry': previousStats.consumedAfterExpiry,
          'discardedBeforeExpiry': previousStats.discardedBeforeExpiry,
          'discardedAfterExpiry': previousStats.discardedAfterExpiry,
        };

        comparison['changes'] = {
          'totalRegistered': currentStats.totalRegisteredItems - previousStats.totalRegisteredItems,
          'totalConsumed': currentStats.totalConsumed - previousStats.totalConsumed,
          'totalDiscarded': currentStats.totalDiscarded - previousStats.totalDiscarded,
          'expiredItems': currentStats.expiredItems - previousStats.expiredItems,
          'consumedBeforeExpiry': currentStats.consumedBeforeExpiry - previousStats.consumedBeforeExpiry,
          'consumedAfterExpiry': currentStats.consumedAfterExpiry - previousStats.consumedAfterExpiry,
          'discardedBeforeExpiry': currentStats.discardedBeforeExpiry - previousStats.discardedBeforeExpiry,
          'discardedAfterExpiry': currentStats.discardedAfterExpiry - previousStats.discardedAfterExpiry,
        };
      }

      return comparison;
    } catch (e) {
      print('통계 비교 데이터 가져오기 오류: $e');
      return {};
    }
  }

  /// 특정 월의 통계 비교 데이터 가져오기 (해당 월 vs 전월)
  Future<Map<String, dynamic>> getStatisticsComparisonForMonth(String roomId, DateTime selectedMonth) async {
    try {
      print(' getStatisticsComparisonForMonth: ${selectedMonth.year}-${selectedMonth.month}');
      
      final currentStats = await getRoomStatisticsByMonth(roomId, selectedMonth);
      
      // 전월 계산 (타임존 안전하게 처리)
      DateTime previousMonth;
      if (selectedMonth.month == 1) {
        // 1월인 경우 전년 12월
        previousMonth = DateTime(selectedMonth.year - 1, 12);
      } else {
        // 일반적인 경우
        previousMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
      }
      
      print(' 전월 계산: ${selectedMonth.year}-${selectedMonth.month} → ${previousMonth.year}-${previousMonth.month}');
      
      final previousStats = await getRoomStatisticsByMonth(roomId, previousMonth);

      if (currentStats == null) {
        print('❌ 현재 월 통계가 없음');
        return {};
      }
      
      print(' 현재 월 데이터: 등록=${currentStats.totalRegisteredItems}, 소비=${currentStats.totalConsumed}');

      Map<String, dynamic> comparison = {
        'current': {
          'totalRegistered': currentStats.totalRegisteredItems,
          'totalConsumed': currentStats.totalConsumed,
          'totalDiscarded': currentStats.totalDiscarded,
          'expiredItems': currentStats.expiredItems,
          'consumedBeforeExpiry': currentStats.consumedBeforeExpiry,
          'consumedAfterExpiry': currentStats.consumedAfterExpiry,
          'discardedBeforeExpiry': currentStats.discardedBeforeExpiry,
          'discardedAfterExpiry': currentStats.discardedAfterExpiry,
        },
        'changes': {},
      };

      // 전월 데이터가 존재하는지 확인 (문서가 실제로 존재하는지)
      bool hasValidPreviousData = false;
      
      if (previousStats != null) {
        // 문서가 존재하고, Firestore에서 실제로 가져온 데이터인지 확인
        // (빈 통계가 아닌 실제 저장된 데이터인지 확인)
        try {
          final previousDocId = '${roomId}_${previousMonth.year}_${previousMonth.month}';
          DocumentSnapshot previousDoc = await _firestore
              .collection('RoomStatistics')
              .doc(previousDocId)
              .get();
          
          hasValidPreviousData = previousDoc.exists;
          print(' 전월 문서 존재 여부: ${previousDoc.exists} (${previousMonth.year}-${previousMonth.month})');
        } catch (e) {
          print('❌ 전월 문서 확인 오류: $e');
          hasValidPreviousData = false;
        }
      }

      if (hasValidPreviousData) {
        print(' 유효한 전월 데이터 있음: ${previousMonth.year}-${previousMonth.month} (등록=${previousStats!.totalRegisteredItems})');
        comparison['previous'] = {
          'totalRegistered': previousStats!.totalRegisteredItems,
          'totalConsumed': previousStats.totalConsumed,
          'totalDiscarded': previousStats.totalDiscarded,
          'expiredItems': previousStats.expiredItems,
          'consumedBeforeExpiry': previousStats.consumedBeforeExpiry,
          'consumedAfterExpiry': previousStats.consumedAfterExpiry,
          'discardedBeforeExpiry': previousStats.discardedBeforeExpiry,
          'discardedAfterExpiry': previousStats.discardedAfterExpiry,
        };

        comparison['changes'] = {
          'totalRegistered': currentStats.totalRegisteredItems - previousStats.totalRegisteredItems,
          'totalConsumed': currentStats.totalConsumed - previousStats.totalConsumed,
          'totalDiscarded': currentStats.totalDiscarded - previousStats.totalDiscarded,
          'expiredItems': currentStats.expiredItems - previousStats.expiredItems,
          'consumedBeforeExpiry': currentStats.consumedBeforeExpiry - previousStats.consumedBeforeExpiry,
          'consumedAfterExpiry': currentStats.consumedAfterExpiry - previousStats.consumedAfterExpiry,
          'discardedBeforeExpiry': currentStats.discardedBeforeExpiry - previousStats.discardedBeforeExpiry,
          'discardedAfterExpiry': currentStats.discardedAfterExpiry - previousStats.discardedAfterExpiry,
        };
        
        print(' 비교 데이터 생성 완료');
      } else {
        print(' 전월 문서가 존재하지 않음: ${previousMonth.year}-${previousMonth.month}');
      }

      return comparison;
    } catch (e) {
      print('❌ 특정 월 통계 비교 데이터 가져오기 오류: $e');
      return {};
    }
  }


  /// 특정 월 데이터를 DB에서 삭제 (디버그용)
  Future<void> deleteMonthData(String roomId, DateTime month) async {
    try {
      final docId = '${roomId}_${month.year}_${month.month}';
      await _firestore
          .collection('RoomStatistics')
          .doc(docId)
          .delete();
      
      print(' ${month.year}년 ${month.month}월 데이터 삭제 완료');
    } catch (e) {
      print('❌ 월 데이터 삭제 오류: $e');
      rethrow;
    }
  }


}
