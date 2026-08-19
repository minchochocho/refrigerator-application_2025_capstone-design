import 'package:flutter/material.dart';

class TextUtils {
  // 안전한 텍스트 표시 (overflow 처리)
  static Widget safeText(
    String text, {
    TextStyle? style,
    int maxLines = 1,
    TextOverflow overflow = TextOverflow.ellipsis,
    TextAlign textAlign = TextAlign.left,
    bool softWrap = true,
  }) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
    );
  }

  // 제목용 텍스트 (1줄 제한)
  static Widget titleText(
    String text, {
    TextStyle? style,
    TextAlign textAlign = TextAlign.left,
  }) {
    return safeText(
      text,
      style: style ?? TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      maxLines: 1,
      textAlign: textAlign,
    );
  }

  // 부제목용 텍스트 (2줄 제한)
  static Widget subtitleText(
    String text, {
    TextStyle? style,
    TextAlign textAlign = TextAlign.left,
  }) {
    return safeText(
      text,
      style: style ?? TextStyle(
        fontSize: 14,
        color: Colors.grey[600],
      ),
      maxLines: 2,
      textAlign: textAlign,
    );
  }

  // 본문용 텍스트 (여러 줄 허용)
  static Widget bodyText(
    String text, {
    TextStyle? style,
    int maxLines = 3,
    TextAlign textAlign = TextAlign.left,
  }) {
    return safeText(
      text,
      style: style ?? TextStyle(
        fontSize: 14,
        height: 1.4,
      ),
      maxLines: maxLines,
      textAlign: textAlign,
    );
  }

  // 카드 내 텍스트 (컨테이너 크기에 맞춤)
  static Widget cardText(
    String text, {
    TextStyle? style,
    int maxLines = 2,
    TextAlign textAlign = TextAlign.left,
  }) {
    return safeText(
      text,
      style: style ?? TextStyle(
        fontSize: 12,
        color: Colors.grey[700],
      ),
      maxLines: maxLines,
      textAlign: textAlign,
    );
  }

  // 버튼 텍스트 (1줄 제한)
  static Widget buttonText(
    String text, {
    TextStyle? style,
    TextAlign textAlign = TextAlign.center,
  }) {
    return safeText(
      text,
      style: style ?? TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      maxLines: 1,
      textAlign: textAlign,
    );
  }

  // 라벨 텍스트 (1줄 제한)
  static Widget labelText(
    String text, {
    TextStyle? style,
    TextAlign textAlign = TextAlign.left,
  }) {
    return safeText(
      text,
      style: style ?? TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.grey[600],
      ),
      maxLines: 1,
      textAlign: textAlign,
    );
  }

  // 텍스트 길이 제한
  static String truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // 빈 텍스트 체크
  static bool isEmpty(String? text) {
    return text == null || text.trim().isEmpty;
  }

  // 안전한 텍스트 반환 (null 체크)
  static String safeString(String? text, {String defaultValue = ''}) {
    return text?.trim() ?? defaultValue;
  }
} 