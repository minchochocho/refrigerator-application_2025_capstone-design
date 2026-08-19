import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import '../firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:crypto/crypto.dart';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final String _projectId = DefaultFirebaseOptions.currentPlatform.projectId;

  Reference _primaryRoot() {
    // 기본 초기화된 버킷의 루트
    return _storage.ref();
  }

  Reference _fallbackRoot() {
    // GCS 표준 버킷 (gs://<project-id>.appspot.com)로 강제
    final gs = 'gs://' + _projectId + '.appspot.com';
    return _storage.refFromURL(gs);
  }

  Future<String?> _uploadToStorage(String path, Uint8List bytes, SettableMetadata metadata) async {
    print('Storage 업로드 시작 - 경로: $path, 크기: ${bytes.length}B');
    
    // 먼저 기본 버킷 정보 확인
    try {
      final bucketName = _storage.bucket;
      print('🪣 사용 중인 버킷: $bucketName');
    } catch (e) {
      print('버킷 정보 확인 실패: $e');
    }
    
    // 단순한 1회 업로드 시도 (복잡한 재시도 제거)
    try {
      print('단순 업로드 시도...');
      
      // 가장 기본적인 참조 생성
      final ref = _storage.ref(path);
      
      print('📍 참조 경로: ${ref.fullPath}');
      print('🌐 참조 버킷: ${ref.bucket}');
      
      // 가장 간단한 업로드 (메타데이터 최소화)
      final uploadTask = ref.putData(bytes, metadata);
      
      // 업로드 완료 대기 (진행률 모니터링 제거)
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('단순 업로드 성공: $downloadUrl');
      return downloadUrl;
      
    } catch (e, stackTrace) {
      print('❌ 단순 업로드 실패: $e');
      print('📜 상세 오류: ${e.toString()}');
      
      // 대안: 다른 경로로 시도
      try {
        print('대안 경로로 재시도...');
        final alternativePath = 'temp/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final altRef = _storage.ref(alternativePath);
        
        final altUploadTask = altRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        final altSnapshot = await altUploadTask;
        final altDownloadUrl = await altSnapshot.ref.getDownloadURL();
        
        print('대안 경로 업로드 성공: $altDownloadUrl');
        return altDownloadUrl;
        
      } catch (altError) {
        print('❌ 대안 경로도 실패: $altError');
        return null;
      }
    }
  }
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // 자동 압축 설정 (고정값)
  static const int _maxImageWidth = 800;    // 최대 너비 800px
  static const int _maxImageHeight = 600;   // 최대 높이 600px
  static const int _jpegQuality = 70;       // JPEG 품질 70%
  static const int _maxFileSizeKB = 500;    // 최대 파일 크기 500KB

  /// Storage 경로 세그먼트에 사용할 안전한 문자열로 변환
  String _sanitizePathSegment(String input) {
    // 영숫자, 점, 밑줄, 대시만 허용. 그 외 문자는 모두 '_'
    return input.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  /// 이미지 해시 생성 (중복 검사용)
  Future<String> _generateImageHash(Uint8List imageBytes) async {
    final digest = sha256.convert(imageBytes);
    return digest.toString();
  }

  /// 자동 이미지 압축 및 리사이징
  Future<Uint8List?> _compressImage(File imageFile) async {
    try {
      final originalBytes = await imageFile.readAsBytes();
      final originalSizeKB = originalBytes.length / 1024;
      
      final image = img.decodeImage(originalBytes);
      if (image == null) {
        print('❌ 이미지 디코딩 실패');
        return null;
      }

      print('📏 원본 크기: ${image.width}x${image.height} (${originalSizeKB.toStringAsFixed(1)}KB)');

      // 1단계: 크기 조정 (스마트 리사이징)
      img.Image resizedImage = image;
      if (image.width > _maxImageWidth || image.height > _maxImageHeight) {
        // 가로/세로 비율에 따라 더 효율적으로 리사이징
        final aspectRatio = image.width / image.height;
        int newWidth, newHeight;
        
        if (aspectRatio > 1) {
          // 가로가 더 긴 경우
          newWidth = _maxImageWidth;
          newHeight = (_maxImageWidth / aspectRatio).round();
          if (newHeight > _maxImageHeight) {
            newHeight = _maxImageHeight;
            newWidth = (_maxImageHeight * aspectRatio).round();
          }
        } else {
          // 세로가 더 긴 경우
          newHeight = _maxImageHeight;
          newWidth = (_maxImageHeight * aspectRatio).round();
          if (newWidth > _maxImageWidth) {
            newWidth = _maxImageWidth;
            newHeight = (_maxImageWidth / aspectRatio).round();
          }
        }
        
        resizedImage = img.copyResize(image, width: newWidth, height: newHeight);
        print('📐 리사이징: ${image.width}x${image.height} → ${newWidth}x${newHeight}');
      }

      // 2단계: 이미지 최적화 (선명도 향상)
      resizedImage = img.adjustColor(resizedImage, 
        saturation: 1.1,  // 채도 약간 증가
        contrast: 1.05    // 대비 약간 증가
      );

      // 3단계: JPEG 압축
      var compressedBytes = img.encodeJpg(resizedImage, quality: _jpegQuality);
      var compressedSizeKB = compressedBytes.length / 1024;
      
      print('1차 압축: ${originalSizeKB.toStringAsFixed(1)}KB → ${compressedSizeKB.toStringAsFixed(1)}KB');

      // 4단계: 목표 크기에 맞춰 추가 압축
      var currentQuality = _jpegQuality;
      var attempts = 0;
      while (compressedBytes.length > _maxFileSizeKB * 1024 && currentQuality > 20 && attempts < 5) {
        currentQuality -= 10;
        compressedBytes = img.encodeJpg(resizedImage, quality: currentQuality);
        compressedSizeKB = compressedBytes.length / 1024;
        attempts++;
        print('추가 압축 ${attempts}회: 품질 ${currentQuality}% → ${compressedSizeKB.toStringAsFixed(1)}KB');
      }

      // 5단계: 극한 압축이 필요한 경우 크기 추가 조정
      if (compressedBytes.length > _maxFileSizeKB * 1024 && attempts >= 5) {
        final scaleFactor = 0.8;
        final ultraCompressedImage = img.copyResize(
          resizedImage,
          width: (resizedImage.width * scaleFactor).round(),
          height: (resizedImage.height * scaleFactor).round()
        );
        compressedBytes = img.encodeJpg(ultraCompressedImage, quality: 40);
        compressedSizeKB = compressedBytes.length / 1024;
        print('극한 압축: 크기 80% 축소 → ${compressedSizeKB.toStringAsFixed(1)}KB');
      }

      // 결과 리포트
      final compressionRatio = ((originalSizeKB - compressedSizeKB) / originalSizeKB * 100);
      print('이미지 압축 완료: ${compressionRatio.toStringAsFixed(1)}% 압축 (${compressedSizeKB.toStringAsFixed(1)}KB)');

      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      print('❌ 이미지 압축 실패: $e');
      return null;
    }
  }

  /// 중복 이미지 확인
  Future<String?> _checkDuplicateImage(String imageHash, String roomId, String refrigeratorName) async {
    try {
      // 리스트 API가 404를 유발하는 환경이 있어, 중복 검사는 임시 비활성화
      // 필요 시 서버 사이드로 이전 권장
      
      return null; // 중복 없음
    } catch (e) {
      print('중복 확인 실패, 새로 업로드: $e');
      return null;
    }
  }

  /// 이미지를 Base64로 인코딩하여 data URL 반환 (Firebase Storage 우회)
  Future<String?> uploadIngredientImage(File imageFile, String roomId, String refrigeratorName, int compartmentIndex) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      print('📱 Base64 인코딩으로 이미지 처리 시작 (Storage 우회)');

      // 1. 이미지 압축 (더 작게 - Firestore 1MB 제한 고려)
      final compressedBytes = await _compressImageForFirestore(imageFile);
      if (compressedBytes == null) {
        throw Exception('이미지 압축 실패');
      }

      print('압축된 파일 크기: ${compressedBytes.length} bytes');

      // 2. Base64 인코딩
      final base64String = base64Encode(compressedBytes);
      
      // 3. Data URL 생성
      final dataUrl = 'data:image/jpeg;base64,$base64String';
      
      print('Base64 인코딩 성공: ${dataUrl.length} 문자 (${(dataUrl.length / 1024).toStringAsFixed(1)}KB)');
      
      return dataUrl;
      
    } catch (e) {
      print('❌ Base64 인코딩 실패: $e');
      return null;
    }
  }

  /// Firestore용 이미지 압축 (더 강한 압축)
  Future<Uint8List?> _compressImageForFirestore(File imageFile) async {
    try {
      final originalBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(originalBytes);
      
      if (image == null) return null;
      
      // 더 작은 크기로 리사이즈 (Firestore 1MB 제한 고려)
      img.Image resized = image;
      if (image.width > 400 || image.height > 300) {
        resized = img.copyResize(
          image,
          width: image.width > image.height ? 400 : null,
          height: image.height >= image.width ? 300 : null,
        );
      }
      
      // 더 강한 JPEG 압축 (품질 40%)
      final compressedBytes = img.encodeJpg(resized, quality: 40);
      
      // 최대 200KB로 제한 (Base64로 인코딩하면 약 270KB가 됨)
      if (compressedBytes.length > 200 * 1024) {
        // 품질을 더 낮춰서 재압축
        final recompressed = img.encodeJpg(resized, quality: 25);
        print('추가 압축: ${compressedBytes.length} → ${recompressed.length} bytes');
        return Uint8List.fromList(recompressed);
      }
      
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      print('❌ Firestore용 이미지 압축 오류: $e');
      return null;
    }
  }

  /// 바코드 이미지를 Firebase Storage에 업로드 (압축 및 중복 제거)
  Future<String?> uploadBarcodeImage(File imageFile, String barcodeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 1. 이미지 압축
      final compressedBytes = await _compressImage(imageFile);
      if (compressedBytes == null) {
        throw Exception('바코드 이미지 압축 실패');
      }

      // 2. 이미지 해시 생성
      final imageHash = await _generateImageHash(compressedBytes);

      // 중복 확인은 임시 비활성화 (일부 환경에서 404 유발)

      // 4. 새 바코드 이미지 업로드 (단순 경로)
      final fileName = '${imageHash.substring(0, 16)}.jpg';
      final relativePath = 'images/' + fileName;

      // 메타데이터 설정 (단순화)
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );

      // 압축된 바이트로 업로드
      final downloadUrl = await _uploadToStorage(relativePath, compressedBytes, metadata);
      
      if (downloadUrl == null) throw Exception('업로드 실패');
      print('새 바코드 이미지 업로드 성공: ' + downloadUrl);
      return downloadUrl;
      
    } catch (e) {
      print('❌ 바코드 이미지 업로드 실패: $e');
      return null;
    }
  }

  /// 재료 편집 전용 간단 업로드 (바코드 방식과 동일한 단순 경로 사용)
  Future<String?> uploadIngredientImageForEdit(File imageFile, String ingredientId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('로그인이 필요합니다');
      }

      // 1. 압축
      final compressedBytes = await _compressImage(imageFile);
      if (compressedBytes == null) {
        throw Exception('이미지 압축 실패');
      }

      // 2. 해시 생성 (파일명 안정화)
      final imageHash = await _generateImageHash(compressedBytes);
      final fileName = '${imageHash.substring(0, 16)}.jpg';

      // 3. 업로드 (단순 경로)
      final sanitizedId = _sanitizePathSegment(ingredientId);
      final storageRef = _storage
          .ref()
          .child('ingredients_by_id')
          .child(sanitizedId)
          .child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
          'ingredientId': sanitizedId,
          'imageHash': imageHash,
          'compressed': 'true',
          'originalFileName': path.basename(imageFile.path),
        },
      );

      final snapshot = await storageRef.putData(compressedBytes, metadata);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('편집 이미지 업로드 성공: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ 편집 이미지 업로드 실패: $e');
      return null;
    }
  }

  /// 이미지 URL에서 Storage 참조를 가져와서 삭제
  Future<bool> deleteImageFromUrl(String imageUrl) async {
    try {
      // Firebase Storage URL인지 확인
      if (!imageUrl.contains('firebasestorage.googleapis.com')) {
        print('로컬 이미지이므로 Storage에서 삭제하지 않음: $imageUrl');
        return true;
      }

      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      
      print('Storage 이미지 삭제 성공: $imageUrl');
      return true;
    } catch (e) {
      print('❌ Storage 이미지 삭제 실패: $e');
      return false;
    }
  }

  /// 파일 크기 및 타입 검증 (압축 전)
  bool validateImageFile(File imageFile) {
    try {
      // 파일 크기 검증 (원본 20MB 제한 - 압축 후 500KB 이하로 줄어들 예정)
      final fileSize = imageFile.lengthSync();
      if (fileSize > 20 * 1024 * 1024) {
        print('❌ 파일 크기가 20MB를 초과합니다: ${fileSize / (1024 * 1024)}MB');
        return false;
      }

      // 파일 확장자 검증
      final extension = path.extension(imageFile.path).toLowerCase();
      final allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.bmp'];
      if (!allowedExtensions.contains(extension)) {
        print('❌ 지원하지 않는 파일 형식입니다: $extension');
        return false;
      }

      print('파일 검증 통과: ${(fileSize / 1024).toStringAsFixed(1)}KB → 압축 예정');
      return true;
    } catch (e) {
      print('❌ 파일 검증 실패: $e');
      return false;
    }
  }

  /// 압축 통계 로그
  void logCompressionStats(int originalSize, int compressedSize) {
    final originalKB = originalSize / 1024;
    final compressedKB = compressedSize / 1024;
    final compressionRatio = ((originalSize - compressedSize) / originalSize * 100);
    
    print('💰 비용 절약 통계:');
    print('   원본 크기: ${originalKB.toStringAsFixed(1)}KB');
    print('   압축 크기: ${compressedKB.toStringAsFixed(1)}KB');
    print('   압축률: ${compressionRatio.toStringAsFixed(1)}%');
    print('   절약된 용량: ${(originalKB - compressedKB).toStringAsFixed(1)}KB');
  }
}
