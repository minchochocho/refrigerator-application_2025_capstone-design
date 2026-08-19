import 'package:cloud_firestore/cloud_firestore.dart';

class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 한글 초성 매핑
  static const Map<String, String> _chosungMap = {
    'ㄱ': 'ㄱ', 'ㄲ': 'ㄲ', 'ㄴ': 'ㄴ', 'ㄷ': 'ㄷ', 'ㄸ': 'ㄸ',
    'ㄹ': 'ㄹ', 'ㅁ': 'ㅁ', 'ㅂ': 'ㅂ', 'ㅃ': 'ㅃ', 'ㅅ': 'ㅅ',
    'ㅆ': 'ㅆ', 'ㅇ': 'ㅇ', 'ㅈ': 'ㅈ', 'ㅉ': 'ㅉ', 'ㅊ': 'ㅊ',
    'ㅋ': 'ㅋ', 'ㅌ': 'ㅌ', 'ㅍ': 'ㅍ', 'ㅎ': 'ㅎ'
  };

  // 검색어가 "순수 초성"으로만 이루어져 있는지 확인
  bool _isChosungQuery(String text) {
    if (text.isEmpty) return false;
    for (int i = 0; i < text.length; i++) {
      final ch = text[i];
      if (!_chosungMap.containsKey(ch)) {
        return false;
      }
    }
    return true;
  }

  // 한글 초성 추출
  String _extractChosung(String text) {
    String chosung = '';
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code >= 0xAC00 && code <= 0xD7A3) {
        // 한글 완성형 문자
        int chosungIndex = ((code - 0xAC00) ~/ 588);
        List<String> chosungList = ['ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ'];
        if (chosungIndex < chosungList.length) {
          chosung += chosungList[chosungIndex];
        }
      } else if (_chosungMap.containsKey(text[i])) {
        // 이미 초성인 경우
        chosung += text[i];
      }
    }
    return chosung;
  }

  // 문자열 유사도 계산 (레벤슈타인 거리 기반)
  double _calculateSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    
    a = a.toLowerCase().replaceAll(' ', '');
    b = b.toLowerCase().replaceAll(' ', '');
    
    if (a == b) return 1.0;
    
    List<List<int>> matrix = List.generate(
      a.length + 1,
      (i) => List.generate(b.length + 1, (j) => 0),
    );

    for (int i = 0; i <= a.length; i++) {
      matrix[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        int cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    int maxLength = a.length > b.length ? a.length : b.length;
    return 1.0 - (matrix[a.length][b.length] / maxLength);
  }

  // 향상된 매칭 검사
  bool _isMatch(String ingredientName, String searchQuery, {double threshold = 0.6}) {
    if (ingredientName.isEmpty || searchQuery.isEmpty) return false;
    
    String cleanIngredientName = ingredientName.toLowerCase().replaceAll(' ', '');
    String cleanSearchQuery = searchQuery.toLowerCase().replaceAll(' ', '');
    
    // 1. 정확한 문자열 포함 매칭 (가장 우선, 항상 동일한 기준)
    if (cleanIngredientName.contains(cleanSearchQuery)) {
      return true;
    }
    
    // 2. 순수 초성으로만 이루어진 검색어인 경우에만 초성 검색 허용
    //    예: 'ㅊㅈ' → '치즈' 매칭, 하지만 '치즈' 같이 완성형 글자는 초성 검색을 사용하지 않음
    if (_isChosungQuery(searchQuery)) {
      String ingredientChosung = _extractChosung(ingredientName);
      String searchChosung = _extractChosung(searchQuery);
      if (searchChosung.isNotEmpty && ingredientChosung.contains(searchChosung)) {
        return true;
      }
    }
    
    // 3. 부분 단어 매칭 (띄어쓰기로 분리된 단어들) - 유사도 대신 '포함 여부'만 사용
    List<String> ingredientWords = ingredientName.toLowerCase().split(' ');
    List<String> searchWords = searchQuery.toLowerCase().split(' ');
    
    for (String searchWord in searchWords) {
      String trimmed = searchWord.trim();
      if (trimmed.isEmpty) continue;
      bool wordFound = false;
      for (String ingredientWord in ingredientWords) {
        // 단순 부분 문자열 포함으로만 판단 (오탐 줄이기)
        if (ingredientWord.contains(trimmed)) {
          wordFound = true;
          break;
        }
      }
      if (!wordFound) return false;
    }
    
    return searchWords.isNotEmpty;
  }

  // 방 내 모든 냉장고에서 식품 검색
  Future<List<Map<String, dynamic>>> searchIngredientsInRoom(
    String roomId,
    String searchQuery,
  ) async {
    if (searchQuery.trim().isEmpty) {
      return [];
    }

    try {
      List<Map<String, dynamic>> results = [];
      
      // 방의 모든 냉장고 조회
      QuerySnapshot refrigeratorsSnapshot = await _firestore
          .collection('Refrigerators')
          .where('room_id', isEqualTo: roomId)
          .get();

      for (DocumentSnapshot refrigeratorDoc in refrigeratorsSnapshot.docs) {
        String refrigeratorId = refrigeratorDoc.id;
        Map<String, dynamic> refrigeratorData = refrigeratorDoc.data() as Map<String, dynamic>;
        String refrigeratorName = refrigeratorData['name'] ?? '알 수 없는 냉장고';
        
        // 냉장고의 칸 이름들 가져오기
        List<String> compartmentNames = List<String>.from(
          refrigeratorData['compartment_names'] ?? []
        );

        // 각 칸에서 재료 검색
        for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
          String compartmentName = compartmentNames[compartmentIndex];
          
          QuerySnapshot ingredientsSnapshot = await _firestore
              .collection('Refrigerators')
              .doc(refrigeratorId)
              .collection('compartments')
              .doc(compartmentIndex.toString())
              .collection('ingredients')
              .get();

          for (DocumentSnapshot ingredientDoc in ingredientsSnapshot.docs) {
            Map<String, dynamic> ingredientData = ingredientDoc.data() as Map<String, dynamic>;
            String ingredientName = ingredientData['name'] ?? '';
            
            // 향상된 검색 매칭 사용
            if (_isMatch(ingredientName, searchQuery) ||
                _isMatch(ingredientData['memo']?.toString() ?? '', searchQuery)) {
              results.add({
                'id': ingredientDoc.id,
                'name': ingredientName,
                'quantity': ingredientData['quantity']?.toString() ?? '',
                'expiryDate': ingredientData['expiryDate'],
                'refrigeratorName': refrigeratorName,
                'refrigeratorId': refrigeratorId,
                'compartmentName': compartmentName,
                'compartmentIndex': compartmentIndex,
                'created_at': ingredientData['created_at'],
                'memo': ingredientData['memo']?.toString() ?? '',
                'imagePath': ingredientData['imagePath']?.toString() ?? '',
                'preferences': ingredientData['preferences'] ?? {},
                'layout': refrigeratorData['layout'] ?? 'single',
              });
            }
          }
        }
      }

      // 검색 결과를 유사도 순으로 정렬 (높은 유사도가 먼저)
      results.sort((a, b) {
        double similarityA = _calculateSimilarity(a['name'], searchQuery);
        double similarityB = _calculateSimilarity(b['name'], searchQuery);
        
        // 유사도가 높은 순으로 정렬
        int similarityComparison = similarityB.compareTo(similarityA);
        if (similarityComparison != 0) {
          return similarityComparison;
        }
        
        // 유사도가 같으면 냉장고명, 칸명 순으로 정렬
        int refrigeratorComparison = (a['refrigeratorName'] as String)
            .compareTo(b['refrigeratorName'] as String);
        if (refrigeratorComparison != 0) {
          return refrigeratorComparison;
        }
        return (a['compartmentName'] as String)
            .compareTo(b['compartmentName'] as String);
      });

      return results;
    } catch (e) {
      print('검색 오류: $e');
      return [];
    }
  }

  // 특정 냉장고에서 식품 검색
  Future<List<Map<String, dynamic>>> searchIngredientsInRefrigerator(
    String roomId,
    String refrigeratorName,
    String searchQuery,
  ) async {
    if (searchQuery.trim().isEmpty) {
      return [];
    }

    try {
      List<Map<String, dynamic>> results = [];
      
      // 해당 냉장고 찾기
      QuerySnapshot refrigeratorsSnapshot = await _firestore
          .collection('Refrigerators')
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();

      if (refrigeratorsSnapshot.docs.isEmpty) {
        return [];
      }

      DocumentSnapshot refrigeratorDoc = refrigeratorsSnapshot.docs.first;
      String refrigeratorId = refrigeratorDoc.id;
      Map<String, dynamic> refrigeratorData = refrigeratorDoc.data() as Map<String, dynamic>;
      
      // 냉장고의 칸 이름들 가져오기
      List<String> compartmentNames = List<String>.from(
        refrigeratorData['compartment_names'] ?? []
      );

      // 각 칸에서 재료 검색
      for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
        String compartmentName = compartmentNames[compartmentIndex];
        
        QuerySnapshot ingredientsSnapshot = await _firestore
            .collection('Refrigerators')
            .doc(refrigeratorId)
            .collection('compartments')
            .doc(compartmentIndex.toString())
            .collection('ingredients')
            .get();

        for (DocumentSnapshot ingredientDoc in ingredientsSnapshot.docs) {
          Map<String, dynamic> ingredientData = ingredientDoc.data() as Map<String, dynamic>;
          String ingredientName = ingredientData['name'] ?? '';
          
          // 향상된 검색 매칭 사용
          if (_isMatch(ingredientName, searchQuery) ||
              _isMatch(ingredientData['memo']?.toString() ?? '', searchQuery)) {
            results.add({
              'id': ingredientDoc.id,
              'name': ingredientName,
              'quantity': ingredientData['quantity']?.toString() ?? '',
              'expiryDate': ingredientData['expiryDate'],
              'refrigeratorName': refrigeratorName,
              'refrigeratorId': refrigeratorId,
              'compartmentName': compartmentName,
              'compartmentIndex': compartmentIndex,
              'created_at': ingredientData['created_at'],
              'memo': ingredientData['memo']?.toString() ?? '',
              'imagePath': ingredientData['imagePath']?.toString() ?? '',
              'preferences': ingredientData['preferences'] ?? {},
              'layout': refrigeratorData['layout'] ?? 'single',
            });
          }
        }
      }

      // 검색 결과를 유사도 순으로 정렬 (높은 유사도가 먼저)
      results.sort((a, b) {
        double similarityA = _calculateSimilarity(a['name'], searchQuery);
        double similarityB = _calculateSimilarity(b['name'], searchQuery);
        
        // 유사도가 높은 순으로 정렬
        int similarityComparison = similarityB.compareTo(similarityA);
        if (similarityComparison != 0) {
          return similarityComparison;
        }
        
        // 유사도가 같으면 칸명 순으로 정렬
        return (a['compartmentName'] as String)
            .compareTo(b['compartmentName'] as String);
      });

      return results;
    } catch (e) {
      print('냉장고 검색 오류: $e');
      return [];
    }
  }

  // 최근 검색어 저장 (로컬 저장소 사용)
  Future<void> saveRecentSearch(String searchQuery) async {
    // TODO: SharedPreferences 또는 다른 로컬 저장소 구현
  }

  // 최근 검색어 가져오기
  Future<List<String>> getRecentSearches() async {
    // TODO: SharedPreferences 또는 다른 로컬 저장소에서 가져오기
    return [];
  }
} 