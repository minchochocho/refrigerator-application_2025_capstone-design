import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/search_service.dart';
import '../refrigerator/ingredients_screen.dart';

class RefrigeratorSearchScreen extends StatefulWidget {
  final String roomId;
  final String refrigeratorName;

  const RefrigeratorSearchScreen({
    Key? key,
    required this.roomId,
    required this.refrigeratorName,
  }) : super(key: key);

  @override
  _RefrigeratorSearchScreenState createState() => _RefrigeratorSearchScreenState();
}

class _RefrigeratorSearchScreenState extends State<RefrigeratorSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  
  List<Map<String, dynamic>> _searchResults = [];
  int _searchRequestId = 0; // 동시에 여러 검색 요청을 구분하기 위한 ID
  Timer? _debounce;         // 타이핑 디바운스를 위한 타이머
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // 타이핑할 때마다 바로 검색 실행 (최신 검색만 반영)
  void _onSearchTextChanged(String value) {
    final query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }

    // 남아있을 수 있는 타이머는 정리하고, 디바운스 후 검색 실행
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final int requestId = ++_searchRequestId; // 이 검색 요청 전용 ID
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await _searchService.searchIngredientsInRefrigerator(
        widget.roomId,
        widget.refrigeratorName,
        query,
      );

      // 더 최신 검색이 이미 실행된 경우, 이 결과는 버림
      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() {
        _isSearching = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('검색 중 오류가 발생했습니다'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  void _navigateToIngredient(Map<String, dynamic> ingredient) {
    // 검색 결과 화면 위에 "해당 칸" 화면을 쌓는다.
    // 스택 구조: 이전화면 → 검색 결과 화면 → 해당 칸 화면
    // 뒤로가기를 한 번 누르면 항상 "마지막 검색 결과 화면"으로 돌아오도록 하기 위함.
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'ingredient_from_search'),
        builder: (context) => IngredientsScreen(
          roomId: widget.roomId,
          refrigeratorName: ingredient['refrigeratorName'],
          compartmentName: ingredient['compartmentName'],
          compartmentIndex: ingredient['compartmentIndex'],
          targetIngredientId: ingredient['id'],
        ),
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  Color _getExpiryColor(Timestamp? expiryTimestamp) {
    if (expiryTimestamp == null) return Colors.grey[600]!;
    
    final expiryDate = expiryTimestamp.toDate();
    final difference = _calculateDaysLeft(expiryDate);
    
    if (difference < 0) {
      return Colors.red[600]!; // 만료됨
    } else if (difference <= 3) {
      return Colors.orange[600]!; // 3일 이내
    } else if (difference <= 7) {
      return Colors.yellow[700]!; // 7일 이내
    } else {
      return Colors.green[600]!; // 안전
    }
  }

  // 정확한 D-day 계산 메서드
  int _calculateDaysLeft(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    
    return expiry.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${widget.refrigeratorName} 검색',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 검색 입력 영역
          Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      _onSearchTextChanged(value);
                    },
                    decoration: InputDecoration(
                      hintText: '${widget.refrigeratorName}에서 찾을 식품명을 입력하세요',
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[600]),
                              onPressed: () {
                                // 입력 내용/검색 상태 완전 초기화
                                _debounce?.cancel();
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                  _hasSearched = false;
                                  _isSearching = false;
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue[600]!),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 검색 결과 영역
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            ),
            SizedBox(height: 16),
            Text(
              '${widget.refrigeratorName}에서 검색 중...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search,
                size: 60,
                color: Colors.blue[400],
              ),
            ),
            SizedBox(height: 16),
            Text(
              '${widget.refrigeratorName} 검색',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '이 냉장고의 모든 칸에서 검색합니다',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off,
                  size: 60,
                  color: Colors.orange[400],
                ),
              ),
              SizedBox(height: 24),
              Text(
                '\'${_searchController.text}\' 검색 결과가 없습니다',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.lightbulb_outline, 
                             color: Colors.blue[600], size: 20),
                        SizedBox(width: 8),
                        Text(
                          '검색 팁',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    _buildSearchTip('• 초성으로 검색해보세요 (예: ㅊㅈ → 치즈)'),
                    _buildSearchTip('• 짧은 단어로 검색해보세요 (예: 토마토 → 토마)'),
                    _buildSearchTip('• 띄어쓰기 없이 검색해보세요'),
                    _buildSearchTip('• 메모 내용도 검색됩니다'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final ingredient = _searchResults[index];
        return _buildSearchResultCard(ingredient);
      },
    );
  }

  Widget _buildSearchTip(String tip) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(
        tip,
        style: TextStyle(
          color: Colors.blue[600],
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> ingredient) {
    final expiryTimestamp = ingredient['expiryDate'] as Timestamp?;
    final expiryColor = _getExpiryColor(expiryTimestamp);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _navigateToIngredient(ingredient),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 식품명과 수량
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ingredient['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    if (ingredient['quantity']?.toString().isNotEmpty == true)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ingredient['quantity']?.toString() ?? '',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                
                SizedBox(height: 8),
                
                // 위치 정보 (칸명만 표시)
                Row(
                  children: [
                    Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                    SizedBox(width: 4),
                    Text(
                      ingredient['compartmentName'],
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
                // 유통기한 (있는 경우만)
                if (expiryTimestamp != null) ...[
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: expiryColor),
                      SizedBox(width: 4),
                      Text(
                        '유통기한: ${_formatDate(expiryTimestamp)}',
                        style: TextStyle(
                          color: expiryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                
                // 메모 (있는 경우만)
                if (ingredient['memo']?.toString().isNotEmpty == true) ...[
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.note, size: 16, color: Colors.grey[600]),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ingredient['memo']?.toString() ?? '',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                
                SizedBox(height: 12),
                
                // 이동 버튼
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _navigateToIngredient(ingredient),
                    icon: Icon(Icons.arrow_forward, size: 16),
                    label: Text('해당 칸으로 이동'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue[600],
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 