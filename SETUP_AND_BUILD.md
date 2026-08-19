# 프로젝트 설정 및 빌드 가이드

> Public GitHub 저장소에는 실제 API Key 및 Secret을 포함하지 않습니다.  
> 이 문서는 저장소를 내려받은 뒤 필요한 설정값을 구성하고 Flutter 애플리케이션을 실행·빌드하는 방법을 정리합니다.

## 1. 개발 환경 준비

다음 환경이 필요합니다.

- Flutter SDK
- Android Studio 또는 VS Code
- Android SDK
- Android Emulator 또는 실제 Android 기기
- Firebase 프로젝트 설정
- 외부 API Key
  - SerpAPI
  - Groq API
  - Google Cloud Vision API

설치 상태는 다음 명령어로 확인할 수 있습니다.

```bash
flutter doctor
```

표시되는 오류가 있다면 Android SDK, 라이선스, 연결 기기 등의 설정을 먼저 완료합니다.

---

## 2. 프로젝트 다운로드

```bash
git clone [저장소 URL]
cd refrigerator-food-management-app
```

Flutter 패키지를 설치합니다.

```bash
flutter pub get
```

---

## 3. API Key 준비

이 프로젝트에서는 다음 환경변수를 사용합니다.

| 환경변수 | 용도 |
| --- | --- |
| `SERP_API_KEY` | 바코드 번호 기반 상품명·이미지 검색 |
| `GROQ_API_KEY` | 영수증 OCR 결과 보완 및 정제 |
| `GOOGLE_VISION_API_KEY` | 영수증 이미지 문자 인식 |

실제 API Key는 저장소에 포함하지 않습니다.

프로젝트 루트의 `.env.example`은 필요한 환경변수 이름을 확인하기 위한 참고용 파일입니다.

```text
SERP_API_KEY=your_serpapi_api_key
GROQ_API_KEY=your_groq_api_key
GOOGLE_VISION_API_KEY=your_google_vision_api_key
```

> 현재 Flutter 애플리케이션은 `.env` 파일을 자동으로 읽지 않습니다.  
> API Key는 실행 또는 빌드 시 `--dart-define`으로 전달합니다.

---

## 4. Flutter 애플리케이션 실행

### Windows PowerShell

```powershell
flutter run `
  --dart-define=SERP_API_KEY="YOUR_SERP_API_KEY" `
  --dart-define=GROQ_API_KEY="YOUR_GROQ_API_KEY" `
  --dart-define=GOOGLE_VISION_API_KEY="YOUR_GOOGLE_VISION_API_KEY"
```

### Windows CMD

```cmd
flutter run --dart-define=SERP_API_KEY=YOUR_SERP_API_KEY --dart-define=GROQ_API_KEY=YOUR_GROQ_API_KEY --dart-define=GOOGLE_VISION_API_KEY=YOUR_GOOGLE_VISION_API_KEY
```

### Linux / macOS

```bash
flutter run \
  --dart-define=SERP_API_KEY=YOUR_SERP_API_KEY \
  --dart-define=GROQ_API_KEY=YOUR_GROQ_API_KEY \
  --dart-define=GOOGLE_VISION_API_KEY=YOUR_GOOGLE_VISION_API_KEY
```

API Key가 전달되지 않으면 해당 외부 API를 사용하는 기능이 정상 동작하지 않을 수 있습니다.

---

## 5. Firebase 설정

Flutter 애플리케이션은 Firebase Authentication, Cloud Firestore, Cloud Storage를 사용합니다.

저장소에는 Firebase 클라이언트 설정에 필요한 다음 파일이 포함될 수 있습니다.

```text
android/app/google-services.json
lib/firebase_options.dart
firebase.json
firestore.rules
firestore.indexes.json
```

Firebase 프로젝트를 새로 구성하는 경우에는 자신의 Firebase 프로젝트 설정에 맞게 파일을 다시 생성하거나 교체해야 합니다.

### Firestore Index 적용

필요한 경우 Firebase CLI 로그인 후 인덱스를 배포합니다.

```bash
firebase login
firebase use [FIREBASE_PROJECT_ID]
firebase deploy --only firestore:indexes
```

### Firestore Rules 적용

```bash
firebase deploy --only firestore:rules
```

> 실제 운영 환경에서는 Firestore 및 Storage 접근 권한을 별도로 검토해야 합니다.

---

## 6. Firebase Functions 참고

저장소에는 Functions 구현 예시인 `functions/index.js`와 관련 패키지 파일이 포함되어 있습니다.
`parseReceipt` 함수와 Firebase Secret Manager용 `GROQ_API_KEY` 설정도 해당 파일에 존재합니다.

다만 현재 Flutter 앱의 영수증 처리 흐름은 Firebase Functions를 호출하지 않고,
Google Vision API와 Groq API를 클라이언트에서 직접 호출합니다.
따라서 Firebase Functions 설정 및 배포는 현재 앱 실행에 필수인 단계가 아닙니다.

현재 `firebase.json`에는 Functions source 설정도 포함되어 있지 않으므로,
이 문서에서는 Functions 설치·Secret 등록·배포 명령을 필수 실행 절차로 안내하지 않습니다.
Functions를 실제 앱 실행 경로로 사용할 때는 별도의 배포 설정과 호출 연동을 먼저 구성해야 합니다.

---

## 7. 실행 전 점검

프로젝트 실행 전 다음 명령어를 권장합니다.

```bash
flutter clean
flutter pub get
flutter analyze
```

연결된 기기를 확인하려면 다음 명령어를 사용합니다.

```bash
flutter devices
```

---

# Android 빌드

## 8. Debug APK 빌드

개발 및 테스트용 APK를 생성합니다.

### Windows PowerShell

```powershell
flutter build apk --debug `
  --dart-define=SERP_API_KEY="YOUR_SERP_API_KEY" `
  --dart-define=GROQ_API_KEY="YOUR_GROQ_API_KEY" `
  --dart-define=GOOGLE_VISION_API_KEY="YOUR_GOOGLE_VISION_API_KEY"
```

### Windows CMD

```cmd
flutter build apk --debug --dart-define=SERP_API_KEY=YOUR_SERP_API_KEY --dart-define=GROQ_API_KEY=YOUR_GROQ_API_KEY --dart-define=GOOGLE_VISION_API_KEY=YOUR_GOOGLE_VISION_API_KEY
```

빌드 결과는 일반적으로 다음 경로에 생성됩니다.

```text
build/app/outputs/flutter-apk/app-debug.apk
```

---

## 9. Release APK 빌드

배포용 APK를 생성합니다.

### Windows PowerShell

```powershell
flutter build apk --release `
  --dart-define=SERP_API_KEY="YOUR_SERP_API_KEY" `
  --dart-define=GROQ_API_KEY="YOUR_GROQ_API_KEY" `
  --dart-define=GOOGLE_VISION_API_KEY="YOUR_GOOGLE_VISION_API_KEY"
```

### Windows CMD

```cmd
flutter build apk --release --dart-define=SERP_API_KEY=YOUR_SERP_API_KEY --dart-define=GROQ_API_KEY=YOUR_GROQ_API_KEY --dart-define=GOOGLE_VISION_API_KEY=YOUR_GOOGLE_VISION_API_KEY
```

빌드 결과:

```text
build/app/outputs/flutter-apk/app-release.apk
```

> 실제 스토어 배포용 Release APK/AAB를 만들려면 Android 앱 서명 설정이 추가로 필요할 수 있습니다.

---

## 10. Android App Bundle(AAB) 빌드

Google Play 배포용 App Bundle을 생성할 경우 사용합니다.

### Windows PowerShell

```powershell
flutter build appbundle --release `
  --dart-define=SERP_API_KEY="YOUR_SERP_API_KEY" `
  --dart-define=GROQ_API_KEY="YOUR_GROQ_API_KEY" `
  --dart-define=GOOGLE_VISION_API_KEY="YOUR_GOOGLE_VISION_API_KEY"
```

### Windows CMD

```cmd
flutter build appbundle --release --dart-define=SERP_API_KEY=YOUR_SERP_API_KEY --dart-define=GROQ_API_KEY=YOUR_GROQ_API_KEY --dart-define=GOOGLE_VISION_API_KEY=YOUR_GOOGLE_VISION_API_KEY
```

빌드 결과:

```text
build/app/outputs/bundle/release/app-release.aab
```

---

## 11. 실제 기기에 APK 설치

연결된 Android 기기에 APK를 설치하려면 다음과 같이 실행할 수 있습니다.

```bash
flutter install
```

또는 생성된 APK 파일을 실제 Android 기기로 옮겨 직접 설치할 수 있습니다.

---

# 보안 주의사항

## 12. Git에 포함하면 안 되는 파일

다음과 같은 실제 Secret 및 인증 파일은 Public GitHub 저장소에 올리지 않습니다.

```text
.env
.env.*
local.properties
key.properties
*.jks
*.keystore
*.p12
*.pfx
*.pem
Service Account JSON
Credential JSON
```

단, 실제 값이 없는 `.env.example`은 공개 저장소에 포함할 수 있습니다.

---

## 13. API Key를 코드에 직접 작성하지 않기

다음과 같은 형태로 실제 API Key를 코드에 작성하지 않습니다.

```dart
const apiKey = 'REAL_API_KEY';
```

이 프로젝트에서는 다음과 같이 환경값을 읽습니다.

```dart
const apiKey = String.fromEnvironment('SERP_API_KEY');
```

실제 값은 실행 및 빌드 명령의 `--dart-define`을 통해 전달합니다.

---

## 14. API Key가 노출된 경우

이미 GitHub, 협업 저장소, 문서 등에 실제 API Key가 노출된 적이 있다면 코드에서 삭제하는 것만으로는 충분하지 않습니다.

해당 서비스에서 기존 Key를 폐기하고 새 Key를 발급합니다.

점검 대상:

- Groq API Key
- SerpAPI Key
- Google Cloud Vision API Key

Firebase 클라이언트 설정값은 일반적인 Secret과 성격이 다르지만, Google Cloud Console 및 Firebase에서 API 제한과 접근 권한을 확인합니다.

---

# 빠른 실행 순서

처음 프로젝트를 실행할 때는 다음 순서로 진행합니다.

```text
1. Flutter 및 Android 개발 환경 설치
2. 프로젝트 Clone
3. flutter pub get
4. Firebase 설정 확인
5. SerpAPI / Groq / Google Vision API Key 준비
6. --dart-define으로 API Key를 전달하여 flutter run
7. flutter analyze로 코드 점검
8. flutter build apk 또는 flutter build appbundle로 빌드
```

> Public 저장소에는 실제 Secret을 저장하지 않고, 실행하는 개발자가 자신의 환경에서 직접 설정하도록 구성합니다.
