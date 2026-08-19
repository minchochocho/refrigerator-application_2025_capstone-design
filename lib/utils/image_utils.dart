import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageUtils {
  // 안전한 네트워크 이미지 로딩
  static Widget safeNetworkImage({
    required String imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _defaultErrorWidget(),
    );
  }

  // 안전한 Asset 이미지 로딩
  static Widget safeAssetImage({
    required String assetPath,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? errorWidget,
  }) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? _defaultErrorWidget();
      },
    );
  }

  // 안전한 CircleAvatar 이미지
  static Widget safeCircleAvatar({
    required double radius,
    String? imageUrl,
    String? assetPath,
    Widget? child,
    Color? backgroundColor,
  }) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[200],
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipOval(
              child: imageUrl.startsWith('http')
                  ? safeNetworkImage(
                      imageUrl: imageUrl,
                      width: radius * 2,
                      height: radius * 2,
                      fit: BoxFit.cover,
                    )
                  : safeAssetImage(
                      assetPath: imageUrl,
                      width: radius * 2,
                      height: radius * 2,
                      fit: BoxFit.cover,
                    ),
            )
          : assetPath != null && assetPath.isNotEmpty
              ? ClipOval(
                  child: safeAssetImage(
                    assetPath: assetPath,
                    width: radius * 2,
                    height: radius * 2,
                    fit: BoxFit.cover,
                  ),
                )
              : child ?? Icon(Icons.person, size: radius),
    );
  }

  // 기본 플레이스홀더
  static Widget _defaultPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
        ),
      ),
    );
  }

  // 기본 에러 위젯
  static Widget _defaultErrorWidget() {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey[400],
          size: 32,
        ),
      ),
    );
  }

  // 이미지 컨테이너 (고정 크기)
  static Widget imageContainer({
    required Widget child,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    List<BoxShadow>? boxShadow,
    Color? backgroundColor,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.grey[100],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        boxShadow: boxShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
} 