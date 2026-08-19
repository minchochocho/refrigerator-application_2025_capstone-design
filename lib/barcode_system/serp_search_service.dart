import 'dart:convert';
import 'package:http/http.dart' as http;

class SerpSearchService {
  static final SerpSearchService _instance = SerpSearchService._internal();
  factory SerpSearchService() => _instance;
  SerpSearchService._internal();

  // 예: flutter run --dart-define=SERP_API_KEY=...
  static const String _apiKey = String.fromEnvironment('SERP_API_KEY');
  static const String _unknownImageAsset = '';
  static const Duration _timeout = Duration(seconds: 10);

  // HTTP 클라이언트 재사용
  final http.Client _client = http.Client();

  // 바코드로 상품 검색
  Future<Map<String, String>> searchProductByBarcode(String barcode) async {
    try {
      final rawProductName = await _searchProductName(barcode);
      final cleanProductName = _extractProductName(rawProductName);
      final imageUrl = cleanProductName != '알 수 없는 제품'
          ? await _searchImageByBarcode(barcode)
          : _unknownImageAsset;

      return {
        'foodName': cleanProductName,
        'imageUrl': imageUrl,
      };
    } catch (e) {
      return {
        'foodName': '알 수 없는 제품',
        'imageUrl': _unknownImageAsset,
      };
    }
  }

  // 상품명에서 핵심 제품명만 추출하는 함수 (수정된 버전)
  String _extractProductName(String rawProductName) {
    if (rawProductName == '알 수 없는 제품') {
      return rawProductName;
    }

    String cleanName = rawProductName;

    // 1. 유통기한 정보 제거 (더 정확한 패턴)
    cleanName = cleanName.replaceAll(RegExp(r'[_\s]*유통기한[\s:]*\d{4}[\.\-\s]*\d{1,2}[\.\-\s]*\d{1,2}.*?$', caseSensitive: false), '');

    // 2. 대괄호와 내용 제거
    cleanName = cleanName.replaceAll(RegExp(r'\[.*?\]'), '');

    // 3. 소괄호와 내용 제거
    cleanName = cleanName.replaceAll(RegExp(r'\([^)]*\)'), '');

    // 4. 중량/용량 정보 제거 (수정된 패턴)
    // 공백이 있거나 없거나 상관없이 숫자+단위 패턴을 매칭
    cleanName = cleanName.replaceAll(RegExp(r'\s*\d+(?:\.\d+)?\s*(?:g|gm|ml|l|kg|oz|개|입|팩|병|캔|상자|박스)(?:\*\d+)?(?:입|들이)?(?=\s|_|$|[가-힣])', caseSensitive: false), '');

    // GM과 같은 대문자 단위도 처리 (공백 유무 상관없이)
    cleanName = cleanName.replaceAll(RegExp(r'\s*\d+(?:\.\d+)?\s*(?:G|GM|ML|L|KG|OZ)(?:\*\d+)?(?=\s|_|$|[가-힣])', caseSensitive: true), '');

    // 5. 가격 정보 제거
    cleanName = cleanName.replaceAll(RegExp(r'[₩$]\d+(?:,\d{3})*(?:\.\d{2})?|\d+(?:,\d{3})*원'), '');

    // 6. 수량 표기 제거
    cleanName = cleanName.replaceAll(RegExp(r'[x*×]\d+|[0-9]+(?:개|팩|입|병|캔|상자|박스)(?:입|들이)?', caseSensitive: false), '');

    // 7. 언더스코어를 공백으로 변환 (유통기한 앞의 _ 처리)
    cleanName = cleanName.replaceAll('_', ' ');

    // 8. 특수문자를 공백으로 변환 (단, 한글과 영문은 보존)
    cleanName = cleanName.replaceAll(RegExp(r'[^\w가-힣\s]'), ' ');

    // 9. 여러 공백을 하나로 통합
    cleanName = cleanName.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 10. 브랜드명 처리 (제품 타입에 따라)
    if (_shouldRemoveBrand(cleanName)) {
      cleanName = _removeBrandName(cleanName);
    }

    // 11. 최종 정리 - 끝에 남은 단일 알파벳 제거 (M, G 등)
    cleanName = cleanName.replaceAll(RegExp(r'\s+[A-Z]$'), '');

    // 12. 최종 trim
    cleanName = cleanName.trim();

    // 13. 결과 검증
    if (cleanName.isEmpty || cleanName.length < 2) {
      return '알 수 없는 제품';
    }

    return cleanName;
  }

// 브랜드명을 제거해야 하는지 판단
  bool _shouldRemoveBrand(String productName) {
    // 우유, 음료류는 브랜드명 유지
    const keepBrandKeywords = ['우유', '음료', '물', '주스', '콜라', '사이다', '맥주', '소주', '커피'];

    for (String keyword in keepBrandKeywords) {
      if (productName.contains(keyword)) {
        return false;
      }
    }

    return true; // 기본적으로 브랜드명 제거
  }

// 브랜드명 제거
  String _removeBrandName(String productName) {
    const brandNames = [
      '크라운', '농심', '오리온', '롯데', '해태', '동원', '대상', '청정원',
      '삼양', '팔도', '빙그레', '매일', '서울우유', '남양', '코카콜라', '펩시',
      '하이트', '카스', '칠성', '웅진', '광동', '정식품', '풀무원', 'CJ', '샤니'
    ];

    String result = productName;

    for (String brand in brandNames) {
      // 브랜드명이 맨 앞에 있고 뒤에 공백이 있는 경우
      if (result.startsWith('$brand ')) {
        result = result.substring(brand.length + 1).trim();
        break;
      }
      // 브랜드명이 맨 앞에 있고 바로 붙어있는 경우
      else if (result.startsWith(brand) && result.length > brand.length) {
        String remaining = result.substring(brand.length);
        // 뒤에 한글이나 영문이 바로 오는 경우만 제거
        if (RegExp(r'^[가-힣a-zA-Z]').hasMatch(remaining)) {
          result = remaining.trim();
          break;
        }
      }
    }

    return result;
  }

// 숫자나 일반적인 브랜드명인지 확인하는 헬퍼 함수
  bool _isNumberOrBrand(String word) {
    if (RegExp(r'^\d+$').hasMatch(word)) {
      return true;
    }

    const commonBrands = [
      '크라운', '농심', '오리온', '롯데', '해태', '동원', '대상', '청정원',
      '삼양', '팔도', '코카콜라', '펩시', '하이트', '카스', '칠성', '웅진'
    ];

    return commonBrands.contains(word);
  }

// 단위인지 확인하는 헬퍼 함수
  bool _isUnit(String word) {
    const units = ['g', 'gm', 'ml', 'l', 'kg', 'oz', '개', '입', '팩', '병', '캔', '상자', '박스'];
    return units.any((unit) => word.toLowerCase().contains(unit));
  }

// 날짜 관련 단어인지 확인하는 헬퍼 함수
  bool _isDate(String word) {
    return RegExp(r'^(19|20)\d{2}$').hasMatch(word) ||
        RegExp(r'^\d{1,2}$').hasMatch(word) ||
        word.contains('유통기한');
  }

  // 상품명 검색 (에러 핸들링 개선)
  Future<String> _searchProductName(String barcode) async {
    try {
      final url = Uri.parse(
          'https://serpapi.com/search'
              '?engine=google'
              '&q=$barcode+-site:beepscan.com+-site:emile.emarteveryday.co.kr'
              '&api_key=$_apiKey'
              '&gl=kr'
              '&hl=ko'
      );

      final response = await _client.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final organicResults = data['organic_results'] as List?;

        if (organicResults?.isNotEmpty == true) {
          final result = organicResults!.first as Map<String, dynamic>;
          return result['title']?.toString() ?? '알 수 없는 제품';
        }
      }

      return '알 수 없는 제품';
    } catch (e) {
      return '알 수 없는 제품';
    }
  }

  // 이미지 검색 (에러 핸들링 개선)
  Future<String> _searchImageByBarcode(String barcode) async {
    try {
      final url = Uri.parse(
          'https://serpapi.com/search'
              '?engine=google_images'
              '&q=$barcode'
              '&api_key=$_apiKey'
              '&gl=kr'
              '&hl=ko'
      );

      final response = await _client.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final imageResults = data['images_results'] as List?;

        if (imageResults?.isNotEmpty == true) {
          final result = imageResults!.first as Map<String, dynamic>;
          return result['original']?.toString() ??
              result['thumbnail']?.toString() ??
              _unknownImageAsset;
        }
      }

      return _unknownImageAsset;
    } catch (e) {
      return _unknownImageAsset;
    }
  }

  // 리소스 정리
  void dispose() {
    _client.close();
  }
}
