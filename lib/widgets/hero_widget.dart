import 'package:flutter/material.dart';

class HeroWidget extends StatelessWidget {
  final String tag;
  final Widget child;
  final bool createRectTween;

  const HeroWidget({
    Key? key,
    required this.tag,
    required this.child,
    this.createRectTween = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (createRectTween) {
      return Hero(
        tag: tag,
        createRectTween: (begin, end) {
          return RectTween(
            begin: begin,
            end: end,
          );
        },
        flightShuttleBuilder: (
          flightContext,
          animation,
          flightDirection,
          fromHeroContext,
          toHeroContext,
        ) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Material(
                color: Colors.transparent,
                child: ScaleTransition(
                  scale: animation.drive(
                    Tween<double>(begin: 0.8, end: 1.0)
                        .chain(CurveTween(curve: Curves.easeOutQuad)),
                  ),
                  child: FadeTransition(
                    opacity: animation.drive(
                      Tween<double>(begin: 0.0, end: 1.0)
                          .chain(CurveTween(curve: Curves.easeInQuad)),
                    ),
                    child: child,
                  ),
                ),
              );
            },
            child: toHeroContext.widget,
          );
        },
        child: child,
      );
    }

    return Hero(
      tag: tag,
      child: child,
    );
  }
} 