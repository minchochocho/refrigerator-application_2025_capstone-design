import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../services/refrigerator_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/image_upload_service.dart';
import '../../../services/statistics_service.dart';
import '../../../models/statistics.dart';

/// 날짜를 UTC 자정으로 변환 (타임존 문제 해결)
/// 예: 2025-11-24 10:00 KST -> 2025-11-23 15:00 UTC (자정 기준)
DateTime _toUtcMidnight(DateTime localDate) {
  // 로컬 날짜의 년/월/일만 추출
  final dateOnly = DateTime(localDate.year, localDate.month, localDate.day);
  // UTC 자정으로 변환 (KST는 UTC+9이므로 9시간을 빼줌)
  return DateTime.utc(dateOnly.year, dateOnly.month, dateOnly.day);
}

/// UTC 자정 날짜를 로컬 날짜로 변환
/// 예: 2025-11-23 15:00 UTC -> 2025-11-24 00:00 KST
DateTime _fromUtcMidnight(DateTime utcDate) {
  // UTC 날짜를 로컬로 변환
  return DateTime(utcDate.year, utcDate.month, utcDate.day);
}

/// 재료 관리 관련 로직을 담당하는 클래스
class IngredientManagementLogic {
  final RefrigeratorService refrigeratorService;
  final AuthService authService;
  final ImageUploadService imageUploadService;
  final StatisticsService statisticsService;
  
  IngredientManagementLogic({
    required this.refrigeratorService,
    required this.authService,
    required this.imageUploadService,
    required this.statisticsService,
  });
  
  /// 재료 추가
  Future<bool> addIngredient({
    required String roomId,
    required String refrigeratorName,
    required int compartmentIndex,
    required String name,
    required int quantity,
    DateTime? expiryDate,
    DateTime? manufactureDate,
    DateTime? registrationDate,
    String? memo,
    String? imagePath,
  }) async {
    try {
      // 재료 데이터를 Map으로 구성
      Map<String, dynamic> ingredientData = {
        'name': name,
        'quantity': quantity,
        'created_at': registrationDate != null ? Timestamp.fromDate(registrationDate) : Timestamp.now(),
        'preferences': {
          'likes': [],
          'dislikes': [],
        },
      };
      
      // 유통기한이 있는 경우 추가 (UTC 자정으로 변환)
      if (expiryDate != null) {
        ingredientData['expiryDate'] = Timestamp.fromDate(_toUtcMidnight(expiryDate));
      }
      
      // 제조일이 있는 경우 추가 (UTC 자정으로 변환)
      if (manufactureDate != null) {
        ingredientData['manufactureDate'] = Timestamp.fromDate(_toUtcMidnight(manufactureDate));
      }
      
      // 등록일이 있는 경우 추가 (UTC 자정으로 변환)
      if (registrationDate != null) {
        ingredientData['registrationDate'] = Timestamp.fromDate(_toUtcMidnight(registrationDate));
      }
      
      // 메모가 있는 경우 작성자 정보와 함께 추가
      if (memo != null && memo.isNotEmpty) {
        final userNickname = await authService.getUserNickname();
        ingredientData['memo'] = memo;
        ingredientData['memoAuthor'] = userNickname ?? '알 수 없는 사용자';
        ingredientData['memoCreatedAt'] = Timestamp.now();
      }
      
      // 이미지 업로드 처리
      if (imagePath != null && imagePath.isNotEmpty) {
        if (imagePath.startsWith('http')) {
          // 외부 URL (바코드 이미지 등)은 그대로 저장
          ingredientData['imagePath'] = imagePath;
        } else if (imagePath.startsWith('asset://')) {
          // Asset 경로도 그대로 저장
          ingredientData['imagePath'] = imagePath;
        } else {
          // 로컬 파일 경로인 경우 Firebase Storage에 업로드
          final imageFile = File(imagePath);
          if (imageUploadService.validateImageFile(imageFile)) {
            final uploadedImageUrl = await imageUploadService.uploadIngredientImage(
              imageFile,
              roomId,
              refrigeratorName,
              compartmentIndex,
            );
            
            if (uploadedImageUrl != null) {
              ingredientData['imagePath'] = uploadedImageUrl;
            } else {
              // 업로드 실패 시 로컬 경로 저장 (기존 방식)
              ingredientData['imagePath'] = imagePath;
            }
          } else {
            throw Exception('이미지 파일이 유효하지 않습니다');
          }
        }
      }
      
      bool success = await refrigeratorService.addIngredient(
        roomId,
        refrigeratorName,
        compartmentIndex,
        ingredientData,
      );
      
      return success;
    } catch (e) {
      print('재료 추가 오류: $e');
      rethrow;
    }
  }
  
  /// 재료 수정
  Future<bool> updateIngredient({
    required String roomId,
    required String refrigeratorName,
    required int compartmentIndex,
    required String ingredientId,
    required Map<String, dynamic> originalIngredient,
    required String name,
    required int quantity,
    DateTime? expiryDate,
    DateTime? manufactureDate,
    DateTime? registrationDate,
    String? memo,
    String? imagePath,
  }) async {
    try {
      Map<String, dynamic> updatedData = {
        'name': name,
        'quantity': quantity,
      };
      
      // 메모가 변경된 경우 작성자 정보와 함께 업데이트
      final newMemo = memo?.trim() ?? '';
      final originalMemo = originalIngredient['memo'] ?? '';
      
      if (newMemo.isNotEmpty) {
        updatedData['memo'] = newMemo;
        
        // 메모가 변경된 경우에만 작성자 정보 업데이트
        if (newMemo != originalMemo) {
          final userNickname = await authService.getUserNickname();
          updatedData['memoAuthor'] = userNickname ?? '알 수 없는 사용자';
          updatedData['memoUpdatedAt'] = Timestamp.now();
        }
      } else {
        // 메모가 비워진 경우 관련 필드들도 삭제
        updatedData['memo'] = '';
        updatedData['memoAuthor'] = null;
        updatedData['memoCreatedAt'] = null;
        updatedData['memoUpdatedAt'] = null;
      }
      
      // 날짜 데이터 추가 (UTC 자정으로 변환)
      if (registrationDate != null) {
        updatedData['registrationDate'] = Timestamp.fromDate(_toUtcMidnight(registrationDate));
      }
      if (manufactureDate != null) {
        updatedData['manufactureDate'] = Timestamp.fromDate(_toUtcMidnight(manufactureDate));
      }
      if (expiryDate != null) {
        updatedData['expiryDate'] = Timestamp.fromDate(_toUtcMidnight(expiryDate));
      }
      
      // 이미지 업로드 처리
      if (imagePath != null && imagePath.isNotEmpty) {
        // 기존 이미지와 다른 경우에만 업로드
        if (imagePath != originalIngredient['imagePath']) {
          print('   📝 이미지가 변경됨, 업로드 시작');
          if (imagePath.startsWith('http')) {
            // 외부 URL은 그대로 저장
            if (originalIngredient['imagePath'] != null && 
                originalIngredient['imagePath'].toString().startsWith('http')) {
              await imageUploadService.deleteImageFromUrl(originalIngredient['imagePath']);
            }
            updatedData['imagePath'] = imagePath;
          } else if (imagePath.startsWith('asset://')) {
            // Asset 경로도 그대로 저장
            if (originalIngredient['imagePath'] != null && 
                originalIngredient['imagePath'].toString().startsWith('http')) {
              await imageUploadService.deleteImageFromUrl(originalIngredient['imagePath']);
            }
            updatedData['imagePath'] = imagePath;
          } else {
            // 로컬 파일 - Firebase Storage 업로드
            print('   📁 로컬 파일 임시 저장: $imagePath');
            final imageFile = File(imagePath);
            
            if (imageUploadService.validateImageFile(imageFile)) {
              print('   ✅ 파일 검증 통과, 업로드 시도');
              
              try {
                print('   🔥 Firebase Storage 업로드 시도...');
                final uploadedImageUrl = await imageUploadService.uploadIngredientImage(
                  imageFile,
                  roomId,
                  refrigeratorName,
                  compartmentIndex,
                );
                
                if (uploadedImageUrl != null) {
                  print('   🚀 Firebase Storage 업로드 성공: $uploadedImageUrl');
                  // 기존 이미지 삭제
                  if (originalIngredient['imagePath'] != null && 
                      originalIngredient['imagePath'].toString().startsWith('http')) {
                    print('   🗑️ 기존 이미지 삭제: ${originalIngredient['imagePath']}');
                    await imageUploadService.deleteImageFromUrl(originalIngredient['imagePath']);
                  }
                  updatedData['imagePath'] = uploadedImageUrl;
                } else {
                  // Firebase Storage 업로드 실패 시 로컬 경로로 임시 저장
                  print('   ⚠️ Firebase Storage 업로드 실패, 로컬 경로로 저장: $imagePath');
                  updatedData['imagePath'] = imagePath;
                }
              } catch (e) {
                print('   ❌ Firebase Storage 업로드 중 오류: $e');
                // 오류 발생 시에도 로컬 경로로 저장
                updatedData['imagePath'] = imagePath;
              }
            } else {
              throw Exception('이미지 파일이 유효하지 않습니다');
            }
          }
        }
      } else {
        // 이미지 제거 시 Storage에서도 삭제
        print('   🗑️ 이미지 제거 요청');
        if (originalIngredient['imagePath'] != null && 
            originalIngredient['imagePath'].toString().startsWith('http')) {
          print('   🗑️ Storage에서 기존 이미지 삭제: ${originalIngredient['imagePath']}');
          await imageUploadService.deleteImageFromUrl(originalIngredient['imagePath']);
        }
        updatedData['imagePath'] = null;
      }
      
      print('🔧 최종 업데이트 데이터 imagePath: ${updatedData['imagePath']}');
      
      // 재료 수정
      bool success = await refrigeratorService.updateIngredient(
        roomId,
        refrigeratorName,
        compartmentIndex,
        ingredientId,
        updatedData,
      );
      
      return success;
    } catch (e) {
      print('재료 수정 오류: $e');
      rethrow;
    }
  }
  
  /// 재료 삭제
  Future<bool> deleteIngredient({
    required String roomId,
    required String refrigeratorName,
    required int compartmentIndex,
    required String ingredientId,
  }) async {
    try {
      return await refrigeratorService.deleteIngredient(
        roomId,
        refrigeratorName,
        compartmentIndex,
        ingredientId,
      );
    } catch (e) {
      print('재료 삭제 오류: $e');
      rethrow;
    }
  }
  
  /// 식품 소비 처리
  Future<bool> consumeIngredient({
    required String roomId,
    required String refrigeratorName,
    required int compartmentIndex,
    required Map<String, dynamic> ingredient,
  }) async {
    try {
      // 유통기한 파싱 (UTC 자정에서 로컬 날짜로 변환)
      DateTime? expiryDate;
      final dynamic expiryField = ingredient['expiryDate'];
      
      if (expiryField is Timestamp) {
        final utcDate = expiryField.toDate();
        expiryDate = _fromUtcMidnight(utcDate);
      } else if (expiryField is String) {
        expiryDate = DateTime.tryParse(expiryField);
      }
      
      if (expiryDate == null) {
        expiryDate = DateTime.now().add(Duration(days: 7)); // 기본값
      }

      // 통계 기록
      await statisticsService.recordFoodAction(
        roomId: roomId,
        refrigeratorName: refrigeratorName,
        ingredientName: ingredient['name'] ?? '알 수 없는 식품',
        ingredientId: ingredient['id'],
        expiryDate: expiryDate,
        actionType: FoodActionType.consumed,
      );

      // 식품 삭제
      return await refrigeratorService.deleteIngredient(
        roomId,
        refrigeratorName,
        compartmentIndex,
        ingredient['id'],
      );
    } catch (e) {
      print('식품 소비 처리 오류: $e');
      rethrow;
    }
  }
  
  /// 식품 폐기 처리
  Future<bool> discardIngredient({
    required String roomId,
    required String refrigeratorName,
    required int compartmentIndex,
    required Map<String, dynamic> ingredient,
  }) async {
    try {
      // 유통기한 파싱 (UTC 자정에서 로컬 날짜로 변환)
      DateTime? expiryDate;
      final dynamic expiryField = ingredient['expiryDate'];
      
      if (expiryField is Timestamp) {
        final utcDate = expiryField.toDate();
        expiryDate = _fromUtcMidnight(utcDate);
      } else if (expiryField is String) {
        expiryDate = DateTime.tryParse(expiryField);
      }
      
      if (expiryDate == null) {
        expiryDate = DateTime.now().add(Duration(days: 7)); // 기본값
      }

      // 통계 기록
      await statisticsService.recordFoodAction(
        roomId: roomId,
        refrigeratorName: refrigeratorName,
        ingredientName: ingredient['name'] ?? '알 수 없는 식품',
        ingredientId: ingredient['id'],
        expiryDate: expiryDate,
        actionType: FoodActionType.discarded,
      );

      // 식품 삭제
      return await refrigeratorService.deleteIngredient(
        roomId,
        refrigeratorName,
        compartmentIndex,
        ingredient['id'],
      );
    } catch (e) {
      print('식품 폐기 처리 오류: $e');
      rethrow;
    }
  }
  
  /// 선호도 토글
  Future<bool> togglePreference({
    required String roomId,
    required String refrigeratorName,
    required int compartmentIndex,
    required Map<String, dynamic> ingredient,
    required String type, // 'like' or 'dislike'
  }) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        throw Exception('로그인이 필요합니다');
      }
      
      final Map<String, dynamic> preferences = ingredient['preferences'] ?? {};
      final List<String> likes = List<String>.from(preferences['likes'] ?? []);
      final List<String> dislikes = List<String>.from(preferences['dislikes'] ?? []);
      
      if (type == 'like') {
        if (likes.contains(currentUserId)) {
          likes.remove(currentUserId);
        } else {
          likes.add(currentUserId);
          dislikes.remove(currentUserId); // 싫어요에서 제거
        }
      } else {
        if (dislikes.contains(currentUserId)) {
          dislikes.remove(currentUserId);
        } else {
          dislikes.add(currentUserId);
          likes.remove(currentUserId); // 좋아요에서 제거
        }
      }
      
      // Firestore 업데이트
      final updatedPreferences = {
        'likes': likes,
        'dislikes': dislikes,
      };
      
      return await refrigeratorService.updateIngredientPreferences(
        roomId,
        refrigeratorName,
        compartmentIndex,
        ingredient['id'],
        updatedPreferences,
      );
    } catch (e) {
      print('선호도 토글 오류: $e');
      rethrow;
    }
  }
  
  /// 식품 잠금
  Future<bool> lockIngredient({
    required String roomId,
    required String refrigeratorName,
    required int compartmentIndex,
    required String ingredientId,
  }) async {
    try {
      return await refrigeratorService.lockIngredient(
        roomId: roomId,
        refrigeratorName: refrigeratorName,
        compartmentIndex: compartmentIndex,
        ingredientId: ingredientId,
      );
    } catch (e) {
      print('식품 잠금 처리 오류: $e');
      rethrow;
    }
  }
  
  /// 식품 잠금 해제
  Future<bool> unlockIngredient({
    required String roomId,
    required String refrigeratorName,
    required int compartmentIndex,
    required String ingredientId,
  }) async {
    try {
      return await refrigeratorService.unlockIngredient(
        roomId: roomId,
        refrigeratorName: refrigeratorName,
        compartmentIndex: compartmentIndex,
        ingredientId: ingredientId,
      );
    } catch (e) {
      print('식품 잠금 해제 처리 오류: $e');
      rethrow;
    }
  }
}

