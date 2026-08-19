import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// 스크롤 오버플로우 효과 제거를 위한 커스텀 ScrollBehavior
class NoGlowScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}

class AppTheme {
  // 앱 기본 색상
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF64B5F6);
  static const Color accentColor = Color(0xFF42A5F5);
  static const Color backgroundColor = Colors.white;
  static const Color errorColor = Color(0xFFE57373);
  static const Color successColor = Color(0xFF81C784);
  static const Color warningColor = Color(0xFFFFD54F);
  
  // 텍스트 색상
  static const Color textPrimaryColor = Color(0xFF212121);
  static const Color textSecondaryColor = Color(0xFF757575);
  static const Color textTertiaryColor = Color(0xFF9E9E9E);
  
  // 애니메이션 지속 시간
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 400);
  static const Duration longAnimationDuration = Duration(milliseconds: 600);
  
  // 애니메이션 커브
  static const Curve defaultAnimationCurve = Curves.easeOutCubic;
  static const Curve bounceAnimationCurve = Curves.elasticOut;
  static const Curve smoothAnimationCurve = Curves.easeInOutCubic;
  
  // 스크롤 동작
  static ScrollBehavior get noGlowScrollBehavior => NoGlowScrollBehavior();
  
  // 기본 테마 가져오기
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: Colors.white,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(Colors.grey.shade400),
        trackColor: MaterialStateProperty.all(Colors.grey.shade200),
      ),
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        background: backgroundColor,
        surface: backgroundColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        error: errorColor,
      ),
      
      // 입력 필드 테마
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        border: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.grey),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 12),
        labelStyle: TextStyle(color: textSecondaryColor),
        floatingLabelStyle: TextStyle(color: primaryColor),
      ),
      
      // 버튼 테마
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          animationDuration: shortAnimationDuration,
        ),
      ),
      
      // 앱바 테마
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimaryColor,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: textPrimaryColor,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
      
      // 카드 테마
      cardTheme: CardTheme(
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      // 텍스트 테마
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        displayMedium: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        displaySmall: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        headlineMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          color: textPrimaryColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: textSecondaryColor,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: textTertiaryColor,
        ),
      ),
      
      // 페이지 전환 테마
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(
            allowEnterRouteSnapshotting: false,
          ),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      
      // 아이콘 테마
      iconTheme: IconThemeData(
        color: primaryColor,
        size: 24,
      ),
      
      // 체크박스 테마
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      
      // 스위치 테마
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return null;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.5);
          }
          return null;
        }),
      ),
      
      // 슬라이더 테마
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: primaryColor.withOpacity(0.3),
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.3),
        valueIndicatorColor: primaryColor,
      ),
      
      // 스낵바 테마
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentTextStyle: TextStyle(color: Colors.white),
        backgroundColor: Colors.grey.shade800,
      ),
      
      // 다이얼로그 테마
      dialogTheme: DialogTheme(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 4,
        backgroundColor: backgroundColor,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
        ),
        contentTextStyle: TextStyle(
          fontSize: 16,
          color: textSecondaryColor,
        ),
      ),
      
      // 하단 시트 테마
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        backgroundColor: backgroundColor,
        modalBackgroundColor: backgroundColor,
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
  
  // 애니메이션 스타일
  static Widget fadeInAnimation({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double beginOpacity = 0.0,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: beginOpacity, end: 1.0),
      duration: duration ?? mediumAnimationDuration,
      curve: curve ?? defaultAnimationCurve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: child,
    );
  }
  
  static Widget slideAnimation({
    required Widget child,
    Duration? duration,
    Curve? curve,
    Offset begin = const Offset(0, 0.1),
    Offset end = Offset.zero,
  }) {
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: begin, end: end),
      duration: duration ?? mediumAnimationDuration,
      curve: curve ?? defaultAnimationCurve,
      builder: (context, value, child) {
        return Transform.translate(
          offset: value * 100,
          child: child,
        );
      },
      child: child,
    );
  }
  
  static Widget scaleAnimation({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double begin = 0.95,
    double end = 1.0,
    Alignment alignment = Alignment.center,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: begin, end: end),
      duration: duration ?? mediumAnimationDuration,
      curve: curve ?? defaultAnimationCurve,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: alignment,
          child: child,
        );
      },
      child: child,
    );
  }
  
  static Widget combinedAnimation({
    required Widget child,
    Duration? duration,
    Curve? curve,
    double beginOpacity = 0.0,
    Offset beginOffset = const Offset(0, 0.1),
    double beginScale = 0.95,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration ?? mediumAnimationDuration,
      curve: curve ?? defaultAnimationCurve,
      builder: (context, value, child) {
        return Opacity(
          opacity: beginOpacity + (1.0 - beginOpacity) * value,
          child: Transform.translate(
            offset: Offset(
              beginOffset.dx * (1.0 - value) * 100,
              beginOffset.dy * (1.0 - value) * 100,
            ),
            child: Transform.scale(
              scale: beginScale + (1.0 - beginScale) * value,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
} 