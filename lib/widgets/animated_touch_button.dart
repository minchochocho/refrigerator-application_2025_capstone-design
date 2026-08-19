import 'package:flutter/material.dart';

class AnimatedTouchButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final Duration duration;
  final bool enabled;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? highlightColor;

  const AnimatedTouchButton({
    Key? key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.95,
    this.duration = const Duration(milliseconds: 150),
    this.enabled = true,
    this.padding,
    this.backgroundColor,
    this.borderRadius,
    this.splashColor,
    this.highlightColor,
  }) : super(key: key);

  @override
  State<AnimatedTouchButton> createState() => _AnimatedTouchButtonState();
}

class _AnimatedTouchButtonState extends State<AnimatedTouchButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scale,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enabled) {
      setState(() {
        _isPressed = true;
      });
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.enabled) {
      setState(() {
        _isPressed = false;
      });
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.enabled) {
      setState(() {
        _isPressed = false;
      });
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Material(
              color: widget.backgroundColor ?? Colors.transparent,
              borderRadius: widget.borderRadius,
              child: Opacity(
                opacity: widget.enabled ? 1.0 : 0.6,
                child: Ink(
                  child: InkWell(
                    splashColor: widget.splashColor,
                    highlightColor: widget.highlightColor,
                    borderRadius: widget.borderRadius,
                    onTap: widget.enabled ? widget.onTap : null,
                    child: Padding(
                      padding: widget.padding ?? EdgeInsets.zero,
                      child: widget.child,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 