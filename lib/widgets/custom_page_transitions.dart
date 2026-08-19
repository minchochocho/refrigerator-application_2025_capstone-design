import 'package:flutter/material.dart';

// 페이드 전환 애니메이션
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  FadePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) =>
              FadeTransition(
                opacity: animation,
                child: child,
              ),
          transitionDuration: duration,
        );
}

// 슬라이드 전환 애니메이션 (오른쪽에서 왼쪽으로)
class SlideRightPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  SlideRightPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
    RouteSettings? settings,
  }) : super(
          settings: settings,
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end);
            final offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration: duration,
        );
}

// 슬라이드 업 전환 애니메이션 (아래에서 위로)
class SlideUpPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  SlideUpPageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            final tween = Tween(begin: begin, end: end);
            final offsetAnimation = animation.drive(tween);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
          transitionDuration: duration,
        );
}

// 확대/축소 전환 애니메이션
class ScalePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;
  final Alignment alignment;

  ScalePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 300),
    this.alignment = Alignment.center,
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            return ScaleTransition(
              scale: animation,
              alignment: alignment,
              child: child,
            );
          },
          transitionDuration: duration,
        );
}

// 혼합 전환 애니메이션 (페이드 + 슬라이드)
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;
  final Offset beginOffset;

  FadeSlidePageRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 400),
    this.beginOffset = const Offset(0.0, 0.2),
  }) : super(
          pageBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) =>
              page,
          transitionsBuilder: (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            final end = Offset.zero;
            final tween = Tween(begin: beginOffset, end: end);
            final offsetAnimation = animation.drive(tween);
            final fadeAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );

            return SlideTransition(
              position: offsetAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: child,
              ),
            );
          },
          transitionDuration: duration,
        );
} 