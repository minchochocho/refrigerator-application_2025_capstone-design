import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// 재료 관련 유틸리티 함수들
class IngredientUtils {
  /// 정확한 D-day 계산
  static int calculateDaysLeft(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    
    return expiry.difference(today).inDays;
  }
  
  /// D-day 표시 텍스트 생성
  static String getDayDisplayText(int daysLeft) {
    if (daysLeft < 0) {
      return 'D+${-daysLeft}'; // 만료된 경우
    } else if (daysLeft == 0) {
      return 'D-day'; // 당일
    } else {
      return 'D-$daysLeft'; // 남은 일수
    }
  }
  
  /// D-day 표시 색상
  static Color getDayDisplayColor(int daysLeft) {
    if (daysLeft < 0) {
      return Colors.red[600]!; // 만료됨 - 빨강
    } else if (daysLeft == 0) {
      return Colors.orange[600]!; // 오늘 - 주황
    } else if (daysLeft == 1) {
      return Colors.amber[600]!; // 내일 - 노랑
    } else if (daysLeft <= 3) {
      return Colors.yellow[700]!; // 3일 이내 - 연노랑
    } else {
      return Colors.green[600]!; // 일반 - 초록
    }
  }
  
  /// 날짜 포맷팅
  static String formatDate(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }
  
  /// 날짜 및 시간 포맷팅
  static String formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      // 오늘인 경우 시간만 표시
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '오늘 $hour:$minute';
    } else if (difference.inDays == 1) {
      // 어제인 경우
      return '어제';
    } else if (difference.inDays < 7) {
      // 일주일 이내
      return '${difference.inDays}일 전';
    } else {
      // 그 외의 경우 날짜 표시
      return '${dateTime.month}/${dateTime.day}';
    }
  }
  
  /// 카드 높이 계산 (유통기한 상태에 따라 동적 크기)
  static double calculateCardHeight(Map<String, dynamic> ingredient) {
    final DateTime? expiryDate = ingredient['expiryDate']?.toDate();
    final DateTime? manufactureDate = ingredient['manufactureDate']?.toDate();
    final String memo = ingredient['memo']?.toString() ?? '';
    final bool isExpiring = expiryDate != null && calculateDaysLeft(expiryDate) <= 3;
    final bool isExpired = expiryDate != null && calculateDaysLeft(expiryDate) < 0;
    
    // 실제 UI 구조 기반 정확한 높이 계산
    double height = 0;
    
    // 1. 컨테이너 패딩 (상단)
    height += (isExpired || isExpiring) ? 20 : 16;
    
    // 2. 메인 Row 높이 (이미지 48px + 텍스트 영역)
    double textHeight = 0;
    textHeight += 20; // 식품명 (fontSize: 16, fontWeight: bold)
    textHeight += 4;  // SizedBox(height: 4)
    textHeight += 18; // 수량 텍스트 (fontSize: 14)
    
    if (manufactureDate != null) {
      textHeight += 2 + 16; // SizedBox + 제조일 텍스트
    }
    
    if (expiryDate != null) {
      textHeight += 2 + 16; // SizedBox + 유통기한 텍스트
    }
    
    if (memo.isNotEmpty) {
      textHeight += 2 + 18; // SizedBox + 메모 텍스트 (maxLines: 2)
      if (ingredient['memoAuthor'] != null) {
        textHeight += 1 + 13; // 작성자 정보
      }
      if (ingredient['memoCreatedAt'] != null || ingredient['memoUpdatedAt'] != null) {
        textHeight += 1 + 13; // 시간 정보
      }
    }
    
    // Row 높이는 이미지(48px)와 텍스트 영역 중 더 큰 값
    height += math.max(48, textHeight);
    
    // 3. 컨테이너 패딩 (하단)
    height += (isExpired || isExpiring) ? 20 : 16;
    
    // 4. 컨테이너 마진 (하단)
    height += 16;
    
    return height;
  }
  
  /// 누적 스크롤 위치 계산 (각 카드의 실제 크기 고려)
  static double calculateCumulativeOffset(int targetIndex, List<Map<String, dynamic>> ingredients) {
    double totalOffset = 0.0;
    
    print('🧮 === 누적 오프셋 계산 시작 ===');
    print('🧮 타겟 인덱스: $targetIndex');
    
    // 타겟 인덱스까지의 모든 카드 높이 누적 (패딩은 제외)
    for (int i = 0; i < targetIndex && i < ingredients.length; i++) {
      double cardHeight = calculateCardHeight(ingredients[i]);
      totalOffset += cardHeight;
      
      print('🧮   [$i] ${ingredients[i]['name']}: ${cardHeight}px (누적: ${totalOffset}px)');
    }
    
    print('🧮 최종 누적 오프셋: $totalOffset (패딩 제외)');
    
    return totalOffset;
  }
  
  /// 날짜 범위 체크 헬퍼 함수
  static bool isDateInRange(DateTime date, DateTime? firstDate, DateTime? lastDate) {
    if (firstDate != null && date.isBefore(firstDate)) return false;
    if (lastDate != null && date.isAfter(lastDate)) return false;
    return true;
  }
}

