import 'package:flutter/material.dart';

class SortCounterBar extends StatelessWidget {
  final IconData sortIcon;
  final String sortLabel;
  final VoidCallback onSortTap;
  final int itemCount;

  const SortCounterBar({
    super.key,
    required this.sortIcon,
    required this.sortLabel,
    required this.onSortTap,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onSortTap,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    sortIcon,
                    size: 16,
                    color: Color(0xFF6366F1),
                  ),
                  SizedBox(width: 6),
                  Text(
                    sortLabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          Spacer(),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${itemCount}개',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6366F1),
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


