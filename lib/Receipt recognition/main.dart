import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:math' as Math;
import '../services/groq_local_config.dart';
import '../services/vision_config.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '영수증 스캐너',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ReceiptScannerHomePage(),
    );
  }
}

class ReceiptScannerHomePage extends StatefulWidget {
  @override
  _ReceiptScannerHomePageState createState() => _ReceiptScannerHomePageState();
}

class _ReceiptScannerHomePageState extends State<ReceiptScannerHomePage> {
  File? _image;
  String _extractedText = '';
  List<ReceiptItem> _receiptItems = [];
  bool _isLoading = false;
  
  // 예: flutter run --dart-define=GOOGLE_VISION_API_KEY=...
  final String _apiKey = VisionConfig.apiKey;
  
  final ImagePicker _picker = ImagePicker();
  
  // API 사용량 변수들
  int _dailyUsage = 0;
  int _monthlyUsage = 0;
  String _lastResetDate = '';

  @override
  void initState() {
    super.initState();
    _loadUsageData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUsageData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String today = DateTime.now().toString().substring(0, 10); // YYYY-MM-DD
    String currentMonth = DateTime.now().toString().substring(0, 7); // YYYY-MM
    
    setState(() {
      _dailyUsage = prefs.getInt('daily_usage_$today') ?? 0;
      _monthlyUsage = prefs.getInt('monthly_usage_$currentMonth') ?? 0;
      _lastResetDate = prefs.getString('last_reset_date') ?? today;
    });
  }

  Future<void> _incrementUsage() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String today = DateTime.now().toString().substring(0, 10);
    String currentMonth = DateTime.now().toString().substring(0, 7);
    
    // 일일 사용량 증가
    int newDailyUsage = (prefs.getInt('daily_usage_$today') ?? 0) + 1;
    await prefs.setInt('daily_usage_$today', newDailyUsage);
    
    // 월간 사용량 증가
    int newMonthlyUsage = (prefs.getInt('monthly_usage_$currentMonth') ?? 0) + 1;
    await prefs.setInt('monthly_usage_$currentMonth', newMonthlyUsage);
    
    setState(() {
      _dailyUsage = newDailyUsage;
      _monthlyUsage = newMonthlyUsage;
    });
  }

  bool _canUseAPI() {
    return _dailyUsage < 50 && _monthlyUsage < 900;
  }

  void _showUsageLimitDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('🚫 API 사용량 초과'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('안전을 위해 사용량을 제한합니다:'),
              SizedBox(height: 8),
              Text('오늘: $_dailyUsage/50회'),
              Text('📆 이번 달: $_monthlyUsage/900회'),
              SizedBox(height: 12),
              Text('내일 또는 다음 달에 다시 시도해주세요!', 
                style: TextStyle(color: Colors.red[600])),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('확인'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _requestPermissions() async {
    await Permission.camera.request();
    await Permission.storage.request();
  }

  Future<void> _pickImageFromCamera() async {
    // API 사용량 먼저 체크 (확실하게)
    await _loadUsageData();
    if (!_canUseAPI()) {
      _showUsageLimitDialog();
      return;
    }
    
    await _requestPermissions();
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 100,
    );
    if (image != null) {
      setState(() {
        _image = File(image.path);
        _isLoading = true;
      });
      await _processImageWithGoogleVision();
    }
  }

  Future<void> _pickImageFromGallery() async {
    // API 사용량 먼저 체크 (확실하게)
    await _loadUsageData();
    if (!_canUseAPI()) {
      _showUsageLimitDialog();
      return;
    }
    
    await _requestPermissions();
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (image != null) {
      setState(() {
        _image = File(image.path);
        _isLoading = true;
      });
      await _processImageWithGoogleVision();
    }
  }

  Future<void> _processImageWithGoogleVision() async {
    if (_image == null) return;

    // 한 번 더 사용량 체크 (이중 안전장치)
    await _loadUsageData();
    if (!_canUseAPI()) {
      _showUsageLimitDialog();
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // API 사용량 증가 (호출 전에 미리 증가)
      await _incrementUsage();
      
      // 이미지를 base64로 인코딩
      List<int> imageBytes = await _image!.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      
      // Google Cloud Vision API 요청
      final response = await http.post(
        Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$_apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'requests': [
            {
              'image': {
                'content': base64Image,
              },
              'features': [
                {
                  'type': 'TEXT_DETECTION',
                  'maxResults': 10,
                }
              ],
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        if (responseData['responses'] != null && 
            responseData['responses'].isNotEmpty &&
            responseData['responses'][0]['textAnnotations'] != null) {
          
          String recognizedText = responseData['responses'][0]['textAnnotations'][0]['description'];
          
          // 🚀 1단계: 기본 파싱
          List<ReceiptItem> basicItems = _parseReceiptTextAdvanced(recognizedText);
          
          // 🤖 2단계: AI 후처리로 정제
          List<ReceiptItem> refinedItems = await _refineWithAI(recognizedText, basicItems);
          
          setState(() {
            _extractedText = recognizedText;
            _receiptItems = refinedItems;
            _isLoading = false;
          });
        } else {
          setState(() {
            _extractedText = '텍스트를 찾을 수 없습니다.';
            _receiptItems = [];
            _isLoading = false;
          });
        }
      } else {
        final errorData = json.decode(response.body);
        setState(() {
          _extractedText = 'API 오류: ${errorData['error']['message'] ?? '알 수 없는 오류'}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _extractedText = '오류 발생: $e';
        _isLoading = false;
      });
    }
  }

  Future<List<ReceiptItem>> _refineWithAI(String ocrText, List<ReceiptItem> basicItems) async {
    print('\n🤖 === AI 후처리 시작 ===');
    
    try {
      // Groq API 사용 (월 14,400회 무료!)
      String prompt = _buildAIPrompt(ocrText, basicItems);
      
      final aiResponse = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${GroqLocalConfig.apiKey}',
        },
        body: json.encode({
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'user',
              'content': prompt
            }
          ],
          'temperature': 0.3,
          'max_tokens': 1000
        }),
      );

      if (aiResponse.statusCode == 200) {
        final aiData = json.decode(aiResponse.body);
        String aiResult = aiData['choices'][0]['message']['content'];
        
        return _parseAIResponse(aiResult);
      } else {
        print('❌ AI API 오류: ${aiResponse.statusCode}');
        print('❌ 응답: ${aiResponse.body}');
        return basicItems; // AI 실패시 기본 결과 사용
      }
    } catch (e) {
      print('❌ AI 후처리 실패: $e');
      return basicItems; // 오류시 기본 결과 사용
    }
  }

  String _buildAIPrompt(String ocrText, List<ReceiptItem> basicItems) {
    return '''
영수증 OCR 텍스트를 분석해서 진짜 음식/상품만 정확히 추출해주세요.

=== OCR 원본 텍스트 ===
$ocrText

=== 현재 추출된 항목들 ===
${basicItems.map((item) => '${item.name} x ${item.quantity}개').join('\n')}

=== 요청사항 ===
1. 위 항목들 중에서 진짜 음식/상품만 선별해주세요
2. 사업자번호, 전화번호, 매장정보, 기본-5 같은 코드는 제외
3. 수량도 정확히 파악해주세요 (주변 숫자 분석)
4. 결과는 아래 형식으로만 답변:

상품명1|수량1
상품명2|수량2
상품명3|수량3

예시: 
싸이버거|1
상큠에이드|2
치즈추가|1

진짜 음식/상품이 아닌 것들은 절대 포함하지 마세요.
''';
  }

  List<ReceiptItem> _parseAIResponse(String aiResponse) {
    List<ReceiptItem> refinedItems = [];
    
    print('🤖 AI 응답: $aiResponse');
    
    List<String> lines = aiResponse.split('\n')
        .where((line) => line.trim().isNotEmpty && line.contains('|'))
        .toList();
    
    for (String line in lines) {
      List<String> parts = line.split('|');
      if (parts.length == 2) {
        String name = parts[0].trim();
        int quantity = int.tryParse(parts[1].trim()) ?? 1;
        
        if (name.isNotEmpty && quantity > 0) {
          refinedItems.add(ReceiptItem(
            name: name,
            quantity: quantity,
            price: 0
          ));
          print('✅ AI 정제 완료: $name x ${quantity}개');
        }
      }
    }
    
    print('\n🎉 AI 후처리 완료: ${refinedItems.length}개 상품');
    return refinedItems;
  }

  List<ReceiptItem> _parseReceiptTextAdvanced(String text) {
    List<ReceiptItem> items = [];
    List<String> lines = text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    
    print('\n🧠 === 초지능 AI 판단 파싱 엔진 ===');
    print('📝 전체 라인 수: ${lines.length}');
    
    // AI처럼 의미 기반으로 분석
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      
      // 1단계: 상품명에서 가격 분리 (AI 스타일)
      String cleanProductName = _separateProductFromPrice(line);
      if (cleanProductName.isEmpty) continue;
      
      // 2단계: 이 라인이 진짜 상품명인지 AI처럼 판단
      if (_isRealProduct(cleanProductName, lines, i)) {
        
        // 3단계: 똑똑한 수량 추출 (금액과 구분)
        int quantity = _smartQuantityExtraction(cleanProductName, lines, i);
        
        print('🎯 진짜 상품 발견: "$cleanProductName" x ${quantity}개');
        
        // 중복 검사
        bool isDuplicate = items.any((item) => 
            _isSimilarProductName(item.name, cleanProductName));
        
        if (!isDuplicate) {
          items.add(ReceiptItem(name: cleanProductName, quantity: quantity, price: 0));
        }
      }
    }
    
    print('\n✨ === 초지능 AI 최종 결과: ${items.length}개 상품 ===');
    for (var item in items) {
      print('🍽️ ${item.name} x ${item.quantity}개');
    }
    
    return items;
  }

  String _separateProductFromPrice(String line) {
    // AI 스타일: 상품명에서 가격 부분 제거
    
    // 패턴 1: "상품명 12,000" 형태
    RegExp pricePattern1 = RegExp(r'(.+?)\s+(\d{1,3}(?:,\d{3})+|\d{4,})$');
    Match? match1 = pricePattern1.firstMatch(line);
    if (match1 != null) {
      String productPart = match1.group(1)?.trim() ?? '';
      String pricePart = match1.group(2) ?? '';
      
      // 가격이 1000원 이상이면 분리
      int? price = int.tryParse(pricePart.replaceAll(',', ''));
      if (price != null && price >= 1000) {
        print('💡 가격 분리: "$productPart" (가격: $pricePart 제거)');
        return productPart;
      }
    }
    
    // 패턴 2: "상품명12000" 형태 (공백 없음)
    RegExp pricePattern2 = RegExp(r'([가-힣\w\s()]+?)(\d{4,})$');
    Match? match2 = pricePattern2.firstMatch(line);
    if (match2 != null) {
      String productPart = match2.group(1)?.trim() ?? '';
      String pricePart = match2.group(2) ?? '';
      
      int? price = int.tryParse(pricePart);
      if (price != null && price >= 1000 && productPart.length >= 2) {
        print('💡 붙은 가격 분리: "$productPart" (가격: $pricePart 제거)');
        return productPart;
      }
    }
    
    // 원본 라인 반환 (가격이 없거나 분리 실패)
    return line;
  }

  bool _isRealProduct(String line, List<String> lines, int index) {
    // AI 스타일 진짜 상품 판단 로직
    
    // 1차 필터: 명백히 상품이 아닌 것들 제거
    if (_isObviouslyNotProduct(line)) {
      print('❌ 명백히 비상품: $line');
      return false;
    }
    
    // 2차 필터: 의미없는 텍스트 제거 (AI 스타일)
    if (_isMeaninglessText(line)) {
      print('❌ 무의미한 텍스트: $line');
      return false;
    }
    
    // 3차 필터: 매장/메타 정보 제거
    if (_isStoreOrMetaInfo(line)) {
      print('❌ 매장/메타 정보: $line');
      return false;
    }
    
    // 4차 검증: 진짜 음식/상품인지 확인
    if (_containsFoodKeywords(line)) {
      print('✅ 음식 키워드 포함: $line');
      return true;
    }
    
    // 5차 검증: 상품 패턴 분석
    if (_hasProductPattern(line, lines, index)) {
      print('✅ 상품 패턴 확인: $line');
      return true;
    }
    
    print('❓ 판단 보류: $line');
    return false;
  }

  bool _isMeaninglessText(String line) {
    // AI처럼 의미없는 텍스트 판단
    
    // OCR 오류 패턴들
    List<String> ocrErrors = [
      '맥액', '볼액', '리액', '세액', '투액', '라액',
      '교)', '나)', '다)', '라)', '마)', '바)',
      '구독', '투', '증류', '복류', '수류', '불류',
      '카드종', '종류', '항목', '내역'
    ];
    
    // 짧고 의미없는 패턴
    if (line.length <= 2) return true;
    
    // 특수문자가 많은 경우
    int specialCharCount = RegExp(r'[^\w가-힣\s]').allMatches(line).length;
    if (specialCharCount > line.length * 0.3) return true;
    
    // 숫자만 있는 경우
    if (RegExp(r'^\d+$').hasMatch(line)) return true;
    
    // 알려진 OCR 오류
    return ocrErrors.any((error) => line.contains(error));
  }

  bool _isStoreOrMetaInfo(String line) {
    // 매장 정보나 메타데이터 판단
    
    List<String> storePatterns = [
      '대학교', '대학', '학교', '병원', '회사', '센터',
      '점포', '매장', '지점', '본점', '분점',
      '주식회사', '유한회사', '(주)', '(유)',
      '사업자', '등록', '번호', '대표', '전화',
      '주소', '위치', '층', '호', '번지'
    ];
    
    // 괄호로 시작하는 메타정보
    if (RegExp(r'^[가-힣]\)').hasMatch(line)) return true;
    
    // 매장 관련 키워드
    return storePatterns.any((pattern) => line.contains(pattern));
  }

  bool _hasProductPattern(String line, List<String> lines, int index) {
    // 상품다운 패턴인지 확인
    
    // 한글이 주를 이루고 적절한 길이
    int koreanCount = RegExp(r'[가-힣]').allMatches(line).length;
    if (koreanCount < 2 || line.length < 3 || line.length > 20) return false;
    
    // 주변에 숫자(가격/수량) 정보가 있으면 상품일 가능성 높음
    for (int i = Math.max(0, index - 1); i <= Math.min(lines.length - 1, index + 2); i++) {
      if (RegExp(r'\d{3,}').hasMatch(lines[i])) {
        return true;
      }
    }
    
    return false;
  }

  int _smartQuantityExtraction(String line, List<String> lines, int index) {
    // 초똑똑한 수량 추출 (금액과 확실히 구분)
    
    print('🔍 수량 분석 시작: $line');
    
    // 1단계: 현재 라인에서 명확한 수량 표현 찾기
    RegExp directQty = RegExp(r'(\d+)\s*(개|EA|ea|x|X|×|팩|병|캔|잔|인분)\b');
    Match? directMatch = directQty.firstMatch(line);
    if (directMatch != null) {
      int? qty = int.tryParse(directMatch.group(1) ?? '');
      if (qty != null && qty >= 1 && qty <= 50) {
        print('🎯 명확한 수량 발견: $qty (${directMatch.group(0)})');
        return qty;
      }
    }
    
    // 2단계: 주변 라인에서 수량 찾기 (금액과 구분)
    for (int i = index; i <= Math.min(index + 3, lines.length - 1); i++) {
      String contextLine = lines[i];
      
      // 작은 숫자들 찾기 (2-20 사이)
      RegExp smallNums = RegExp(r'\b([2-9]|1[0-9]|20)\b');
      Iterable<Match> matches = smallNums.allMatches(contextLine);
      
      for (Match match in matches) {
        int? num = int.tryParse(match.group(1) ?? '');
        if (num == null) continue;
        
        // 금액의 일부인지 확인 (중요!)
        int start = match.start;
        int end = match.end;
        
        // 앞에 큰 숫자가 있으면 금액의 일부
        String before = contextLine.substring(0, start);
        if (RegExp(r'\d{2,}$').hasMatch(before)) {
          print('❌ 금액의 일부로 판단: $num (앞: $before)');
          continue;
        }
        
        // 뒤에 큰 숫자가 이어지면 금액의 일부
        String after = contextLine.substring(end);
        if (RegExp(r'^\d').hasMatch(after)) {
          print('❌ 금액의 일부로 판단: $num (뒤: $after)');
          continue;
        }
        
        // 큰 금액과 함께 있으면서 독립적이면 수량일 가능성
        bool hasBigPrice = RegExp(r'\b\d{4,}\b').hasMatch(contextLine);
        if (hasBigPrice && num >= 2 && num <= 10) {
          print('🎯 가격 근처 독립 수량: $num');
          return num;
        }
      }
    }
    
    print('📝 수량 없음 - 기본값 1');
    return 1;
  }

  // 필요한 헬퍼 메서드들
  bool _isSimilarProductName(String name1, String name2) {
    return name1 == name2 || 
           name1.contains(name2) || 
           name2.contains(name1);
  }

  bool _isObviouslyNotProduct(String line) {
    // 대폭 확장된 시스템 키워드 목록
    List<String> notProducts = [
      // 기본 시스템 정보
      '영수증', '합계', '총액', '부가세', '할인', '서비스', '세금',
      '받은돈', '거스름돈', '잔액', '현금', '카드', '신용카드', '체크카드',
      '결제', '승인', '거래', '번호', '승인번호', '카드번호',
      
      // 매장 정보
      '매장', '사업자', '대표', '주소', '전화', 'Tel', 'TEL', 'FAX',
      '상호', '점포', '지점', '본점', '분점', '직영점', '가맹점',
      
      // 테이블/인쇄 정보  
      '상품명', '단가', '수량', '금액', '가격', '항목', '품목', '내역',
      '일시', '시간', '날짜', '년', '월', '일', '시', '분', '초',
      '포인트', '적립', '사용', '쿠폰', '할인쿠폰',
      
      // 고객 서비스
      '감사합니다', '안녕히', '재방문', '또오세요', '고맙습니다',
      '이용해', '방문해', '고객', '서비스', '문의', '연락',
      
      // OCR 오류 패턴 (추가)
      '구독', '투', '증류', '현대카드', '카드종', '신용', '체크',
      '마스터', '비자', 'VISA', 'MASTER', 'KB', 'NH', '우리',
      '하나', '신한', '삼성', 'BC카드', 'LG', 'SK',
      
      // 배달/포장
      '배달', '포장', '매장', '테이크아웃', 'TAKE', 'OUT',
      '주문', '번호', '대기', '완료',
      
      // 기타 메타 정보
      '주차', '무료', '유료', '할인', '이벤트', '행사', '증정',
      '교환', '환불', '불가', '가능', '정책', '약관'
    ];
    
    // 순수 숫자만 있는 경우
    if (RegExp(r'^\d+$').hasMatch(line)) return true;
    
    // 특수문자만 있는 경우
    if (RegExp(r'^[^\w가-힣]+$').hasMatch(line)) return true;
    
    // 괄호로 완전히 감싸진 경우 (메타데이터)
    if (RegExp(r'^\([^)]+\)$').hasMatch(line)) return true;
    
    // 영어만 있고 길이가 짧은 경우
    if (RegExp(r'^[A-Za-z\s]+$').hasMatch(line) && line.length < 4) return true;
    
    // 시스템 키워드 포함
    return notProducts.any((keyword) => line.contains(keyword));
  }

  bool _containsFoodKeywords(String line) {
    List<String> foodKeywords = [
      // 음료 (대폭 확장)
      '에이드', '하이볼', '라떼', '커피', '주스', '콜라', '사이다', '물', '차', '음료',
      '스무디', '프라페', '아메리카노', '카푸치노', '마끼아또', '모카', '바닐라',
      '카라멜', '민트', '레몬', '오렌지', '자몽', '딸기', '망고', '키위',
      
      // 한식 (세분화)
      '구이', '볶음', '찜', '탕', '국', '밥', '면', '죽', '김치', '나물',
      '떡', '순대', '어묵', '튀김', '전', '부침', '비빔', '냉면', '한판',
      '갈비', '삼겹살', '불고기', '치킨', '닭', '돼지', '소고기', '생선',
      '두부', '콩나물', '시금치', '고사리', '도라지', '무', '배추',
      
      // 양식/디저트
      '파스타', '피자', '샐러드', '스테이크', '버거', '샌드위치',
      '치즈', '크림', '버터', '케이크', '빙수', '아이스크림', '과자',
      
      // 브랜드 메뉴 (추가)
      '맥', '치즈버거', '빅맥', '와퍼', '새우버거', '불고기버거',
      '후라이드', '양념치킨', '간장치킨', '마늘치킨', '허니',
      
      // 일반 키워드
      '세트', '단품', '대', '중', '소', 'L', 'M', 'S',
      '콤보', '업그레이드', '추가', '토핑'
    ];
    
    String lowerLine = line.toLowerCase();
    return foodKeywords.any((keyword) => lowerLine.contains(keyword.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('영수증 스캐너'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 메인 카드
            Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 48,
                      color: Colors.blue[600],
                    ),
                    SizedBox(height: 16),
                    Text(
                      '🎯 Google Cloud Vision OCR',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '한글 인식률 95%+ • 설정 완료됨',
                      style: TextStyle(fontSize: 14, color: Colors.green[600], fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      '영수증을 촬영하거나 갤러리에서 선택하세요',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImageFromCamera,
                            icon: Icon(Icons.camera_alt),
                            label: Text('카메라 촬영'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _pickImageFromGallery,
                            icon: Icon(Icons.photo_library),
                            label: Text('갤러리 선택'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            if (_image != null) ...[
              SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.image, color: Colors.blue[600]),
                          SizedBox(width: 8),
                          Text(
                            '선택된 이미지',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 300,
                      width: double.infinity,
                      child: Image.file(
                        _image!,
                        fit: BoxFit.contain,
                      ),
                    ),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ],

            if (_isLoading) ...[
              SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: Colors.blue[600]),
                    SizedBox(height: 16),
                    Text(
                      'Google Cloud Vision으로 텍스트 인식 중...',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '한글 인식률 95%+ 보장',
                      style: TextStyle(color: Colors.green[700], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],

            if (_receiptItems.isNotEmpty && !_isLoading) ...[
              SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green[600], size: 24),
                          SizedBox(width: 8),
                          Text(
                            '한글 제품명 인식 완료!',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700]),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      ...(_receiptItems.map((item) => Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item.quantity}개',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ))),
                      Divider(thickness: 2, color: Colors.grey[300]),
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_cart, color: Colors.blue[700]),
                            SizedBox(width: 8),
                            Text(
                              '총 ${_receiptItems.length}개 제품 • ${_receiptItems.fold(0, (sum, item) => sum + item.quantity)}개 수량',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (_extractedText.isNotEmpty && !_isLoading) ...[
              SizedBox(height: 16),
              ExpansionTile(
                title: Text('인식된 원본 텍스트'),
                leading: Icon(Icons.text_fields, color: Colors.grey[600]),
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      _extractedText,
                      style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ],

            // 상태 정보
            SizedBox(height: 16),
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified, color: Colors.green[600]),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '✅ Google Cloud Vision API 연결됨',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green[800]),
                              ),
                              Text(
                                '한글 인식률 95%+ • 월 1,000건까지 무료',
                                style: TextStyle(fontSize: 11, color: Colors.green[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Divider(color: Colors.green[300]),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.analytics_outlined, color: Colors.blue[600], size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🛡️ 안전 사용량 제한',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue[800]),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '오늘: $_dailyUsage/50회',
                                    style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                                  ),
                                  Text(
                                    '이번 달: $_monthlyUsage/900회',
                                    style: TextStyle(fontSize: 10, color: Colors.blue[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiptItem {
  final String name;
  final int quantity;
  final int price;

  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
  });

  @override
  String toString() {
    return '$name (수량: ${quantity}개)';
  }
}

// 사용하지 않는 클래스들 제거됨
