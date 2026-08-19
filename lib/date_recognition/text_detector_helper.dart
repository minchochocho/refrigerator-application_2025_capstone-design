import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

class TextDetectorHelper {
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> recognizeText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      // 인식된 모든 텍스트에서 유통기한 형식 추출
      return _extractExpirationDates(recognizedText.text, recognizedText.blocks);
    } catch (e) {
      return '텍스트 인식 오류: $e';
    }
  }

  String _extractExpirationDates(String text, List<TextBlock> blocks) {
    // 점(.)으로 표시된 유통기한 형식도 포함하기 위해 전체 텍스트에서 모든 가능한 후보 검색
    final List<_DateCandidate> expirationDates = [];
    final int currentYear = DateTime.now().year;
    
    // 모든 텍스트 블록을 검사하여 날짜 형식 검색
    for (TextBlock block in blocks) {
      // 블록 내의 모든 라인 검사
      for (TextLine line in block.lines) {
        String lineText = line.text.trim();
        
        // 1. 점 패턴으로 찍힌 날짜 검색 (예: 2 0 2 6 . 0 3 . 0 4)
        // 점으로 찍힌 패턴은 특수한 처리가 필요함
        if (_containsDottedPattern(lineText)) {
          String normalizedDate = _extractDottedDatePattern(lineText);
          if (normalizedDate.isNotEmpty) {
            expirationDates.add(_DateCandidate(
              date: normalizedDate,
              confidence: 0.9, // 점으로 된 유통기한은 명확한 패턴이므로 높은 신뢰도 부여
              source: lineText
            ));
            continue; // 점 패턴이 발견되면 다른 패턴은 검사하지 않음
          }
        }
        
        // 각 라인 텍스트를 사용하여 일반적인 날짜 형식 검색
        _findDatePatterns(lineText, currentYear, expirationDates);
      }
    }
    
    // 전체 텍스트에서 한 번 더 검색 (블록 사이에 잘린 날짜가 있을 수 있음)
    _findDatePatterns(text, currentYear, expirationDates);
    
    if (expirationDates.isEmpty) {
      return '인식된 유통기한이 없습니다.\n\n지원되는 형식:\n• yyyy.mm.dd, mm.dd, dd.mm.yyyy\n• yyyy년mm월dd일, mm월dd일\n• 간단한 m-d 형식 (예: 3-12)\n• 구분자: ., /, - 모두 지원';
    }
    
    // 신뢰도 기준으로 정렬하고 가장 신뢰할 수 있는 날짜 하나만 반환
    expirationDates.sort((a, b) => b.confidence.compareTo(a.confidence));
    
    // 한 개의 날짜만 반환
    return '유통기한:\n${expirationDates.first.date}';
  }

  // 점으로 된 패턴 (2 0 2 6 . 0 3 . 0 4 같은)인지 확인
  bool _containsDottedPattern(String text) {
    // 숫자와 점이 일정 간격으로 배열된 패턴 검색
    RegExp dottedNumberPattern = RegExp(r'[2][\s\.]*[0][\s\.]*[2][\s\.]*[0-9][\s\.]*[\.][\s\.]*[0-1]?[\s\.]*[0-9][\s\.]*[\.][\s\.]*[0-3]?[\s\.]*[0-9]');
    return dottedNumberPattern.hasMatch(text);
  }
  
  // 점으로 찍힌 날짜 패턴 추출 (2 0 2 6 . 0 3 . 0 4 -> 2026.03.04)
  String _extractDottedDatePattern(String text) {
    try {
      // 모든 공백 제거
      String cleanText = text.replaceAll(RegExp(r'\s'), '');
      
      // 숫자와 점으로만 구성된 패턴 추출
      RegExp datePattern = RegExp(r'(20\d{2})\.(0?[1-9]|1[0-2])\.(0?[1-9]|[12][0-9]|3[01])');
      Match? match = datePattern.firstMatch(cleanText);
      
      if (match != null) {
        String year = match.group(1) ?? '';
        String month = match.group(2) ?? '';
        String day = match.group(3) ?? '';
        
        // 월과 일이 한 자리면 두 자리로 맞춤
        month = month.padLeft(2, '0');
        day = day.padLeft(2, '0');
        
        return '$year.$month.$day';
      }
      
      return '';
    } catch (e) {
      print('점 패턴 날짜 추출 오류: $e');
      return '';
    }
  }

  // 다양한 날짜 패턴 검색
  void _findDatePatterns(String line, int currentYear, List<_DateCandidate> expirationDates) {
    // 1. yyyy.mm.dd 형식 (2024.05.12, 2024.5.12, 2024.05.1 등) - 점 또는 슬래시 또는 하이픈 구분자
    RegExp fullYearDotFormat = RegExp(r'\b(20\d{2})[./-](0?[1-9]|1[0-2])[./-](0?[1-9]|[12][0-9]|3[01])\b');
    
    // 2. mm.dd 형식 (05.12, 5.12, 05.1 등) - 점 또는 슬래시 또는 하이픈 구분자
    RegExp shortDateFormat = RegExp(r'\b(0?[1-9]|1[0-2])[./-](0?[1-9]|[12][0-9]|3[01])\b');
    
    // 3. yyyy년mm월dd일 형식 (2024년05월12일, 2024년5월12일 등)
    RegExp koreanDateFormat = RegExp(r'\b(20\d{2})년\s*(0?[1-9]|1[0-2])월\s*(0?[1-9]|[12][0-9]|3[01])일\b');
    
    // 4. mm월dd일 형식 (05월12일, 5월12일 등)
    RegExp shortKoreanDateFormat = RegExp(r'\b(0?[1-9]|1[0-2])월\s*(0?[1-9]|[12][0-9]|3[01])일\b');
    
    // 5. dd.mm.yyyy 형식 (유럽식 날짜 - 12.05.2024 등)
    RegExp europeanDateFormat = RegExp(r'\b(0?[1-9]|[12][0-9]|3[01])[./-](0?[1-9]|1[0-2])[./-](20\d{2})\b');

    // 6. mm-yyyy 또는 mm/yyyy 형식 (05-2024, 05/2024 등)
    RegExp monthYearFormat = RegExp(r'\b(0?[1-9]|1[0-2])[./-](20\d{2})\b');
    
    // 7. 간단한 m-d 형식 (3-12 같은 형식)
    RegExp simpleFormat = RegExp(r'\b([1-9]|1[0-2])-([1-9]|[12][0-9]|3[01])\b');
    
    // yyyy.mm.dd 형식 찾기
    Iterable<Match> fullYearMatches = fullYearDotFormat.allMatches(line);
    for (Match match in fullYearMatches) {
      String dateStr = match.group(0)!;
      
      // 구분자를 통일시켜 yyyy.mm.dd 형식으로 변환
      dateStr = _normalizeDate(dateStr, format: 'yyyy.MM.dd');
      if (dateStr.isNotEmpty) {
        expirationDates.add(_DateCandidate(
          date: dateStr,
          confidence: 0.9, // 가장 명확한 형식이므로 높은 신뢰도
          source: match.group(0)!
        ));
      }
    }
    
    // dd.mm.yyyy (유럽식) 형식 찾기
    Iterable<Match> europeanMatches = europeanDateFormat.allMatches(line);
    for (Match match in europeanMatches) {
      String dateStr = match.group(0)!;
      
      // 구분자 통일 및 형식 변환 (dd.mm.yyyy -> yyyy.mm.dd)
      dateStr = _normalizeDate(dateStr, isEuropean: true);
      if (dateStr.isNotEmpty) {
        expirationDates.add(_DateCandidate(
          date: dateStr,
          confidence: 0.85, // 유럽식은 약간 낮은 신뢰도
          source: match.group(0)!
        ));
      }
    }
    
    // yyyy년mm월dd일 형식 찾기
    Iterable<Match> koreanMatches = koreanDateFormat.allMatches(line);
    for (Match match in koreanMatches) {
      try {
        final year = match.group(1);
        final month = match.group(2);
        final day = match.group(3);
        
        if (year != null && month != null && day != null) {
          // 숫자만 추출하고 yyyy.mm.dd 형식으로 변환
          String normalizedMonth = month.padLeft(2, '0');
          String normalizedDay = day.padLeft(2, '0');
          String dateStr = '$year.$normalizedMonth.$normalizedDay';
          
          expirationDates.add(_DateCandidate(
            date: dateStr,
            confidence: 0.9, // 한국어 명확한 형식이므로 높은 신뢰도
            source: match.group(0)!
          ));
        }
      } catch (e) {
        print('한국어 날짜 형식 파싱 오류: $e');
      }
    }
    
    // 같은 라인에 이미 full 형식이 있으면 short 형식은 검사하지 않음
    if (fullYearMatches.isEmpty && europeanMatches.isEmpty && koreanMatches.isEmpty) {
      // mm.dd 형식 찾기
      Iterable<Match> shortDateMatches = shortDateFormat.allMatches(line);
      for (Match match in shortDateMatches) {
        String shortDate = match.group(0)!;
        
        // 구분자 통일 후 현재 연도를 앞에 붙여 yyyy.mm.dd 형식으로 변환
        String dateStr = _normalizeShortDate(shortDate, currentYear);
        if (dateStr.isNotEmpty) {
          expirationDates.add(_DateCandidate(
            date: dateStr,
            confidence: 0.6, // 단축 날짜는 낮은 신뢰도
            source: match.group(0)!
          ));
        }
      }
      
      // 간단한 m-d 형식 처리 (3-12 같은 형식)
      Iterable<Match> simpleMatches = simpleFormat.allMatches(line);
      for (Match match in simpleMatches) {
        try {
          final m = match.group(1);
          final d = match.group(2);
          
          if (m != null && d != null) {
            // 월과 일자를 yyyy.mm.dd 형식으로 변환
            int month = int.parse(m);
            int day = int.parse(d);
            
            if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
              String paddedMonth = month.toString().padLeft(2, '0');
              String paddedDay = day.toString().padLeft(2, '0');
              String dateStr = '$currentYear.$paddedMonth.$paddedDay';
              
              expirationDates.add(_DateCandidate(
                date: dateStr,
                confidence: 0.5, // 단순 형식은 가장 낮은 신뢰도
                source: match.group(0)!
              ));
            }
          }
        } catch (e) {
          print('단순 날짜 형식 파싱 오류: $e');
        }
      }
      
      // mm월dd일 형식 찾기
      Iterable<Match> shortKoreanMatches = shortKoreanDateFormat.allMatches(line);
      for (Match match in shortKoreanMatches) {
        try {
          final month = match.group(1);
          final day = match.group(2);
          
          if (month != null && day != null) {
            // 현재 연도를 앞에 붙여 yyyy.mm.dd 형식으로 변환
            String normalizedMonth = month.padLeft(2, '0');
            String normalizedDay = day.padLeft(2, '0');
            String dateStr = '$currentYear.$normalizedMonth.$normalizedDay';
            
            expirationDates.add(_DateCandidate(
              date: dateStr,
              confidence: 0.7, // 한국어 단축 형식은 중간 신뢰도
              source: match.group(0)!
            ));
          }
        } catch (e) {
          print('한국어 단축 날짜 형식 파싱 오류: $e');
        }
      }
      
      // mm-yyyy 또는 mm/yyyy 형식 찾기
      Iterable<Match> monthYearMatches = monthYearFormat.allMatches(line);
      for (Match match in monthYearMatches) {
        String dateStr = match.group(0)!;
        
        // mm/yyyy를 yyyy.mm.01 형식으로 변환 (일자는 1일로 설정)
        dateStr = _normalizeMonthYearFormat(dateStr);
        if (dateStr.isNotEmpty) {
          expirationDates.add(_DateCandidate(
            date: dateStr,
            confidence: 0.65, // 월/연도 형식은 약간 낮은 신뢰도
            source: match.group(0)!
          ));
        }
      }
    }
  }
  
  // 날짜 구분자 통일 (yyyy.mm.dd 형식으로)
  String _normalizeDate(String dateStr, {String format = 'yyyy.MM.dd', bool isEuropean = false}) {
    try {
      // 구분자 통일 (모든 구분자를 임시로 '/'로 변경)
      dateStr = dateStr.replaceAll('.', '/').replaceAll('-', '/');
      
      DateTime dateTime;
      if (isEuropean) {
        // dd/mm/yyyy 형식을 파싱
        List<String> parts = dateStr.split('/');
        if (parts.length == 3) {
          // 순서를 yyyy/mm/dd로 변경
          dateStr = '${parts[2]}/${parts[1]}/${parts[0]}';
        }
      }
      
      // 날짜 파싱
      dateTime = DateFormat('yyyy/MM/dd').parse(dateStr);
      
      // yyyy.mm.dd 형식으로 변환
      return DateFormat('yyyy.MM.dd').format(dateTime);
    } catch (e) {
      print('날짜 정규화 오류: $e, 날짜: $dateStr');
      return '';
    }
  }
  
  // mm.dd 또는 mm/dd 형식을 yyyy.mm.dd 형식으로 변환
  String _normalizeShortDate(String shortDate, int currentYear) {
    try {
      // 구분자 통일 (모든 구분자를 임시로 '/'로 변경)
      shortDate = shortDate.replaceAll('.', '/').replaceAll('-', '/');
      
      // 현재 연도를 앞에 붙임
      String fullDate = '$currentYear/$shortDate';
      
      // 날짜 파싱 및 변환
      DateTime dateTime = DateFormat('yyyy/MM/dd').parse(fullDate);
      return DateFormat('yyyy.MM.dd').format(dateTime);
    } catch (e) {
      print('단축 날짜 정규화 오류: $e, 날짜: $shortDate');
      return '';
    }
  }
  
  // mm/yyyy 형식을 yyyy.mm.01 형식으로 변환
  String _normalizeMonthYearFormat(String monthYearStr) {
    try {
      // 구분자 통일
      monthYearStr = monthYearStr.replaceAll('.', '/').replaceAll('-', '/');
      
      List<String> parts = monthYearStr.split('/');
      if (parts.length == 2) {
        // 월/연도 순서를 연도/월로 변경하고 일자를 1일로 설정
        String month = parts[0].padLeft(2, '0');
        String year = parts[1];
        
        return '$year.$month.01';
      }
      return '';
    } catch (e) {
      print('월/연도 형식 정규화 오류: $e, 날짜: $monthYearStr');
      return '';
    }
  }

  void dispose() {
    textRecognizer.close();
  }
}

// 후보 날짜 클래스
class _DateCandidate {
  final String date;      // yyyy.mm.dd 형식의 날짜
  final double confidence; // 신뢰도 (0.0~1.0)
  final String source;    // 원본 텍스트

  _DateCandidate({
    required this.date,
    required this.confidence,
    required this.source,
  });
}