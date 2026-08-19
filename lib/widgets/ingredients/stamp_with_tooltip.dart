import 'package:flutter/material.dart';

class StampWithTooltip extends StatefulWidget {
  final String nickname;
  final Color avatarColor;
  final IconData avatarIcon;
  final double stampSize;

  const StampWithTooltip({
    Key? key,
    required this.nickname,
    required this.avatarColor,
    required this.avatarIcon,
    required this.stampSize,
  }) : super(key: key);

  @override
  _StampWithTooltipState createState() => _StampWithTooltipState();
}

class _StampWithTooltipState extends State<StampWithTooltip>
    with TickerProviderStateMixin {
  bool _showTooltip = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleTooltip() {
    setState(() {
      _showTooltip = !_showTooltip;
      if (_showTooltip) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });

    // 3초 후 자동으로 툴팁 숨기기
    if (_showTooltip) {
      Future.delayed(Duration(seconds: 3), () {
        if (_showTooltip && mounted) {
          setState(() {
            _showTooltip = false;
            _animationController.reverse();
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 도장 (클릭 영역 확장)
        GestureDetector(
          onTap: _toggleTooltip,
          child: Container(
            // 클릭 영역을 더 크게 만들기 위해 패딩 추가
            padding: EdgeInsets.all(8), // 8px 패딩으로 클릭 영역 확장
            child: Container(
              width: widget.stampSize,
              height: widget.stampSize,
              decoration: BoxDecoration(
                color: widget.avatarColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                // 그림자 제거
              ),
              child: Stack(
              alignment: Alignment.center,
              children: [
                // 프로필 아이콘
                Icon(
                  widget.avatarIcon,
                  size: widget.stampSize * 0.4,
                  color: Colors.white,
                ),
                // 잠금 아이콘 (오른쪽 하단)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red[600],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.lock,
                      color: Colors.white,
                      size: widget.stampSize * 0.2,
                    ),
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
        
        // 깔끔한 툴팁 (닉네임만)
        if (_showTooltip)
          Positioned(
            top: -20, // 도장과 겹치지 않을 정도로 적당히 위쪽에
            left: widget.stampSize / 2 - 25, // 도장 중심에 더 정확하게 맞춤
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  alignment: Alignment.center, // 중앙 정렬로 변경
                  child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65), // 더 연한 투명한 검은색
                        borderRadius: BorderRadius.circular(16), // 더 둥근 모서리
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.nickname,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3, // 글자 간격 조정
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
