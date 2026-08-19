import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../refrigerator/widgets/ingredient_image_widget.dart';

class PreferencesScreen extends StatefulWidget {
  final User? user;

  const PreferencesScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  _PreferencesScreenState createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _preferencesData = {};
  List<Map<String, dynamic>> _likedItems = [];
  List<Map<String, dynamic>> _dislikedItems = [];

  @override
  void initState() {
    super.initState();
    print('🚀 PreferencesScreen initState 호출됨');
    // 즉시 데이터 로드 시작
    _loadPreferencesData();
  }
  
  @override
  void didUpdateWidget(PreferencesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('🔄 PreferencesScreen didUpdateWidget 호출됨');
    // 위젯이 업데이트될 때마다 데이터 다시 로드
    _loadPreferencesData();
  }

  Future<void> _loadPreferencesData() async {
    print('📥 _loadPreferencesData 시작: user=${widget.user?.uid ?? "null"}');
    
    if (widget.user == null) {
      print('❌ user가 null이어서 로드 중단');
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    print('✅ user 존재, 데이터 로드 시작');

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUserId = widget.user!.uid;
      List<Map<String, dynamic>> likedItems = [];
      List<Map<String, dynamic>> dislikedItems = [];

      // 사용자가 접근 가능한 냉장고만 조회 (member_ids 에 포함된 경우)
      final firestore = FirebaseFirestore.instance;
      final refrigeratorsSnapshot = await firestore
          .collection('Refrigerators')
          .where('member_ids', arrayContains: currentUserId)
          .get();

      for (var refrigeratorDoc in refrigeratorsSnapshot.docs) {
        final refrigeratorData = refrigeratorDoc.data();
        final String roomId = (refrigeratorData['room_id'] ?? '').toString();
        final compartmentNames = refrigeratorData['compartment_names'] as List<dynamic>?;
        final refrigeratorName = refrigeratorData['name'] as String? ?? '알 수 없는 냉장고';
        
        // 방이 삭제된 경우 선호도에서 제외
        if (roomId.isNotEmpty) {
          try {
            final roomDoc = await firestore.collection('Rooms').doc(roomId).get();
            if (!roomDoc.exists) {
              print('⚠️ 방 삭제됨, 선호도 목록에서 냉장고 제외: $refrigeratorName');
              continue;
            }
          } catch (e) {
            print('⚠️ 방 확인 실패, 선호도 목록에서 냉장고 제외: $refrigeratorName (error: $e)');
            continue;
          }
        }
        
        // compartment_names가 없으면 해당 냉장고 건너뜀
        if (compartmentNames == null || compartmentNames.isEmpty) {
          continue;
        }
        
        // 방 이름 가져오기 (냉장고 이름과 함께 표시)
        String roomName = refrigeratorName;
        if (roomId.isNotEmpty) {
          try {
            final roomDoc = await firestore
                .collection('Rooms')
                .doc(roomId)
                .get();
            if (roomDoc.exists) {
              final roomData = roomDoc.data();
              // 'roomName' 또는 'name' 필드 시도
              final fetchedRoomName = roomData?['roomName'] ?? roomData?['name'];
              if (fetchedRoomName != null) {
                roomName = '$fetchedRoomName - $refrigeratorName';
              }
            }
          } catch (e) {
            print('방 이름 로드 오류: $e');
          }
        }

        // compartment_names 배열의 인덱스를 기반으로 각 칸 조회
        for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
          // 각 칸의 모든 재료를 순회
          final ingredientsSnapshot = await refrigeratorDoc.reference
              .collection('compartments')
              .doc(compartmentIndex.toString())  // 인덱스로 직접 접근
              .collection('ingredients')
              .get();

          for (var ingredientDoc in ingredientsSnapshot.docs) {
            final data = ingredientDoc.data();
            final preferences = data['preferences'] as Map<String, dynamic>?;

            if (preferences != null) {
              final likes = List<String>.from(preferences['likes'] ?? []);
              final dislikes = List<String>.from(preferences['dislikes'] ?? []);

              final ingredientItem = {
                'name': data['name'] ?? '알 수 없는 식품',
                'category': data['category'] ?? '기타',
                'imagePath': data['imagePath'],
                'likesCount': likes.length,
                'dislikesCount': dislikes.length,
              };

              if (likes.contains(currentUserId)) {
                likedItems.add(ingredientItem);
              }
              if (dislikes.contains(currentUserId)) {
                dislikedItems.add(ingredientItem);
              }
            }
          }
        }
      }

      print('📊 선호도 데이터 처리 완료: 좋아요 ${likedItems.length}개, 싫어요 ${dislikedItems.length}개');
      
      setState(() {
        _likedItems = likedItems;
        _dislikedItems = dislikedItems;
        _preferencesData = {
          'totalLikes': likedItems.length,
          'totalDislikes': dislikedItems.length,
          'lastUpdated': Timestamp.now(),
        };
        _isLoading = false;
      });

      print('✅ 선호도 로드 완료 및 setState 호출됨');
      print('   _likedItems.length: ${_likedItems.length}');
      print('   _dislikedItems.length: ${_dislikedItems.length}');
      print('   _isLoading: $_isLoading');
    } catch (e) {
      print('선호도 데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '선호도 통계',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.grey[600]),
            onPressed: _loadPreferencesData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '선호도 데이터를 불러오는 중...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPreferencesData,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 전체 통계 카드
                    _buildOverallStatsCard(),
                    
                    SizedBox(height: 24),
                    
                    // 좋아요 한 식품
                    _buildPreferenceSection(
                      title: '좋아요 한 식품',
                      icon: Icons.favorite,
                      color: Colors.red[300]!,
                      items: _likedItems,
                      emptyMessage: '아직 좋아요를 누른 식품이 없습니다.',
                    ),
                    
                    SizedBox(height: 24),
                    
                    // 싫어요 한 식품
                    _buildPreferenceSection(
                      title: '싫어요 한 식품',
                      icon: Icons.thumb_down,
                      color: Colors.blue[400]!,
                      items: _dislikedItems,
                      emptyMessage: '아직 싫어요를 누른 식품이 없습니다.',
                    ),
                    
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverallStatsCard() {
    final totalLikes = _likedItems.length;
    final totalDislikes = _dislikedItems.length;
    final totalActions = totalLikes + totalDislikes;
    
    print('🎨 카드 빌드 중: 좋아요=$totalLikes, 싫어요=$totalDislikes, _isLoading=$_isLoading');

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child:           Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  '좋아요',
                  totalLikes.toString(),
                  Icons.favorite,
                  Colors.red[300]!,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey[200],
              ),
              Expanded(
                child: _buildStatItem(
                  '싫어요',
                  totalDislikes.toString(),
                  Icons.thumb_down,
                  Colors.blue[400]!,
                ),
              ),
              Container(
                width: 1,
                height: 50,
                color: Colors.grey[200],
              ),
              Expanded(
                child: _buildStatItem(
                  '전체',
                  totalActions.toString(),
                  Icons.bar_chart_rounded,
                  Colors.orange[400]!,
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 10),
        Text(
          value,
          style: TextStyle(
            color: Colors.black87,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPreferenceSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    required String emptyMessage,
  }) {
    // 최대 3개만 미리보기
    final previewItems = items.take(3).toList();
    final hasMore = items.length > 3;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 제목 (카드 밖으로)
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}개',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // 카드
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: items.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        color: Colors.grey[300],
                        size: 56,
                      ),
                      SizedBox(height: 16),
                      Text(
                        emptyMessage,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // 미리보기 3개
                    ...List.generate(
                      previewItems.length,
                      (index) => _buildPreferenceItem(
                        previewItems[index],
                        color,
                        index == 0,
                        index == previewItems.length - 1 && !hasMore,
                      ),
                    ),
                    
                    // 더보기 버튼
                    if (hasMore)
                      InkWell(
                        onTap: () => _showAllItems(context, title, items, color, icon),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Colors.grey[100]!, width: 1),
                            ),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '더보기',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(
                                '(${items.length - 3}개)',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: Colors.blue[600],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  // 전체 목록 보기 전체 화면
  void _showAllItems(
    BuildContext context,
    String title,
    List<Map<String, dynamic>> items,
    Color color,
    IconData icon,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PreferenceFullListScreen(
          title: title,
          items: items,
          color: color,
          icon: icon,
        ),
      ),
    );
  }

  Widget _buildPreferenceItem(
    Map<String, dynamic> item, 
    Color color, 
    bool isFirst,
    bool isLast,
  ) {
    final itemName = item['name'] ?? '알 수 없는 식품';
    final category = item['category'] ?? '기타';
    final likesCount = item['likesCount'] ?? 0;
    final dislikesCount = item['dislikesCount'] ?? 0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: isFirst ? null : Border(
          top: BorderSide(color: Colors.grey[100]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 식품 이미지/아이콘
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.5),
              child: item['imagePath'] != null && item['imagePath'].toString().isNotEmpty
                  ? IngredientImageWidget(
                      imagePath: item['imagePath'],
                      width: 56,
                      height: 56,
                    )
                  : Center(
                      child: Text(
                        _getEmojiForFood(itemName),
                        style: TextStyle(fontSize: 28),
                      ),
                    ),
            ),
          ),
          SizedBox(width: 14),
          
          // 정보
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  itemName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          SizedBox(width: 12),
          
          // 좋아요/싫어요 카운트
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite, color: Colors.red[300], size: 16),
                  SizedBox(width: 4),
                  Text(
                    '$likesCount',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.thumb_down, color: Colors.blue[400], size: 16),
                  SizedBox(width: 4),
                  Text(
                    '$dislikesCount',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 음식 이름으로 이모지 반환
  String _getEmojiForFood(String foodName) {
    final name = foodName.toLowerCase();

    // 유제품/음료 (우선순위 높임)
    if (name.contains('우유') || name.contains('밀크') || name.contains('milk')) return '🥛';
    if (name.contains('요거트') || name.contains('요구르트') || name.contains('yogurt')) return '🥛';
    if (name.contains('치즈') || name.contains('cheese')) return '🧀';
    if (name.contains('버터') || name.contains('butter')) return '🧈';
    
    // 음료
    if (name.contains('커피') || name.contains('coffee') || name.contains('카페')) return '☕';
    if (name.contains('차') || name.contains('tea') || name.contains('티')) return '🍵';
    if (name.contains('주스') || name.contains('juice')) return '🧃';
    if (name.contains('콜라') || name.contains('cola') || name.contains('코카')) return '🥤';
    if (name.contains('사이다') || name.contains('cider') || name.contains('sprite') || name.contains('스프라이트')) return '🥤';
    if (name.contains('물') || name.contains('water')) return '💧';
    if (name.contains('소주') || name.contains('soju')) return '🍶';
    if (name.contains('맥주') || name.contains('beer')) return '🍺';
    if (name.contains('와인') || name.contains('wine')) return '🍷';
    if (name.contains('하이볼') || name.contains('highball')) return '🥃';
    if (name.contains('위스키') || name.contains('whiskey') || name.contains('whisky')) return '🥃';
    if (name.contains('막걸리')) return '🍶';
    if (name.contains('보드카') || name.contains('vodka')) return '🍸';
    if (name.contains('진') || name.contains('gin')) return '🍸';
    if (name.contains('럼') || name.contains('rum')) return '🍹';
    if (name.contains('테킬라') || name.contains('tequila')) return '🍹';
    if (name.contains('샴페인') || name.contains('champagne')) return '🍾';
    if (name.contains('스파클링') || name.contains('sparkling')) return '🍾';
    if (name.contains('카스') || name.contains('cass')) return '🍺';
    if (name.contains('하이트') || name.contains('hite')) return '🍺';
    if (name.contains('테라') || name.contains('terra')) return '🍺';
    if (name.contains('참이슬')) return '🍶';
    if (name.contains('처음처럼')) return '🍶';
    if (name.contains('레드와인')) return '🍷';
    if (name.contains('화이트와인')) return '🍷';
    if (name.contains('펩시') || name.contains('pepsi')) return '🥤';
    if (name.contains('게토레이') || name.contains('gatorade')) return '🥤';
    if (name.contains('포카리') || name.contains('pocari')) return '🥤';
    if (name.contains('핫식스') || name.contains('hot6')) return '🥫';
    if (name.contains('레드불') || name.contains('redbull')) return '🥫';
    if (name.contains('몬스터') || name.contains('monster')) return '🥫';
    if (name.contains('탄산수')) return '💧';
    if (name.contains('토닉워터') || name.contains('tonic')) return '🥤';

    // 과일
    if (name.contains('사과') || name.contains('apple')) return '🍎';
    if (name.contains('바나나') || name.contains('banana')) return '🍌';
    if (name.contains('오렌지') || name.contains('orange')) return '🍊';
    if (name.contains('포도') || name.contains('grape')) return '🍇';
    if (name.contains('딸기') || name.contains('strawberry')) return '🍓';
    if (name.contains('수박') || name.contains('watermelon')) return '🍉';
    if (name.contains('복숭아') || name.contains('peach')) return '🍑';
    if (name.contains('체리') || name.contains('cherry')) return '🍒';
    if (name.contains('키위') || name.contains('kiwi')) return '🥝';
    if (name.contains('망고') || name.contains('mango')) return '🥭';
    if (name.contains('파인애플') || name.contains('pineapple')) return '🍍';
    if (name.contains('레몬') || name.contains('lemon')) return '🍋';
    if (name.contains('배') || name.contains('pear')) return '🍐';

    // 채소
    if (name.contains('토마토') || name.contains('tomato')) return '🍅';
    if (name.contains('당근') || name.contains('carrot')) return '🥕';
    if (name.contains('브로콜리') || name.contains('broccoli')) return '🥦';
    if (name.contains('양파') || name.contains('onion')) return '🧅';
    if (name.contains('마늘') || name.contains('garlic')) return '🧄';
    if (name.contains('감자') || name.contains('potato')) return '🥔';
    if (name.contains('고구마') || name.contains('sweet potato')) return '🍠';
    if (name.contains('옥수수') || name.contains('corn')) return '🌽';
    if (name.contains('상추') || name.contains('lettuce') || name.contains('샐러드')) return '🥬';
    if (name.contains('오이') || name.contains('cucumber')) return '🥒';
    if (name.contains('호박') || name.contains('pumpkin')) return '🎃';
    if (name.contains('버섯') || name.contains('mushroom')) return '🍄';

    // 육류/해산물
    if (name.contains('소고기') || name.contains('beef') || name.contains('steak')) return '🥩';
    if (name.contains('돼지') || name.contains('pork') || name.contains('삼겹살')) return '🥓';
    if (name.contains('닭') || name.contains('chicken')) return '🍗';
    if (name.contains('계란') || name.contains('달걀') || name.contains('egg')) return '🥚';
    if (name.contains('생선') || name.contains('fish')) return '🐟';
    if (name.contains('새우') || name.contains('shrimp')) return '🦐';
    if (name.contains('게') || name.contains('crab')) return '🦀';
    if (name.contains('오징어') || name.contains('squid')) return '🦑';
    if (name.contains('조개') || name.contains('clam')) return '🦪';

    // 빵/디저트
    if (name.contains('빵') || name.contains('bread')) return '🍞';
    if (name.contains('케이크') || name.contains('cake')) return '🍰';
    if (name.contains('쿠키') || name.contains('cookie')) return '🍪';
    if (name.contains('초코') || name.contains('chocolate') || name.contains('choco')) return '🍫';
    if (name.contains('아이스크림') || name.contains('ice cream')) return '🍦';
    if (name.contains('도넛') || name.contains('donut')) return '🍩';
    if (name.contains('피자') || name.contains('pizza')) return '🍕';
    if (name.contains('햄버거') || name.contains('burger')) return '🍔';

    // 한식
    if (name.contains('김치') || name.contains('kimchi')) return '🥬';
    if (name.contains('밥') || name.contains('rice') || name.contains('쌀')) return '🍚';
    if (name.contains('라면') || name.contains('ramen') || name.contains('noodle')) return '🍜';
    if (name.contains('떡') || name.contains('rice cake')) return '🍡';
    if (name.contains('만두') || name.contains('dumpling')) return '🥟';
    if (name.contains('국') || name.contains('soup') || name.contains('찌개')) return '🍲';

    // 조미료/기타
    if (name.contains('소금') || name.contains('salt')) return '🧂';
    if (name.contains('설탕') || name.contains('sugar')) return '🍬';
    if (name.contains('꿀') || name.contains('honey')) return '🍯';
    if (name.contains('잼') || name.contains('jam')) return '🍓';

    // 신선식품 특수 케이스
    if (name.contains('신선식품') || name.contains('신선제품')) return '🍙';

    // 기본 아이콘
    return '🥘';
  }

  // 카테고리에 따른 아이콘 반환
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case '육류':
        return Icons.set_meal;
      case '채소':
        return Icons.eco;
      case '과일':
        return Icons.apple;
      case '유제품':
        return Icons.local_drink;
      case '음료':
        return Icons.local_cafe;
      case '냉동식품':
        return Icons.ac_unit;
      case '조미료':
        return Icons.restaurant;
      case '간식':
        return Icons.cake;
      default:
        return Icons.fastfood;
    }
  }
}

// 전체 목록 화면
class _PreferenceFullListScreen extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final Color color;
  final IconData icon;

  const _PreferenceFullListScreen({
    Key? key,
    required this.title,
    required this.items,
    required this.color,
    required this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 총 개수 표시
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.blue[400],
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    '총',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 4),
                  Text(
                    '${items.length}개',
                    style: TextStyle(
                      color: Colors.blue[500],
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // 리스트
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: items.length,
              separatorBuilder: (context, index) => SizedBox(height: 10),
              itemBuilder: (context, index) {
          final item = items[index];
          final itemName = item['name'] ?? '알 수 없는 식품';
          final likesCount = item['likesCount'] ?? 0;
          final dislikesCount = item['dislikesCount'] ?? 0;

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey[200]!, width: 1),
            ),
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Row(
                children: [
                  // 식품 이미지/아이콘
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: item['imagePath'] != null && item['imagePath'].toString().isNotEmpty
                          ? IngredientImageWidget(
                              imagePath: item['imagePath'],
                              width: 52,
                              height: 52,
                            )
                          : Center(
                              child: Text(
                                _getEmojiForFood(itemName),
                                style: TextStyle(fontSize: 26),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: 12),
                  
                  // 정보
                  Expanded(
                    child: Text(
                      itemName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  
                  SizedBox(width: 10),
                  
                  // 좋아요/싫어요 카운트
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite, color: Colors.red[300], size: 15),
                          SizedBox(width: 3),
                          Text(
                            '$likesCount',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.thumb_down, color: Colors.blue[400], size: 15),
                          SizedBox(width: 3),
                          Text(
                            '$dislikesCount',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
          ),
        ],
      ),
    );
  }

  // 음식 이름으로 이모지 반환
  String _getEmojiForFood(String foodName) {
    final name = foodName.toLowerCase();

    // 유제품/음료 (우선순위 높임)
    if (name.contains('우유') || name.contains('밀크') || name.contains('milk')) return '🥛';
    if (name.contains('요거트') || name.contains('요구르트') || name.contains('yogurt')) return '🥛';
    if (name.contains('치즈') || name.contains('cheese')) return '🧀';
    if (name.contains('버터') || name.contains('butter')) return '🧈';
    
    // 음료
    if (name.contains('커피') || name.contains('coffee') || name.contains('카페')) return '☕';
    if (name.contains('차') || name.contains('tea') || name.contains('티')) return '🍵';
    if (name.contains('주스') || name.contains('juice')) return '🧃';
    if (name.contains('콜라') || name.contains('cola') || name.contains('코카')) return '🥤';
    if (name.contains('사이다') || name.contains('cider') || name.contains('sprite') || name.contains('스프라이트')) return '🥤';
    if (name.contains('물') || name.contains('water')) return '💧';
    if (name.contains('소주') || name.contains('soju')) return '🍶';
    if (name.contains('맥주') || name.contains('beer')) return '🍺';
    if (name.contains('와인') || name.contains('wine')) return '🍷';
    if (name.contains('하이볼') || name.contains('highball')) return '🥃';
    if (name.contains('위스키') || name.contains('whiskey') || name.contains('whisky')) return '🥃';
    if (name.contains('막걸리')) return '🍶';
    if (name.contains('보드카') || name.contains('vodka')) return '🍸';
    if (name.contains('진') || name.contains('gin')) return '🍸';
    if (name.contains('럼') || name.contains('rum')) return '🍹';
    if (name.contains('테킬라') || name.contains('tequila')) return '🍹';
    if (name.contains('샴페인') || name.contains('champagne')) return '🍾';
    if (name.contains('스파클링') || name.contains('sparkling')) return '🍾';
    if (name.contains('카스') || name.contains('cass')) return '🍺';
    if (name.contains('하이트') || name.contains('hite')) return '🍺';
    if (name.contains('테라') || name.contains('terra')) return '🍺';
    if (name.contains('참이슬')) return '🍶';
    if (name.contains('처음처럼')) return '🍶';
    if (name.contains('레드와인')) return '🍷';
    if (name.contains('화이트와인')) return '🍷';
    if (name.contains('펩시') || name.contains('pepsi')) return '🥤';
    if (name.contains('게토레이') || name.contains('gatorade')) return '🥤';
    if (name.contains('포카리') || name.contains('pocari')) return '🥤';
    if (name.contains('핫식스') || name.contains('hot6')) return '🥫';
    if (name.contains('레드불') || name.contains('redbull')) return '🥫';
    if (name.contains('몬스터') || name.contains('monster')) return '🥫';
    if (name.contains('탄산수')) return '💧';
    if (name.contains('토닉워터') || name.contains('tonic')) return '🥤';

    // 과일
    if (name.contains('사과') || name.contains('apple')) return '🍎';
    if (name.contains('바나나') || name.contains('banana')) return '🍌';
    if (name.contains('오렌지') || name.contains('orange')) return '🍊';
    if (name.contains('포도') || name.contains('grape')) return '🍇';
    if (name.contains('딸기') || name.contains('strawberry')) return '🍓';
    if (name.contains('수박') || name.contains('watermelon')) return '🍉';
    if (name.contains('복숭아') || name.contains('peach')) return '🍑';
    if (name.contains('체리') || name.contains('cherry')) return '🍒';
    if (name.contains('키위') || name.contains('kiwi')) return '🥝';
    if (name.contains('망고') || name.contains('mango')) return '🥭';
    if (name.contains('파인애플') || name.contains('pineapple')) return '🍍';
    if (name.contains('레몬') || name.contains('lemon')) return '🍋';
    if (name.contains('배') || name.contains('pear')) return '🍐';

    // 채소
    if (name.contains('토마토') || name.contains('tomato')) return '🍅';
    if (name.contains('당근') || name.contains('carrot')) return '🥕';
    if (name.contains('브로콜리') || name.contains('broccoli')) return '🥦';
    if (name.contains('양파') || name.contains('onion')) return '🧅';
    if (name.contains('마늘') || name.contains('garlic')) return '🧄';
    if (name.contains('감자') || name.contains('potato')) return '🥔';
    if (name.contains('고구마') || name.contains('sweet potato')) return '🍠';
    if (name.contains('옥수수') || name.contains('corn')) return '🌽';
    if (name.contains('상추') || name.contains('lettuce') || name.contains('샐러드')) return '🥬';
    if (name.contains('오이') || name.contains('cucumber')) return '🥒';
    if (name.contains('호박') || name.contains('pumpkin')) return '🎃';
    if (name.contains('버섯') || name.contains('mushroom')) return '🍄';

    // 육류/해산물
    if (name.contains('소고기') || name.contains('beef') || name.contains('steak')) return '🥩';
    if (name.contains('돼지') || name.contains('pork') || name.contains('삼겹살')) return '🥓';
    if (name.contains('닭') || name.contains('chicken')) return '🍗';
    if (name.contains('계란') || name.contains('달걀') || name.contains('egg')) return '🥚';
    if (name.contains('생선') || name.contains('fish')) return '🐟';
    if (name.contains('새우') || name.contains('shrimp')) return '🦐';
    if (name.contains('게') || name.contains('crab')) return '🦀';
    if (name.contains('오징어') || name.contains('squid')) return '🦑';
    if (name.contains('조개') || name.contains('clam')) return '🦪';

    // 빵/디저트
    if (name.contains('빵') || name.contains('bread')) return '🍞';
    if (name.contains('케이크') || name.contains('cake')) return '🍰';
    if (name.contains('쿠키') || name.contains('cookie')) return '🍪';
    if (name.contains('초코') || name.contains('chocolate') || name.contains('choco')) return '🍫';
    if (name.contains('아이스크림') || name.contains('ice cream')) return '🍦';
    if (name.contains('도넛') || name.contains('donut')) return '🍩';
    if (name.contains('피자') || name.contains('pizza')) return '🍕';
    if (name.contains('햄버거') || name.contains('burger')) return '🍔';

    // 한식
    if (name.contains('김치') || name.contains('kimchi')) return '🥬';
    if (name.contains('밥') || name.contains('rice') || name.contains('쌀')) return '🍚';
    if (name.contains('라면') || name.contains('ramen') || name.contains('noodle')) return '🍜';
    if (name.contains('떡') || name.contains('rice cake')) return '🍡';
    if (name.contains('만두') || name.contains('dumpling')) return '🥟';
    if (name.contains('국') || name.contains('soup') || name.contains('찌개')) return '🍲';

    // 조미료/기타
    if (name.contains('소금') || name.contains('salt')) return '🧂';
    if (name.contains('설탕') || name.contains('sugar')) return '🍬';
    if (name.contains('꿀') || name.contains('honey')) return '🍯';
    if (name.contains('잼') || name.contains('jam')) return '🍓';

    // 신선식품 특수 케이스
    if (name.contains('신선식품') || name.contains('신선제품')) return '🍙';

    // 기본 아이콘
    return '🥘';
  }
}


