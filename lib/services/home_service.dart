import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'statistics_service.dart';

class ExpiringItem {
  final String id;
  final String name;
  final String? imagePath;
  final DateTime expiryDate;
  final String refrigeratorName;
  final String refrigeratorId;
  final String compartmentName;
  final int compartmentIndex;
  final String roomId;
  final int daysLeft;
  final String? quantity;
  final String? coupangPurchaseStatus; // 'purchased' | 'notPurchased' | null

  ExpiringItem({
    required this.id,
    required this.name,
    this.imagePath,
    required this.expiryDate,
    required this.refrigeratorName,
    required this.refrigeratorId,
    required this.compartmentName,
    required this.compartmentIndex,
    required this.roomId,
    required this.daysLeft,
    this.quantity,
    this.coupangPurchaseStatus,
  });

  String get urgencyLevel {
    if (daysLeft < 0) return 'expired';
    if (daysLeft == 0) return 'today';
    if (daysLeft <= 3) return 'urgent';
    if (daysLeft <= 7) return 'warning';
    return 'normal';
  }
}

class RecentRefrigerator {
  final String id;
  final String name;
  final String roomId;
  final String roomName; // 그룹(방) 이름
  final int itemCount;
  final DateTime lastVisitedAt;

  RecentRefrigerator({
    required this.id,
    required this.name,
    required this.roomId,
    required this.roomName,
    required this.itemCount,
    required this.lastVisitedAt,
  });
}

class WeeklyStats {
  final int itemsAdded;
  final int itemsConsumed;
  final int expiringCount;

  WeeklyStats({
    required this.itemsAdded,
    required this.itemsConsumed,
    required this.expiringCount,
  });
}

class HomeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StatisticsService statisticsService = StatisticsService();

  /// 유통기한 임박 식품 가져오기 (최적화)
  Future<List<ExpiringItem>> getExpiringItems({int maxDays = 7, int? limit}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final now = DateTime.now();

      // 사용자가 접근 가능한 모든 냉장고 조회
      final refrigeratorsSnapshot = await _firestore
          .collection('Refrigerators')
          .where('member_ids', arrayContains: user.uid)
          .get();

      // 병렬 처리를 위한 Future 리스트 (각 Future가 List<ExpiringItem>을 반환)
      final futures = <Future<List<ExpiringItem>>>[];

      for (final refrigeratorDoc in refrigeratorsSnapshot.docs) {
        final refrigeratorData = refrigeratorDoc.data();
        final refrigeratorName = refrigeratorData['name'] ?? '';
        final roomId = refrigeratorData['room_id'] ?? '';
        
        // 방이 삭제되었는지 확인
        if (roomId.isNotEmpty) {
          try {
            final roomDoc = await _firestore.collection('Rooms').doc(roomId).get();
            if (!roomDoc.exists) {
              print('⚠️ 방이 삭제됨 - 냉장고 스킵: $refrigeratorName (roomId: $roomId)');
              continue; // 방이 삭제된 경우 해당 냉장고 스킵
            }
          } catch (e) {
            print('⚠️ 방 확인 실패 - 냉장고 스킵: $refrigeratorName (error: $e)');
            continue;
          }
        }
        
        // 냉장고의 칸 이름들 가져오기
        final compartmentNames = List<String>.from(
          refrigeratorData['compartment_names'] ?? []
        );

        // 각 칸의 재료를 병렬로 가져오기
        for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
          final compartmentName = compartmentNames[compartmentIndex];
          
          futures.add(
            refrigeratorDoc.reference
                .collection('compartments')
                .doc(compartmentIndex.toString())
                .collection('ingredients')
                .get()
                .then((ingredientsSnapshot) {
              final compartmentItems = <ExpiringItem>[];
              
              for (final ingredientDoc in ingredientsSnapshot.docs) {
                final ingredientData = ingredientDoc.data();
                final dynamic expiryField = ingredientData['expiryDate'];
                
                DateTime? expiryDate;
                if (expiryField is Timestamp) {
                  expiryDate = expiryField.toDate();
                } else if (expiryField is String) {
                  expiryDate = DateTime.tryParse(expiryField);
                }

                if (expiryDate == null) continue;

                final daysLeft = DateTime(expiryDate.year, expiryDate.month, expiryDate.day)
                    .difference(DateTime(now.year, now.month, now.day))
                    .inDays;

                // 임박 식품 + 만료된 식품 모두 포함 (daysLeft <= maxDays)
                if (daysLeft <= maxDays) {
                  compartmentItems.add(ExpiringItem(
                    id: ingredientDoc.id,
                    name: ingredientData['name'] ?? '알 수 없음',
                    imagePath: ingredientData['imagePath'],
                    expiryDate: expiryDate,
                    refrigeratorName: refrigeratorName,
                    refrigeratorId: refrigeratorDoc.id,
                    compartmentName: compartmentName,
                    compartmentIndex: compartmentIndex,
                    roomId: roomId,
                    daysLeft: daysLeft,
                    quantity: ingredientData['quantity']?.toString(),
                    coupangPurchaseStatus: ingredientData['coupangPurchaseStatus'] as String?,
                  ));
                }
              }
              
              return compartmentItems;
            })
          );
        }
      }

      // 모든 비동기 작업 완료 대기 및 결과 합치기
      final results = await Future.wait(futures);
      final items = <ExpiringItem>[];
      for (final result in results) {
        items.addAll(result);
      }

      // 유통기한이 가까운 순으로 정렬 (만료된 것이 먼저)
      items.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
      
      // 만료/임박 식품 개수 분류
      final expiredCount = items.where((item) => item.daysLeft < 0).length;
      final expiringCount = items.where((item) => item.daysLeft >= 0).length;
      
      print('📦 총 ${items.length}개 식품 로드됨 (만료: $expiredCount개, 임박: $expiringCount개)');
      print('📋 식품 목록:');
      for (var item in items.take(5)) {
        final status = item.daysLeft < 0 ? 'D+${item.daysLeft.abs()}' : 'D-${item.daysLeft}';
        print('  - ${item.name} ($status) [${item.refrigeratorName}/${item.compartmentName}] 이미지: ${item.imagePath ?? "없음"}');
      }
      if (items.length > 5) {
        print('  ... 외 ${items.length - 5}개');
      }

      // limit이 지정된 경우 해당 개수만 반환
      if (limit != null && items.length > limit) {
        print('⚠️ limit($limit) 적용 - ${items.length}개 중 $limit개만 반환');
        return items.take(limit).toList();
      }

      return items;
    } catch (e) {
      print('유통기한 임박 식품 조회 오류: $e');
      return [];
    }
  }

  /// 최근 본 냉장고 가져오기 (SharedPreferences 사용 + 최적화)
  Future<List<RecentRefrigerator>> getRecentRefrigerators({int limit = 4}) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final prefs = await SharedPreferences.getInstance();
      final recentIdsJson = prefs.getString('recent_refrigerators_${user.uid}');
      
      print('🔍 최근 냉장고 조회: $recentIdsJson');
      
      if (recentIdsJson == null || recentIdsJson.isEmpty) {
        print('📝 기록 없음, 기본 냉장고 반환');
        return await _getDefaultRecentRefrigerators(limit);
      }

      final List<dynamic> recentIds = json.decode(recentIdsJson);
      print('📋 저장된 냉장고 ID: $recentIds');
      
      final recentRefs = <RecentRefrigerator>[];
      
      // 병렬로 냉장고 정보 가져오기
      final futures = recentIds.take(limit).map((id) async {
        try {
          final doc = await _firestore.collection('Refrigerators').doc(id).get();
          if (doc.exists) {
            final data = doc.data()!;
            final memberIds = List<String>.from(data['member_ids'] ?? []);
            if (memberIds.contains(user.uid)) {
              // 방 이름 가져오기
              final roomId = data['room_id'] ?? '';
              String roomName = '그룹';
              
              if (roomId.isNotEmpty) {
                try {
                  // Rooms 컬렉션에서 방 정보 확인
                  final roomDoc = await _firestore.collection('Rooms').doc(roomId).get();
                  if (!roomDoc.exists) {
                    print('⚠️ 방이 삭제됨 - 냉장고 제외: ${data['name']} (roomId: $roomId)');
                    return null; // 방이 삭제된 경우 null 반환
                  }
                  roomName = roomDoc.data()?['room_name'] ?? '그룹';
                } catch (e) {
                  print('⚠️ 방 이름 조회 오류: $e');
                  return null; // 오류 발생 시 null 반환
                }
              }
              
              return RecentRefrigerator(
                id: doc.id,
                name: data['name'] ?? '냉장고',
                roomId: roomId,
                roomName: roomName,
                itemCount: data['item_count'] ?? 0,
                lastVisitedAt: DateTime.now(),
              );
            }
          }
        } catch (e) {
          print('❌ 냉장고 조회 오류 ($id): $e');
        }
        return null;
      }).toList();

      final results = await Future.wait(futures);
      recentRefs.addAll(results.whereType<RecentRefrigerator>());

      print('📦 총 ${recentRefs.length}개 냉장고 로드됨');

      // 충분한 냉장고가 없으면 기본 냉장고로 채우기
      if (recentRefs.length < limit) {
        final defaultRefs = await _getDefaultRecentRefrigerators(limit - recentRefs.length);
        for (final ref in defaultRefs) {
          if (!recentRefs.any((r) => r.id == ref.id)) {
            recentRefs.add(ref);
          }
        }
      }

      return recentRefs;
    } catch (e) {
      print('❌ 최근 냉장고 조회 오류: $e');
      return await _getDefaultRecentRefrigerators(limit);
    }
  }

  /// 기본 냉장고 목록 (최근 생성순 + 그룹명 포함)
  Future<List<RecentRefrigerator>> _getDefaultRecentRefrigerators(int limit) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final refrigeratorsSnapshot = await _firestore
          .collection('Refrigerators')
          .where('member_ids', arrayContains: user.uid)
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      final recentRefs = <RecentRefrigerator>[];
      
      // 병렬로 방 이름 가져오기
      final futures = refrigeratorsSnapshot.docs.map((doc) async {
        final data = doc.data();
        final roomId = data['room_id'] ?? '';
        String roomName = '그룹';
        
        if (roomId.isNotEmpty) {
          try {
            final roomDoc = await _firestore.collection('Users')
                .doc(user.uid)
                .collection('rooms')
                .doc(roomId)
                .get();
            if (roomDoc.exists) {
              roomName = roomDoc.data()?['name'] ?? '그룹';
            }
          } catch (e) {
            print('⚠️ 방 이름 조회 오류: $e');
          }
        }
        
        return RecentRefrigerator(
          id: doc.id,
          name: data['name'] ?? '냉장고',
          roomId: roomId,
          roomName: roomName,
          itemCount: data['item_count'] ?? 0,
          lastVisitedAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      recentRefs.addAll(await Future.wait(futures));

      return recentRefs;
    } catch (e) {
      print('기본 냉장고 조회 오류: $e');
      return [];
    }
  }

  /// 냉장고 방문 기록 저장
  Future<void> recordRefrigeratorVisit(String refrigeratorId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      print('💾 냉장고 방문 기록 저장: $refrigeratorId');
      
      final prefs = await SharedPreferences.getInstance();
      final key = 'recent_refrigerators_${user.uid}';
      final recentIdsJson = prefs.getString(key);
      
      List<String> recentIds = [];
      if (recentIdsJson != null && recentIdsJson.isNotEmpty) {
        recentIds = List<String>.from(json.decode(recentIdsJson));
        print('📋 기존 기록: $recentIds');
      }

      // 기존 기록에서 제거 (중복 방지)
      recentIds.remove(refrigeratorId);
      
      // 맨 앞에 추가
      recentIds.insert(0, refrigeratorId);
      
      // 최대 10개까지만 저장
      if (recentIds.length > 10) {
        recentIds = recentIds.take(10).toList();
      }

      // 저장
      await prefs.setString(key, json.encode(recentIds));
      print('✅ 방문 기록 저장 완료: $recentIds');
    } catch (e) {
      print('❌ 냉장고 방문 기록 저장 오류: $e');
    }
  }

  /// 이번 주 통계 가져오기 (최적화 + 중복 쿼리 제거)
  Future<WeeklyStats> getWeeklyStats() async {
    final user = _auth.currentUser;
    if (user == null) {
      return WeeklyStats(itemsAdded: 0, itemsConsumed: 0, expiringCount: 0);
    }

    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(Duration(days: 7));

      int itemsAdded = 0;
      int itemsConsumed = 0;

      // 사용자가 접근 가능한 모든 냉장고 조회
      final refrigeratorsSnapshot = await _firestore
          .collection('Refrigerators')
          .where('member_ids', arrayContains: user.uid)
          .get();

      // 병렬로 각 냉장고의 데이터 조회
      final futures = <Future<void>>[];

      for (final refrigeratorDoc in refrigeratorsSnapshot.docs) {
        final refrigeratorData = refrigeratorDoc.data();
        final compartmentNames = List<String>.from(
          refrigeratorData['compartment_names'] ?? []
        );

        // 각 칸의 최근 등록 재료를 병렬로 조회
        for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
          futures.add(
            refrigeratorDoc.reference
                .collection('compartments')
                .doc(compartmentIndex.toString())
                .collection('ingredients')
                .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
                .get()
                .then((ingredientsSnapshot) {
              itemsAdded += ingredientsSnapshot.docs.length;
            })
          );
        }

        // 소비 기록 조회
        futures.add(
          refrigeratorDoc.reference
              .collection('consumed_items')
              .where('consumed_at', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
              .get()
              .then((consumedSnapshot) {
            itemsConsumed += consumedSnapshot.docs.length;
          })
              .catchError((e) {
            // consumed_items 컬렉션이 없을 수 있음
          })
        );
      }

      await Future.wait(futures);

      // 유통기한 임박 개수 (이미 최적화된 함수 사용)
      final expiringItems = await getExpiringItems(maxDays: 3);

      return WeeklyStats(
        itemsAdded: itemsAdded,
        itemsConsumed: itemsConsumed,
        expiringCount: expiringItems.length,
      );
    } catch (e) {
      print('주간 통계 조회 오류: $e');
      return WeeklyStats(itemsAdded: 0, itemsConsumed: 0, expiringCount: 0);
    }
  }

  /// 쿠팡 검색 URL 생성
  String getCoupangSearchUrl(String productName) {
    final query = Uri.encodeComponent(productName);
    // 쿠팡 파트너스 링크를 사용하려면 파트너스 ID가 필요합니다
    // 여기서는 기본 검색 URL을 제공합니다
    return 'https://www.coupang.com/np/search?q=$query';
  }
}

