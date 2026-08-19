import 'package:flutter/material.dart';

class CommonBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CommonBottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  State<CommonBottomNavigation> createState() => _CommonBottomNavigationState();
}

class _CommonBottomNavigationState extends State<CommonBottomNavigation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _controller.forward();
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuart,
      )),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: widget.currentIndex,
          onTap: widget.onTap,
        items: [
          _buildNavItem(Icons.home_rounded, '홈', 0),
          _buildNavItem(Icons.kitchen_rounded, '냉장고', 1),
          _buildNavItem(Icons.bar_chart, '통계', 2),
          _buildNavItem(Icons.person, '마이페이지', 3),
        ],
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
    );
  }
  
  BottomNavigationBarItem _buildNavItem(IconData icon, String label, int index) {
    final isSelected = widget.currentIndex == index;
    
    return BottomNavigationBarItem(
      icon: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.all(isSelected ? 10 : 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon),
      ),
      label: label,
    );
  }
} 