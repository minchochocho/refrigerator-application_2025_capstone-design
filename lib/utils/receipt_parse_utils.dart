import 'dart:io';

import 'package:image/image.dart' as img;
import '../models/receipt_item.dart';

class ReceiptParseUtils {
  /// 간단한 전처리: 그레이스케일 + 대비/명암 보정 후 저장
  static Future<File> enhanceImageForOcr(File source) async {
    try {
      final bytes = await source.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) return source;
      var gray = img.grayscale(original);
      gray = img.adjustColor(gray, contrast: 1.2, brightness: 0.05);
      final outBytes = img.encodeJpg(gray, quality: 95);
      return source.writeAsBytes(outBytes);
    } catch (_) {
      return source;
    }
  }

  /// OCR 텍스트에서 상품 항목을 휴리스틱으로 추출
  static List<ReceiptItem> parseItemsHeuristically(String rawText) {
    final text = _normalizeText(rawText);
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final List<ReceiptItem> items = [];

    bool isMeta(String line) {
      const meta = [
        '합계','총액','부가세','할인','카드','현금','승인','거래','사업자','주소','전화','tel','fax',
        '상품명','단가','수량','금액','항목','내역','일시','시간','날짜','포인트','적립','쿠폰',
        '영수증','감사','재방문','고객','서비스','문의','교환','환불','불가','가능',
      ];
      if (RegExp(r'^\d+$').hasMatch(line)) return true;
      return meta.any((k) => line.toLowerCase().contains(k.toLowerCase()));
    }

    bool looksLikeProduct(String line) {
      if (line.length < 2 || line.length > 40) return false;
      // 문자(한글/영문)가 1개 이상 포함되어야 함
      final hasLetters = RegExp(r'[가-힣A-Za-z]').hasMatch(line);
      if (!hasLetters) return false;
      // 숫자 과다(90% 이상)가 아니면 허용 → 가격·수량이 함께 있어도 통과
      final digits = RegExp(r'\d').allMatches(line).length;
      if (digits / line.length > 0.9) return false;
      return true;
    }

    int? _scanNearbyQty(int centerIndex) {
      // 현재/다음 3줄에서 소량 숫자 추출(금액과 구분)
      for (int i = centerIndex; i <= (centerIndex + 3).clamp(0, lines.length - 1); i++) {
        final s = lines[i];
        final direct = RegExp(r'(\d{1,2})\s*(개|ea|EA|x|X|×|팩|병|캔|잔|인분)\b');
        final m = direct.firstMatch(s);
        if (m != null) {
          final q = int.tryParse(m.group(1)!);
          if (q != null && q > 0 && q <= 50) return q;
        }
        // 독립 소량(금액과 분리)
        for (final mm in RegExp(r'\b([2-9]|1[0-9]|20)\b').allMatches(s)) {
          final before = s.substring(0, mm.start);
          final after = s.substring(mm.end);
          if (RegExp(r'\d{2,}$').hasMatch(before)) continue; // 금액 일부
          if (RegExp(r'^\d').hasMatch(after)) continue; // 금액 일부
          return int.tryParse(mm.group(1)!);
        }
      }
      return null;
    }

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (isMeta(line)) continue;

      // 패턴0(테이블형): "상품명  3,800  1  3,800" (단가,수량,금액 순)
      // 천 단위 구분자 콤마/닷 모두 허용, 통화 기호/원 제거 허용
      // 콤마 뒤에 공백이 OCR로 들어오는 경우 허용 (예: 3, 800)
      final table = RegExp(r'^(.+?)\s+(\d{1,3}(?:[,.]\s*\d{3})+)\s+(\d{1,2})\s+(\d{1,3}(?:[,.]\s*\d{3})+)\s*(?:원|KRW|₩)?$');
      final t = table.firstMatch(line);
      if (t != null) {
        final name = t.group(1)!.trim();
        final qty = int.tryParse(t.group(3)!);
        if (name.isNotEmpty && qty != null) {
          items.add(ReceiptItem(name: name, quantity: qty));
          continue;
        }
      }

      // 붙은 가격 분리: "상품명12000"
      final glued = RegExp(r'([가-힣A-Za-z0-9_\-\s()]+?)(\d{4,})$');
      final gluedM = glued.firstMatch(line);
      if (gluedM != null) {
        line = gluedM.group(1)!.trim();
      }

      // 패턴1: "상품명 2 3000"
      final m1 = RegExp(r'^(.+?)\s+(\d{1,2})\s+(\d{3,}(?:[,.]\d{3})*)\s*(?:원|KRW|₩)?$').firstMatch(line);
      if (m1 != null) {
        final name = m1.group(1)!.trim();
        final qty = int.tryParse(m1.group(2)!) ?? 1;
        final price = double.tryParse(m1.group(3)!.replaceAll(',', ''));
        if (name.isNotEmpty) {
          items.add(ReceiptItem(name: name, quantity: qty, price: price));
          continue;
        }
      }

      // 패턴2: "상품명 x2" or "상품명 2개"
      final m2 = RegExp(r'^(.+?)\s*(?:x|X|×)?\s*(\d{1,2})\s*(?:개|EA|ea)?$').firstMatch(line);
      if (m2 != null && !RegExp(r'\d{4,}').hasMatch(line)) {
        final name = m2.group(1)!.trim();
        final qty = int.tryParse(m2.group(2)!) ?? 1;
        if (name.isNotEmpty && looksLikeProduct(name)) {
          items.add(ReceiptItem(name: name, quantity: qty));
          continue;
        }
      }

      // 패턴3: "상품명 3000"
      final m3 = RegExp(r'^(.+?)\s+(\d{3,}(?:[,.]\d{3})*)\s*(?:원|KRW|₩)?$').firstMatch(line);
      if (m3 != null) {
        final name = m3.group(1)!.trim();
        final price = double.tryParse(m3.group(2)!.replaceAll(',', ''));
        if (name.isNotEmpty && looksLikeProduct(name)) {
          items.add(ReceiptItem(name: name, quantity: 1, price: price));
          continue;
        }
      }

      // 다음 줄에 금액만 있는 경우: "상품명" + "3000"
      if (i + 1 < lines.length && RegExp(r'^\d{3,}(?:[,.]\d{3})*\s*(?:원|KRW|₩)?$').hasMatch(lines[i + 1])) {
        final name = line.trim();
        if (looksLikeProduct(name) && !isMeta(name)) {
          items.add(ReceiptItem(name: name, quantity: _scanNearbyQty(i) ?? 1));
          continue;
        }
      }

      // 키워드 기반 후보
      if (looksLikeProduct(line)) {
        items.add(ReceiptItem(name: line, quantity: _scanNearbyQty(i) ?? 1));
      }
    }

    // 중복 제거
    final seen = <String>{};
    var dedup = <ReceiptItem>[];
    for (final it in items) {
      if (seen.add(it.name)) dedup.add(it);
    }

    // 완화형 폴백: 아무 것도 못 찾았을 때 느슨한 규칙으로 재시도
    if (dedup.isEmpty) {
      for (final raw in lines) {
        if (isMeta(raw)) continue;
        if (!looksLikeProduct(raw)) continue;
        // 뒤쪽 숫자·통화표시 제거 후 이름만 추출
        final name = raw.replaceAll(RegExp(r'[\s]+\d[0-9,\.\s]*(?:원|KRW|₩)?$'), '').trim();
        if (name.length < 2) continue;
        // 수량 후보 탐색
        final q1 = RegExp(r'(\d{1,2})\s*(개|EA|ea)\b').firstMatch(raw)?.group(1);
        final q2 = RegExp(r'(?:x|X|×)\s*(\d{1,2})').firstMatch(raw)?.group(1);
        final qty = int.tryParse(q1 ?? q2 ?? '') ?? 1;
        if (seen.add(name)) dedup.add(ReceiptItem(name: name, quantity: qty));
      }
    }

    return dedup;
  }

  static String _normalizeText(String input) {
    var s = input.replaceAll('\r', '');
    // 전각 숫자/기호를 반각으로 단순 치환
    const full = '０１２３４５６７８９ｘＸ';
    const half = '0123456789xX';
    for (int i = 0; i < full.length; i++) {
      s = s.replaceAll(full[i], half[i % half.length]);
    }
    // 연속 공백 정리
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }
}


