import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/search_service.dart';
import '../refrigerator/ingredients_screen.dart';
import '../refrigerator/widgets/ingredient_image_widget.dart';

class SearchScreen extends StatefulWidget {
  final String? roomId; // optional로 변경

  const SearchScreen({
    Key? key,
    this.roomId,
  }) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SearchService _searchService = SearchService();
  
  List<Map<String, dynamic>> _searchResults = [];
  int _searchRequestId = 0; // 동시에 여러 검색이 실행될 때를 구분하기 위한 ID
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
    // 이 검색 요청에 대한 고유 ID (나중에 들어온 검색만 반영하기 위함)
    final int requestId = ++_searchRequestId;
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    // roomId가 없으면 검색할 수 없음
    if (widget.roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('방을 선택한 후 검색해주세요'),
          backgroundColor: Colors.orange[600],
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await _searchService.searchIngredientsInRoom(
        widget.roomId!,
        query,
      );

      // 검색이 끝났을 때, 이 결과가 "가장 마지막 검색"이 아닐 경우 무시
      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      // 에러가 났어도, 이미 더 최근 검색이 실행 중이면 UI를 건드리지 않음
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
    if (widget.roomId == null) return;

    // 검색 결과 화면 위에 "해당 칸" 화면을 쌓는다.
    // 스택 구조: 이전화면 → 검색 결과 화면 → 해당 칸 화면
    // 뒤로가기를 한 번 누르면 항상 "마지막 검색 결과 화면"으로 돌아오도록 하기 위함.
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: RouteSettings(name: 'ingredient_from_search'),
        builder: (context) => IngredientsScreen(
          roomId: widget.roomId!,
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
      backgroundColor: Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.grey[900]),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                      SizedBox(width: 12),
                      Text(
                        '식품 검색',
                        style: TextStyle(
                          color: Colors.grey[900],
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // 검색창
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!, width: 1.5),
                    ),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: TextStyle(fontSize: 16),
                      onChanged: (value) {
                      _onSearchTextChanged(value);
                      },
                      decoration: InputDecoration(
                        hintText: '식품명을 입력하세요',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: Color(0xFF6B9FFF), size: 22),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.cancel, color: Colors.grey[400], size: 20),
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
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
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
              '검색 중...',
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
            Icon(
              Icons.search,
              size: 80,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              '식품명을 입력하여 검색하세요',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '방의 모든 냉장고에서 검색합니다',
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
    final String? imagePath = ingredient['imagePath']?.toString();
    
    // D-day 계산
    String dDayText = '';
    if (expiryTimestamp != null) {
      final daysLeft = _calculateDaysLeft(expiryTimestamp.toDate());
      if (daysLeft < 0) {
        dDayText = 'D+${daysLeft.abs()}';
      } else if (daysLeft == 0) {
        dDayText = 'D-Day';
      } else {
        dDayText = 'D-$daysLeft';
      }
    }
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToIngredient(ingredient),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                // 왼쪽: 이미지 (있으면 이미지, 없으면 아이콘)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: imagePath != null && imagePath.isNotEmpty
                        ? Colors.transparent
                        : Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: (imagePath != null && imagePath.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: IngredientImageWidget(
                            imagePath: imagePath,
                            width: 44,
                            height: 44,
                            fallbackIcon: Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFF6B9FFF),
                            ),
                          ),
                        )
                      : Icon(Icons.inventory_2_outlined,
                          color: Color(0xFF6B9FFF)),
                ),

                SizedBox(width: 16),

                // 가운데: 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 식품명
                      Text(
                        ingredient['name'],
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        ),
                      ),
                      
                      SizedBox(height: 8),
                      
                      // 위치
                      Row(
                        children: [
                          Icon(Icons.kitchen_outlined, size: 16, color: Colors.grey[500]),
                          SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${ingredient['refrigeratorName']} · ${ingredient['compartmentName']}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                      // 유통기한
                      if (expiryTimestamp != null) ...[
                        SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: expiryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                dDayText,
                                style: TextStyle(
                                  color: expiryColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              _formatDate(expiryTimestamp),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                SizedBox(width: 12),
                
                // 오른쪽: 수량 & 이동 아이콘
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (ingredient['quantity']?.toString().isNotEmpty == true)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Color(0xFF6B9FFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ingredient['quantity']?.toString() ?? '',
                          style: TextStyle(
                            color: Color(0xFF6B9FFF),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    SizedBox(height: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.grey[400],
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}