import 'package:flutter/material.dart';

/// 정렬 메뉴 바텀시트를 표시하고 사용자가 선택한 정렬 타입을 콜백으로 전달합니다.
Future<void> showSortMenuSheet(
  BuildContext context, {
  required String currentSortBy,
  required void Function(String sortBy) onSelected,
}) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => _SortMenuSheet(
      currentSortBy: currentSortBy,
      onSelected: onSelected,
    ),
  );
}

class _SortMenuSheet extends StatelessWidget {
  final String currentSortBy;
  final void Function(String sortBy) onSelected;

  const _SortMenuSheet({
    required this.currentSortBy,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '정렬',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[900],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          _SortMenuItem(
            label: '최신순',
            sortType: 'date',
            icon: Icons.access_time_rounded,
            selected: currentSortBy == 'date',
            onTap: () {
              Navigator.pop(context);
              onSelected('date');
            },
          ),
          _SortMenuItem(
            label: '유통기한 빠른 순',
            sortType: 'expiry',
            icon: Icons.calendar_today_rounded,
            selected: currentSortBy == 'expiry',
            onTap: () {
              Navigator.pop(context);
              onSelected('expiry');
            },
          ),
          _SortMenuItem(
            label: '이름순 (가나다)',
            sortType: 'name',
            icon: Icons.sort_by_alpha_rounded,
            selected: currentSortBy == 'name',
            onTap: () {
              Navigator.pop(context);
              onSelected('name');
            },
          ),
          _SortMenuItem(
            label: '좋아요 많은 순',
            sortType: 'likes',
            icon: Icons.favorite_rounded,
            selected: currentSortBy == 'likes',
            onTap: () {
              Navigator.pop(context);
              onSelected('likes');
            },
          ),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SortMenuItem extends StatelessWidget {
  final String label;
  final String sortType;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SortMenuItem({
    required this.label,
    required this.sortType,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? Color(0xFF6366F1).withOpacity(0.05) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: selected ? Color(0xFF6366F1) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? Color(0xFF6366F1) : Colors.grey[600],
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? Color(0xFF6366F1) : Colors.grey[800],
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_rounded,
                size: 20,
                color: Color(0xFF6366F1),
              ),
          ],
        ),
      ),
    );
  }
}


