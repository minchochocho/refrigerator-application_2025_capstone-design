import 'package:flutter/material.dart';

class IngredientListSection extends StatelessWidget {
  final List<Map<String, dynamic>> filteredIngredients;
  final List<Map<String, dynamic>> allIngredients;
  final ScrollController scrollController;
  final Map<String, GlobalKey> itemKeysById;
  final String searchQuery;
  final VoidCallback onClearSearch;
  final Widget Function(Map<String, dynamic> ingredient, int originalIndex) buildCard;

  const IngredientListSection({
    super.key,
    required this.filteredIngredients,
    required this.allIngredients,
    required this.scrollController,
    required this.itemKeysById,
    required this.searchQuery,
    required this.onClearSearch,
    required this.buildCard,
  });

  @override
  Widget build(BuildContext context) {
    if (filteredIngredients.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                searchQuery.isEmpty ? Icons.kitchen_rounded : Icons.search_off,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 24),
            Text(
              searchQuery.isEmpty ? '등록된 식품이 없습니다' : '\'${searchQuery}\' 검색 결과가 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Text(
              searchQuery.isEmpty
                  ? '영수증 스캔 또는 개별 추가로\n식품을 등록해보세요'
                  : '다른 검색어로 시도해보세요',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (searchQuery.isNotEmpty)
          Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.filter_list, color: Colors.blue[600], size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '\'${searchQuery}\' 검색 결과 ${filteredIngredients.length}개',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onClearSearch,
                  child: Text(
                    '전체보기',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            padding: EdgeInsets.all(20),
            itemCount: filteredIngredients.length,
            itemBuilder: (context, index) {
              final ingredient = filteredIngredients[index];
              final String id = ingredient['id']?.toString() ?? '';
              if (id.isNotEmpty && !itemKeysById.containsKey(id)) {
                itemKeysById[id] = GlobalKey();
              }
              final originalIndex = allIngredients.indexWhere((item) => item['id'] == ingredient['id']);
              return KeyedSubtree(
                key: itemKeysById[id],
                child: buildCard(ingredient, originalIndex),
              );
            },
          ),
        ),
      ],
    );
  }
}


