import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/receipt_item.dart';
import 'groq_local_config.dart';

class GroqClient {
  final String apiKey;
  GroqClient({String? apiKey}) : apiKey = apiKey ?? GroqLocalConfig.apiKey;

  bool get isConfigured => apiKey.isNotEmpty;

  Future<List<ReceiptItem>> refineItems({required String ocrText, required List<ReceiptItem> basicItems}) async {
    if (!isConfigured) return basicItems;
    final prompt = _buildPrompt(ocrText, basicItems);
    final resp = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'llama-3.1-8b-instant',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.2,
        'max_tokens': 800,
      }),
    );

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final content = data['choices']?[0]?['message']?['content']?.toString() ?? '';
      // 우선 JSON 파싱 시도
      final refinedRaw = _parseGroqJson(content).isNotEmpty
          ? _parseGroqJson(content)
          : _parseGroq(content);
      // LLM 환각 방지: OCR 텍스트에 실제로 존재하는 이름만 허용
      final refined = _filterByPresenceInText(ocrText, refinedRaw);
      return refined.isNotEmpty ? refined : basicItems;
    }
    return basicItems;
  }

  String _buildPrompt(String ocrText, List<ReceiptItem> basic) {
    final lines = basic.map((e) => '${e.name}|${e.quantity ?? 1}').join('\n');
    return '''다음은 영수증 OCR 텍스트입니다. 실제 텍스트에 존재하는 상품명과 수량만 추출해 주세요.

규칙:
- OCR 텍스트에 존재하지 않는 항목은 절대 만들지 마세요(환각 금지)
- 표 헤더/합계/결제/매장/연락처/와이파이/문구 등 비상품은 제외
- 수량이 불명확하면 1로 하되 상품명이 불확실하면 제외
- 출력은 반드시 JSON 배열만, 다른 텍스트 금지
- 스키마: [{"name": string, "quantity": number}]

=== OCR 원본 텍스트 ===
$ocrText

=== 휴리스틱 추출(참고용) ===
$lines
''';
  }

  List<ReceiptItem> _parseGroq(String text) {
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty && e.contains('|')).toList();
    final out = <ReceiptItem>[];
    for (final line in lines) {
      final parts = line.split('|');
      if (parts.length != 2) continue;
      final name = parts[0].trim();
      final qty = int.tryParse(parts[1].trim()) ?? 1;
      if (name.isEmpty) continue;
      out.add(ReceiptItem(name: name, quantity: qty));
    }
    return out;
  }

  List<ReceiptItem> _parseGroqJson(String content) {
    try {
      // JSON 본문만 추출
      final start = content.indexOf('[');
      final end = content.lastIndexOf(']');
      if (start == -1 || end == -1 || end <= start) return const [];
      final jsonSlice = content.substring(start, end + 1);
      final list = jsonDecode(jsonSlice) as List<dynamic>;
      final out = <ReceiptItem>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) {
          final name = (e['name'] ?? '').toString().trim();
          final qty = (e['quantity'] is num) ? (e['quantity'] as num).toInt() : int.tryParse('${e['quantity']}') ?? 1;
          if (name.isEmpty) continue;
          out.add(ReceiptItem(name: name, quantity: qty));
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  List<ReceiptItem> _filterByPresenceInText(String ocrText, List<ReceiptItem> candidates) {
    final normText = _normalize(ocrText);
    bool exists(String name) {
      final n = _normalize(name);
      if (n.isEmpty) return false;
      // 직접 포함 또는 토큰 교집합 확인
      if (normText.contains(n)) return true;
      final tokens = n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      final hit = tokens.where((t) => normText.contains(t)).length;
      return tokens.isNotEmpty && hit / tokens.length >= 0.8; // 80% 이상 일치 시 허용
    }
    final filtered = <ReceiptItem>[];
    for (final it in candidates) {
      if (exists(it.name)) filtered.add(it);
    }
    return filtered;
  }

  String _normalize(String s) {
    var out = s.toLowerCase();
    out = out.replaceAll(RegExp(r'[^a-z0-9가-힣\s]'), '');
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out.trim();
  }
}


