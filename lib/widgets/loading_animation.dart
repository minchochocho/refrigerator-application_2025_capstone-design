import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingAnimation extends StatelessWidget {
  final String? message;
  final Color? color;
  final double size;
  final bool useLottie;
  final String? lottieAsset;

  const LoadingAnimation({
    Key? key,
    this.message,
    this.color,
    this.size = 48.0,
    this.useLottie = true, // 기본값을 true로 변경
    this.lottieAsset = 'assets/animations/loading.json', // 기본 애니메이션 설정
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final indicatorColor = color ?? theme.colorScheme.primary;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (useLottie && lottieAsset != null)
            SizedBox(
              width: size * 2.5,
              height: size * 2.5,
              child: Lottie.asset(
                lottieAsset!,
                repeat: true,
              ),
            )
          else
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
                strokeWidth: 3.0,
              ),
            ),
          if (message != null) ...[
            SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 전체 화면을 덮는 로딩 오버레이 위젯
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final Color backgroundColor;
  final bool dismissible;
  final Widget? child;
  final bool useLottie;
  final String? lottieAsset;

  const LoadingOverlay({
    Key? key,
    this.message,
    this.backgroundColor = Colors.black38,
    this.dismissible = false,
    this.child,
    this.useLottie = false,
    this.lottieAsset,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (child != null) child!,
        Positioned.fill(
          child: GestureDetector(
            onTap: dismissible ? () => Navigator.of(context).pop() : null,
            child: Container(
              color: backgroundColor,
              child: LoadingAnimation(
                message: message,
                color: Colors.white,
                useLottie: useLottie,
                lottieAsset: lottieAsset,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 로딩 상태를 관리하는 Provider
class LoadingProvider extends InheritedWidget {
  final bool isLoading;
  final String? message;
  final VoidCallback showLoading;
  final VoidCallback hideLoading;
  final Function(String?) updateMessage;

  const LoadingProvider({
    Key? key,
    required Widget child,
    required this.isLoading,
    required this.message,
    required this.showLoading,
    required this.hideLoading,
    required this.updateMessage,
  }) : super(key: key, child: child);

  static LoadingProvider of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<LoadingProvider>();
    assert(result != null, 'No LoadingProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(LoadingProvider oldWidget) {
    return isLoading != oldWidget.isLoading || message != oldWidget.message;
  }
}

/// 성공 애니메이션 위젯
class SuccessAnimation extends StatelessWidget {
  final String? message;
  final double size;
  final VoidCallback? onComplete;

  const SuccessAnimation({
    Key? key,
    this.message,
    this.size = 80.0,
    this.onComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Lottie.asset(
              'assets/animations/success.json',
              repeat: false,
              onLoaded: (composition) {
                // 애니메이션이 끝나면 콜백 실행
                Future.delayed(composition.duration, () {
                  onComplete?.call();
                });
              },
            ),
          ),
          if (message != null) ...[
            SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 로딩 상태 관리 위젯
class LoadingManager extends StatefulWidget {
  final Widget child;
  final bool dismissible;
  final Color backgroundColor;
  final bool useLottie;
  final String? lottieAsset;

  const LoadingManager({
    Key? key,
    required this.child,
    this.dismissible = false,
    this.backgroundColor = Colors.black38,
    this.useLottie = false,
    this.lottieAsset,
  }) : super(key: key);

  @override
  State<LoadingManager> createState() => _LoadingManagerState();
}

class _LoadingManagerState extends State<LoadingManager> {
  bool _isLoading = false;
  String? _message;

  void showLoading() {
    setState(() {
      _isLoading = true;
    });
  }

  void hideLoading() {
    setState(() {
      _isLoading = false;
      _message = null;
    });
  }

  void updateMessage(String? message) {
    setState(() {
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LoadingProvider(
      isLoading: _isLoading,
      message: _message,
      showLoading: showLoading,
      hideLoading: hideLoading,
      updateMessage: updateMessage,
      child: Stack(
        children: [
          widget.child,
          if (_isLoading)
            Positioned.fill(
              child: LoadingOverlay(
                message: _message,
                dismissible: widget.dismissible,
                backgroundColor: widget.backgroundColor,
                useLottie: widget.useLottie,
                lottieAsset: widget.lottieAsset,
              ),
            ),
        ],
      ),
    );
  }
} 