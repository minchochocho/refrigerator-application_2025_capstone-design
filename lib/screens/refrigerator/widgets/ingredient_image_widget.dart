import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 재료 이미지 표시 위젯 (URL, Asset, 로컬 파일 지원)
class IngredientImageWidget extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  final Widget? fallbackIcon;
  
  const IngredientImageWidget({
    Key? key,
    required this.imagePath,
    required this.width,
    required this.height,
    this.fallbackIcon,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    print('🖼️ 이미지 렌더링 시도: $imagePath');
    
    if (imagePath.startsWith('data:image/')) {
      return _buildBase64Image();
    } else if (imagePath.startsWith('http')) {
      return _buildNetworkImage();
    } else if (imagePath.startsWith('asset://')) {
      return _buildAssetImage();
    } else {
      return _buildFileImage();
    }
  }
  
  /// Base64 Data URL 이미지
  Widget _buildBase64Image() {
    print('   Base64 Data URL로 렌더링');
    try {
      // Base64 Data URL에서 base64 부분 추출
      final base64String = imagePath.split(',')[1];
      final bytes = base64Decode(base64String);
      return Image.memory(
        bytes,
        key: ValueKey(imagePath), // 캐시 키 추가로 실시간 업데이트 보장
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
      );
    } catch (e) {
      print('   ❌ Base64 디코딩 실패: $e');
      return _buildErrorWidget();
    }
  }
  
  /// HTTP 네트워크 이미지
  Widget _buildNetworkImage() {
    print('   HTTP 이미지로 렌더링');
    final int? cacheW = (width.isFinite && width > 0) ? (width * 2).round() : null;
    final int? cacheH = (height.isFinite && height > 0) ? (height * 2).round() : null;
    return CachedNetworkImage(
      imageUrl: imagePath,
      key: ValueKey(imagePath), // 캐시 키 추가로 실시간 업데이트 보장
      width: width.isFinite ? width : null,
      height: height.isFinite ? height : null,
      fit: BoxFit.cover,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      httpHeaders: {'Cache-Control': 'no-cache'}, // HTTP 캐시 비활성화
      placeholder: (context, url) => Container(
        width: width.isFinite ? width : null,
        height: height.isFinite ? height : null,
        color: Colors.grey[200],
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (context, url, error) => _buildErrorWidget(),
    );
  }
  
  /// Asset 이미지
  Widget _buildAssetImage() {
    print('   📱 Asset 이미지로 렌더링');
    return Image.asset(
      imagePath.replaceFirst('asset://', ''),
      key: ValueKey(imagePath), // 캐시 키 추가
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
    );
  }
  
  /// 로컬 파일 이미지
  Widget _buildFileImage() {
    print('   📁 로컬 파일로 렌더링');
    return Image.file(
      File(imagePath),
      key: ValueKey(imagePath), // 캐시 키 추가
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
    );
  }
  
  /// 에러 위젯
  Widget _buildErrorWidget() {
    return Container(
      padding: EdgeInsets.all(12),
      child: fallbackIcon ?? Icon(Icons.image_not_supported, size: 24),
    );
  }
}

