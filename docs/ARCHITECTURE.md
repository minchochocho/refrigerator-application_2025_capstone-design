# 냉장고 관리 앱 시스템 아키텍처

## 시스템 개요

이 문서는 냉장고 관리 모바일 애플리케이션의 전체 시스템 아키텍처를 설명합니다.

## 기술 스택

### 개발 환경

- 개발 언어: Dart
- 프레임워크: Flutter
- 개발도구: Android Studio
- 백엔드: Firebase (Firestore Database, Authentication)
- 테스트 환경: Android Emulator

### 주요 라이브러리

- mobile_scanner: 바코드 인식
- google_ml_kit: 텍스트 인식 (OCR)
- SerpAPI: 제품 정보 검색

## 시스템 구조

### Frontend (Mobile Application)

#### UI 컴포넌트

- 인증 화면 (Authentication Screens)
  - 로그인
  - 회원가입
  - 프로필 관리
- 스캐너 인터페이스 (Scanner Interface)
  - 바코드 스캔
  - 텍스트 인식
- 제품 관리 (Product Management)
  - 제품 목록
  - 상세 정보
  - 유통기한 관리

#### 핵심 서비스

- 바코드 스캔 서비스
  - 실시간 카메라 처리
  - 바코드 디코딩
- OCR 서비스
  - 텍스트 감지
  - 텍스트 인식
- 제품 정보 서비스
  - API 통신
  - 데이터 파싱

### Backend (Firebase)

#### Authentication

- 이메일/비밀번호 인증
- Google 로그인
- 게스트 접근

#### Firestore Database

- Users Collection
  - 사용자 정보
  - 설정 데이터
- Products Collection
  - 바코드 데이터
  - 제품 정보
- Expiry Collection
  - 유통기한 데이터
  - 알림 설정

### External Services

#### mobile_scanner

- 기능: 바코드 및 QR 코드 인식
- 용도: 제품 바코드 스캔

#### google_ml_kit

- 기능: 텍스트 인식
- 용도: 유통기한 텍스트 추출

#### SerpAPI

- 기능: 제품 정보 검색
- 용도: 바코드 기반 제품 정보 조회

## 데이터 흐름

1. 사용자 인증

   ```
   사용자 → 인증 요청 → Firebase Auth → 인증 토큰 → 앱
   ```

2. 제품 등록

   ```
   바코드 스캔 → 제품 정보 검색 → Firestore 저장
   ```

3. 유통기한 관리
   ```
   텍스트 인식 → 날짜 추출 → Firestore 저장 → 알림 설정
   ```

## 보안

- Firebase 보안 규칙 적용
- 사용자 인증 토큰 관리
- API 키 보안 처리

## 확장성

시스템은 다음과 같은 확장을 고려하여 설계되었습니다:

1. 새로운 인증 방식 추가
2. 추가 제품 정보 API 통합
3. 고급 분석 기능 도입
4. 다국어 지원

## 모니터링 및 로깅

- Firebase Analytics 통합
- 사용자 행동 추적
- 오류 모니터링
- 성능 메트릭스 수집
