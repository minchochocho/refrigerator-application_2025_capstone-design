/// Groq API 키는 빌드 시 dart-define으로 주입합니다.
/// 키를 앱에 포함하면 완전히 숨길 수 없으므로, 공개 배포에서는
/// Firebase Functions의 Secret Manager 프록시 사용을 권장합니다.
class GroqLocalConfig {
  /// 예: flutter run --dart-define=GROQ_API_KEY=gsk_...
  static const String apiKey = String.fromEnvironment('GROQ_API_KEY');
}


