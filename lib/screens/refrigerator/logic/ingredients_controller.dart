import 'package:flutter/material.dart';

/// 화면의 정렬/검색 상태와 정렬 적용 로직을 담당하는 컨트롤러
class IngredientsController {
  String sortBy = 'date'; // 'date', 'expiry', 'name', 'likes'
  String searchQuery = '';

  void setSort(String sort) {
    sortBy = sort;
  }

  void setSearch(String query) {
    searchQuery = query;
  }

  void applySorting(List<Map<String, dynamic>> filtered) {
    switch (sortBy) {
      case 'date':
        filtered.sort((a, b) {
          // Firestore 필드명 'created_at' 우선 사용, 없으면 레거시 'createdAt'도 허용
          final aRaw = a['created_at'] ?? a['createdAt'];
          final bRaw = b['created_at'] ?? b['createdAt'];

          final aDate = (aRaw as dynamic)?.toDate?.call() ?? aRaw;
          final bDate = (bRaw as dynamic)?.toDate?.call() ?? bRaw;

          // 생성일이 없으면 가장 예전 날짜로 간주하여 리스트 맨 뒤로 보내기
          final aTime = aDate is DateTime ? aDate : DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = bDate is DateTime ? bDate : DateTime.fromMillisecondsSinceEpoch(0);

          // 최신순: 최근에 생성된 것이 위로 오도록 내림차순 정렬
          return bTime.compareTo(aTime);
        });
        break;
      case 'expiry':
        filtered.sort((a, b) {
          final aExpiryRaw = a['expiryDate'];
          final bExpiryRaw = b['expiryDate'];

          final aExpiry = (aExpiryRaw as dynamic)?.toDate?.call() ?? aExpiryRaw;
          final bExpiry = (bExpiryRaw as dynamic)?.toDate?.call() ?? bExpiryRaw;

          // 유통기한이 없으면 매우 먼 미래(2099년)로 간주하여 리스트 맨 뒤로 보내기
          final aTime = aExpiry is DateTime ? aExpiry : DateTime(2099);
          final bTime = bExpiry is DateTime ? bExpiry : DateTime(2099);

          // 빠른 유통기한이 위로 오도록 오름차순 정렬
          return aTime.compareTo(bTime);
        });
        break;
      case 'name':
        filtered.sort((a, b) {
          final aName = (a['name'] ?? '').toString();
          final bName = (b['name'] ?? '').toString();
          return aName.compareTo(bName);
        });
        break;
      case 'likes':
        filtered.sort((a, b) {
          final aLikes = ((a['preferences']?['likes'] as List?) ?? []).length;
          final bLikes = ((b['preferences']?['likes'] as List?) ?? []).length;
          final likeCmp = bLikes.compareTo(aLikes);
          if (likeCmp != 0) return likeCmp;

          final aRaw = a['created_at'] ?? a['createdAt'];
          final bRaw = b['created_at'] ?? b['createdAt'];

          final aDate = (aRaw as dynamic)?.toDate?.call() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = (bRaw as dynamic)?.toDate?.call() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final aTime = aDate is DateTime ? aDate : DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = bDate is DateTime ? bDate : DateTime.fromMillisecondsSinceEpoch(0);
          final dateCmp = bTime.compareTo(aTime);
          if (dateCmp != 0) return dateCmp;

          final aName = (a['name'] ?? '').toString();
          final bName = (b['name'] ?? '').toString();
          return aName.compareTo(bName);
        });
        break;
    }
  }
}


