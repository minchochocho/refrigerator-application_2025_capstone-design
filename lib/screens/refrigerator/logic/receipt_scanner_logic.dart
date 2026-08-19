import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:http/http.dart' as http;
import '../../../services/groq_client.dart';
import '../../../utils/receipt_parse_utils.dart';
import '../../../services/vision_config.dart';
import '../../../services/groq_local_config.dart';
import '../../../models/receipt_item.dart';

/// 영수증 스캔 관련 로직을 담당하는 클래스
class ReceiptScannerLogic {
  final GroqClient _groq = GroqClient();
  
  /// 이미지 소스로부터 영수증 스캔
  Future<Receipt?> handleReceiptPick(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return null;

      // Vision + Groq 파이프라인 사용
      return await parseReceiptViaVisionAndGroq(File(picked.path));
    } catch (e) {
      print('영수증 스캔 오류: $e');
      rethrow;
    }
  }
  
  /// Vision API + Groq를 사용한 영수증 파싱
  Future<Receipt> parseReceiptViaVisionAndGroq(File image) async {
    // 원본 이미지를 그대로 사용
    final base64Image = base64Encode(await image.readAsBytes());
    final resp = await http.post(
      Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=${VisionConfig.apiKey}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [{'type': 'TEXT_DETECTION', 'maxResults': 10}],
            'imageContext': {'languageHints': ['ko', 'en']}
          }
        ]
      }),
    );
    
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Vision 오류 ${resp.statusCode}');
    }
    
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final responses = data['responses'] as List?;
    final rawText = responses != null && responses.isNotEmpty
        ? (responses.first['textAnnotations'] != null
            ? responses.first['textAnnotations'][0]['description']?.toString() ?? ''
            : (responses.first['fullTextAnnotation']?['text']?.toString() ?? ''))
        : '';

    final basic = ReceiptParseUtils.parseItemsHeuristically(rawText);
    
    // 1) Groq legacy 프롬프트 기반 정제
    final legacy = await refineWithGroqLegacy(rawText, basic);
    
    // 2) GroqClient 보조 정제
    final refined = legacy.isNotEmpty ? legacy : await _groq.refineItems(ocrText: rawText, basicItems: basic);
    final used = refined.isNotEmpty ? refined : basic;
    
    return Receipt(
      id: 'vision_${DateTime.now().millisecondsSinceEpoch}',
      storeName: '',
      date: DateTime.now(),
      items: used,
    );
  }

  /// Groq를 사용한 영수증 항목 정제 (legacy 프롬프트)
  Future<List<ReceiptItem>> refineWithGroqLegacy(String ocrText, List<ReceiptItem> basicItems) async {
    final apiKey = GroqLocalConfig.apiKey;
    if (apiKey.isEmpty) return [];
    
    final prompt = '''영수증 OCR 텍스트를 분석해서 진짜 음식/상품만 정확히 추출해주세요.

=== OCR 원본 텍스트 ===
$ocrText

=== 현재 추출된 항목들 ===
${basicItems.map((e) => '${e.name} x ${e.quantity ?? 1}개').join('\n')}

=== 요청사항 ===
1. 위 항목들 중에서 진짜 음식/상품만 선별해주세요
2. 사업자번호, 전화번호, 매장정보, "상품명", "단가", "수량", "금액" 등 표의 헤더/타이틀/합계/할인/카드정보 등은 절대 포함하지 마세요
3. 수량도 정확히 파악해주세요 (주변 숫자 분석)
4. 결과는 아래 형식으로만 답변:
상품명1|수량1
상품명2|수량2
...''';
    
    final resp = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.1-8b-instant',
        'messages': [{'role': 'user', 'content': prompt}],
        'temperature': 0.3,
        'max_tokens': 1000,
      }),
    );
    
    if (resp.statusCode < 200 || resp.statusCode >= 300) return [];
    
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = data['choices']?[0]?['message']?['content']?.toString() ?? '';
    final lines = content.split('\n').map((e) => e.trim()).where((e) => e.contains('|')).toList();
    
    final out = <ReceiptItem>[];
    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length != 2) continue;
      final name = parts[0].trim();
      final qty = int.tryParse(parts[1].trim()) ?? 1;
      if (name.isEmpty || qty <= 0) continue;
      out.add(ReceiptItem(name: name, quantity: qty));
    }
    return out;
  }

  /// 로컬 OCR을 사용한 영수증 파싱
  Future<Receipt> parseReceiptLocally(File image) async {
    final pre = await ReceiptParseUtils.enhanceImageForOcr(image);
    final input = InputImage.fromFile(pre);
    TextRecognizer recognizer;
    
    try {
      recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    } catch (_) {
      recognizer = TextRecognizer();
    }
    
    try {
      final rt = await recognizer.processImage(input);
      final items = ReceiptParseUtils.parseItemsHeuristically(rt.text);
      
      // Groq 정제 (키가 설정된 경우에만 작동)
      final refined = await _groq.refineItems(ocrText: rt.text, basicItems: items);
      final used = refined.isNotEmpty ? refined : items;
      
      return Receipt(
        id: 'local_${DateTime.now().millisecondsSinceEpoch}',
        storeName: '',
        date: DateTime.now(),
        items: used,
      );
    } finally {
      await recognizer.close();
    }
  }
}

