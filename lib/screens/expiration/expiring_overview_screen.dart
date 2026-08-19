import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../refrigerator/ingredients_screen.dart';
import '../../services/home_service.dart';
import '../main_screen.dart';
import '../../services/statistics_service.dart';
import '../../models/statistics.dart';
import '../refrigerator/constants/food_category_icons.dart';
import '../refrigerator/widgets/ingredient_image_widget.dart';

class ExpiringOverviewScreen extends StatefulWidget {
  final String? roomId;
  final String? refrigeratorName;
  final int initialTab; // 0: 임박, 1: 만료
  
  const ExpiringOverviewScreen({
    super.key,
    this.roomId,
    this.refrigeratorName,
    this.initialTab = 0,
  });

  @override
  State<ExpiringOverviewScreen> createState() => _ExpiringOverviewScreenState();
}

class _ExpiringOverviewScreenState extends State<ExpiringOverviewScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  // 캐시: 한 번 불러온 임박/만료 식품 리스트를 보관해서
  // 소비/폐기 시 즉시 화면에 반영하고, 불필요한 전체 새로고침을 줄이기 위함
  List<_ExpiringItem> _cachedExpiringItems = [];
  List<_ExpiringItem> _cachedExpiredItems = [];
  bool _hasLoadedExpiring = false;
  bool _hasLoadedExpired = false;

  // 쿠팡 이동 이후 복귀 시 구매 여부를 물어볼 식품
  _ExpiringItem? _pendingCoupangItem;
  bool _isWaitingCoupangReturn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(
      length: 2, 
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  // 쿠팡 구매 여부 상태 표시 위젯 (카드 안 뱃지 전용)
  Widget _buildCoupangPurchaseStatusWidget(BuildContext context, _ExpiringItem item) {
    final status = item.coupangPurchaseStatus;

    if (status == null) {
      // 아직 쿠팡 링크를 타지 않았거나, 구매 여부를 선택하지 않은 경우 → 아무 것도 표시하지 않음
      return const SizedBox.shrink();
    }

    String label;
    Color textColor;
    Color backgroundColor;

    if (status == 'purchased') {
      label = '구매';
      textColor = const Color(0xFF2563EB);
      backgroundColor = const Color(0xFFE0ECFF);
    } else {
      label = '미구매';
      textColor = Colors.grey[700]!;
      backgroundColor = Colors.grey[100]!;
    }

    // 뱃지를 탭하면 언제든 팝업을 다시 띄워서 수정 가능
    return GestureDetector(
      onTap: () => _showCoupangPurchaseDialog(item),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 쿠팡으로 나갔다가 앱으로 다시 돌아왔을 때만 구매 여부 다이얼로그 표시
    if (state == AppLifecycleState.resumed &&
        _isWaitingCoupangReturn &&
        _pendingCoupangItem != null &&
        mounted) {
      _isWaitingCoupangReturn = false;
      _showCoupangPurchaseDialog(_pendingCoupangItem!);
    }
  }

  // 임박 식품만 가져오기 (daysLeft >= 0 && daysLeft <= 3)
  Future<List<_ExpiringItem>> _fetchExpiringItems() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    try {
      final now = DateTime.now();
      final items = <_ExpiringItem>[];

      // 특정 냉장고가 지정된 경우
      if (widget.roomId != null && widget.refrigeratorName != null) {
        // 해당 냉장고에서만 식품 가져오기
        final refrigeratorSnapshot = await FirebaseFirestore.instance
            .collection('Refrigerators')
            .where('room_id', isEqualTo: widget.roomId)
            .where('name', isEqualTo: widget.refrigeratorName)
            .limit(1)
            .get();

        if (refrigeratorSnapshot.docs.isNotEmpty) {
          final refrigeratorDoc = refrigeratorSnapshot.docs.first;
          final refrigeratorData = refrigeratorDoc.data();
          
          // 냉장고의 칸 이름들 가져오기
          final compartmentNames = List<String>.from(
            refrigeratorData['compartment_names'] ?? []
          );

          // 각 칸에서 재료 가져오기
          for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
            final compartmentName = compartmentNames[compartmentIndex];
            
            final ingredientsSnapshot = await refrigeratorDoc.reference
                .collection('compartments')
                .doc(compartmentIndex.toString())
                .collection('ingredients')
                .get();

            for (final ingredientDoc in ingredientsSnapshot.docs) {
              final ingredientData = ingredientDoc.data();
              final dynamic expiryField = ingredientData['expiryDate'];
              
              DateTime? expiryDate;
              if (expiryField is Timestamp) {
                // UTC 자정에서 로컬 날짜로 변환
                final utcDate = expiryField.toDate();
                expiryDate = DateTime(utcDate.year, utcDate.month, utcDate.day);
              } else if (expiryField is String) {
                expiryDate = DateTime.tryParse(expiryField);
              }

              if (expiryDate == null) continue;

              final daysLeft = DateTime(expiryDate.year, expiryDate.month, expiryDate.day)
                  .difference(DateTime(now.year, now.month, now.day))
                  .inDays;

              // 임박 식품만 (0 <= daysLeft <= 3)
              if (daysLeft >= 0 && daysLeft <= 3) {
                items.add(_ExpiringItem(
                  id: ingredientDoc.id,
                  name: ingredientData['name'] ?? '',
                  imagePath: ingredientData['imagePath'],
                  expiryDate: expiryDate,
                  compartmentName: compartmentName,
                  refrigeratorName: widget.refrigeratorName!,
                  roomId: widget.roomId!,
                  compartmentIndex: compartmentIndex,
                  coupangPurchaseStatus:
                      ingredientData['coupangPurchaseStatus'] as String?,
                ));
              }
            }
          }
        }
      } else {
        // 냉장고가 지정되지 않은 경우 - HomeService와 동일한 로직 사용 (일관된 개수/목록)
        final homeService = HomeService();
        final allItems = await homeService.getExpiringItems(maxDays: 365);

        for (final hItem in allItems) {
          // 임박 식품만 (0 <= daysLeft <= 3)
          if (hItem.daysLeft >= 0 && hItem.daysLeft <= 3) {
            items.add(_ExpiringItem(
              id: hItem.id,
              name: hItem.name,
              imagePath: hItem.imagePath,
              expiryDate: hItem.expiryDate,
              compartmentName: hItem.compartmentName,
              refrigeratorName: hItem.refrigeratorName,
              roomId: hItem.roomId,
              compartmentIndex: hItem.compartmentIndex,
              coupangPurchaseStatus: hItem.coupangPurchaseStatus,
            ));
          }
        }
      }

      items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      // 캐시에 저장하여 이후 소비/폐기 시 즉시 반영
      _cachedExpiringItems = List<_ExpiringItem>.from(items);
      _hasLoadedExpiring = true;
      return items;
    } catch (e) {
      debugPrint('🔥 만료 예정 식품 로드 오류: $e');
      return [];
    }
  }

  // 만료 식품만 가져오기 (daysLeft < 0)
  Future<List<_ExpiringItem>> _fetchExpiredItems() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    try {
      final now = DateTime.now();
      final items = <_ExpiringItem>[];

      // 특정 냉장고가 지정된 경우
      if (widget.roomId != null && widget.refrigeratorName != null) {
        final refrigeratorSnapshot = await FirebaseFirestore.instance
            .collection('Refrigerators')
            .where('room_id', isEqualTo: widget.roomId)
            .where('name', isEqualTo: widget.refrigeratorName)
            .limit(1)
            .get();

        if (refrigeratorSnapshot.docs.isNotEmpty) {
          final refrigeratorDoc = refrigeratorSnapshot.docs.first;
          final refrigeratorData = refrigeratorDoc.data();
          
          final compartmentNames = List<String>.from(
            refrigeratorData['compartment_names'] ?? []
          );

          for (int compartmentIndex = 0; compartmentIndex < compartmentNames.length; compartmentIndex++) {
            final compartmentName = compartmentNames[compartmentIndex];
            
            final ingredientsSnapshot = await refrigeratorDoc.reference
                .collection('compartments')
                .doc(compartmentIndex.toString())
                .collection('ingredients')
                .get();

            for (final ingredientDoc in ingredientsSnapshot.docs) {
              final ingredientData = ingredientDoc.data();
              final dynamic expiryField = ingredientData['expiryDate'];
              
              DateTime? expiryDate;
              if (expiryField is Timestamp) {
                // UTC 자정에서 로컬 날짜로 변환
                final utcDate = expiryField.toDate();
                expiryDate = DateTime(utcDate.year, utcDate.month, utcDate.day);
              } else if (expiryField is String) {
                expiryDate = DateTime.tryParse(expiryField);
              }

              if (expiryDate == null) continue;

              final daysLeft = DateTime(expiryDate.year, expiryDate.month, expiryDate.day)
                  .difference(DateTime(now.year, now.month, now.day))
                  .inDays;

              // 만료 식품만 (daysLeft < 0)
              if (daysLeft < 0) {
                items.add(_ExpiringItem(
                  id: ingredientDoc.id,
                  name: ingredientData['name'] ?? '',
                  imagePath: ingredientData['imagePath'],
                  expiryDate: expiryDate,
                  compartmentName: compartmentName,
                  refrigeratorName: widget.refrigeratorName!,
                  roomId: widget.roomId!,
                  compartmentIndex: compartmentIndex,
                  coupangPurchaseStatus:
                      ingredientData['coupangPurchaseStatus'] as String?,
                ));
              }
            }
          }
        }
      } else {
        // 전체 조회 - HomeService와 동일한 로직 사용 (일관된 개수/목록)
        final homeService = HomeService();
        final allItems = await homeService.getExpiringItems(maxDays: 365);

        for (final hItem in allItems) {
          // 만료 식품만 (daysLeft < 0)
          if (hItem.daysLeft < 0) {
            items.add(_ExpiringItem(
              id: hItem.id,
              name: hItem.name,
              imagePath: hItem.imagePath,
              expiryDate: hItem.expiryDate,
              compartmentName: hItem.compartmentName,
              refrigeratorName: hItem.refrigeratorName,
              roomId: hItem.roomId,
              compartmentIndex: hItem.compartmentIndex,
              coupangPurchaseStatus: hItem.coupangPurchaseStatus,
            ));
          }
        }
      }

      items.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
      // 캐시에 저장하여 이후 소비/폐기 시 즉시 반영
      _cachedExpiredItems = List<_ExpiringItem>.from(items);
      _hasLoadedExpired = true;
      return items;
    } catch (e) {
      debugPrint('🔥 만료 식품 로드 오류: $e');
      return [];
    }
  }

  String _formatDday(int daysLeft) {
    if (daysLeft < 0) return 'D+${-daysLeft}';
    if (daysLeft == 0) return 'D-Day';
    return 'D-$daysLeft';
  }

  Color _ddayColor(int daysLeft) {
    // 냉장고와 동일한 색상 스키마
    if (daysLeft < 0) {
      return Colors.red[600]!; // 만료됨 - 빨강
    } else if (daysLeft == 0) {
      return Colors.orange[600]!; // 오늘 - 주황
    } else if (daysLeft == 1) {
      return Colors.amber[600]!; // 내일 - 노랑
    } else if (daysLeft <= 3) {
      return Colors.yellow[700]!; // 3일 이내 - 연노랑
    } else {
      return Colors.green[600]!; // 일반 - 초록
    }
  }

  // 이모지 가져오기 (개선된 매칭 로직)
  String _getEmojiForFood(String foodName) {
    final name = foodName.toLowerCase().trim();
    
    // 신선식품 특별 처리
    if (name == '신선식품' || name == '신선제품') return '🍙';
    
    // 유제품 (우선순위 높음 - 복합 단어 매칭)
    if (name.contains('우유') || name.contains('milk') || name.contains('밀크')) return '🥛';
    if (name.contains('치즈') || name.contains('cheese') || name.contains('체다') || name.contains('모짜렐라')) return '🧀';
    if (name.contains('요구르트') || name.contains('yogurt') || name.contains('요거트') || name.contains('야쿠르트')) return '🥛';
    if (name.contains('버터') || name.contains('butter')) return '🧈';
    if (name.contains('아이스크림') || name.contains('ice cream') || name.contains('빙수')) return '🍦';
    if (name.contains('크림') || name.contains('cream')) return '🥛';
    
    // 음료 (우선순위 높음)
    if (name.contains('커피') || name.contains('coffee') || name.contains('아메리카노') || name.contains('라떼')) return '☕';
    if (name.contains('차') || name.contains('tea') || name.contains('티') || name.contains('녹차') || name.contains('홍차')) return '🍵';
    if (name.contains('주스') || name.contains('juice')) return '🧃';
    if (name.contains('에이드') || name.contains('ade') || name.contains('레모네이드')) return '🍹';
    if (name.contains('스무디') || name.contains('smoothie')) return '🥤';
    if (name.contains('쉐이크') || name.contains('shake')) return '🥤';
    if (name.contains('탄산') || name.contains('콜라') || name.contains('사이다') || name.contains('coke') || name.contains('sprite') || name.contains('펩시')) return '🥤';
    if (name.contains('소주') || name.contains('soju') || name.contains('참이슬') || name.contains('처음처럼')) return '🍶';
    if (name.contains('맥주') || name.contains('beer') || name.contains('카스') || name.contains('하이트') || name.contains('테라')) return '🍺';
    if (name.contains('와인') || name.contains('wine') || name.contains('레드와인') || name.contains('화이트와인')) return '🍷';
    if (name.contains('칵테일') || name.contains('cocktail') || name.contains('하이볼') || name.contains('highball') || 
        name.contains('모히또') || name.contains('mojito') || name.contains('마가리타') || name.contains('margarita')) return '🍸';
    if (name.contains('위스키') || name.contains('whisky') || name.contains('whiskey') || name.contains('버번')) return '🥃';
    if (name.contains('보드카') || name.contains('vodka')) return '🍸';
    if (name.contains('진') || name.contains('gin') || name.contains('럼') || name.contains('rum') || name.contains('테킬라') || name.contains('tequila')) return '🍸';
    if (name.contains('샴페인') || name.contains('champagne') || name.contains('스파클링')) return '🍾';
    if (name.contains('막걸리')) return '🍶';
    if (name.contains('청하') || name.contains('정종') || name.contains('사케') || name.contains('sake')) return '🍶';
    if (name.contains('물') || name.contains('water') || name.contains('생수') || name.contains('탄산수') || name.contains('토닉워터')) return '💧';
    if (name.contains('이온음료') || name.contains('게토레이') || name.contains('포카리')) return '🥤';
    if (name.contains('에너지드링크') || name.contains('핫식스') || name.contains('레드불') || name.contains('몬스터')) return '🥤';
    
    // 과일류
    if (name.contains('사과')) return '🍎';
    if (name.contains('바나나')) return '🍌';
    if (name.contains('딸기')) return '🍓';
    if (name.contains('수박')) return '🍉';
    if (name.contains('포도')) return '🍇';
    if (name.contains('오렌지') || name.contains('귤') || name.contains('감귤') || name.contains('천혜향')) return '🍊';
    if (name.contains('레몬') || name.contains('라임')) return '🍋';
    if (name.contains('복숭아')) return '🍑';
    if (name.contains('체리') || name.contains('앵두')) return '🍒';
    if (name.contains('키위')) return '🥝';
    if (name.contains('파인애플')) return '🍍';
    if (name.contains('망고')) return '🥭';
    if (name.contains('배') && !name.contains('배추') && !name.contains('양배추')) return '🍐';
    if (name.contains('멜론') || name.contains('참외')) return '🍈';
    if (name.contains('블루베리')) return '🫐';
    if (name.contains('코코넛')) return '🥥';
    if (name.contains('아보카도')) return '🥑';
    if (name.contains('과일') || name.contains('fruit')) return '🍎';
    
    // 채소류
    if (name.contains('토마토')) return '🍅';
    if (name.contains('당근')) return '🥕';
    if (name.contains('브로콜리')) return '🥦';
    if (name.contains('양파')) return '🧅';
    if (name.contains('마늘')) return '🧄';
    if (name.contains('고추') || name.contains('피망') || name.contains('파프리카') || name.contains('청양고추')) return '🌶️';
    if (name.contains('감자') || name.contains('potato')) return '🥔';
    if (name.contains('옥수수') || name.contains('corn')) return '🌽';
    if (name.contains('가지')) return '🍆';
    if (name.contains('양배추') || name.contains('배추') || name.contains('cabbage')) return '🥬';
    if (name.contains('상추') || name.contains('샐러드') || name.contains('lettuce') || name.contains('salad')) return '🥗';
    if (name.contains('오이') || name.contains('cucumber')) return '🥒';
    if (name.contains('버섯') || name.contains('mushroom') || name.contains('표고') || name.contains('새송이')) return '🍄';
    if (name.contains('호박') || name.contains('애호박') || name.contains('단호박')) return '🎃';
    if (name.contains('무') && !name.contains('무화과')) return '🥬';
    if (name.contains('파') || name.contains('대파') || name.contains('쪽파')) return '🥬';
    if (name.contains('김치') || name.contains('kimchi')) return '🥬';
    if (name.contains('야채') || name.contains('채소') || name.contains('vegetable')) return '🥬';
    
    // 육류
    if (name.contains('소고기') || name.contains('쇠고기') || name.contains('beef') || name.contains('steak')) return '🥩';
    if (name.contains('돼지고기') || name.contains('삼겹살') || name.contains('pork') || name.contains('목살') || name.contains('앞다리')) return '🥓';
    if (name.contains('닭고기') || name.contains('chicken') || name.contains('치킨') || name.contains('닭') || name.contains('계육')) return '🍗';
    if (name.contains('베이컨') || name.contains('bacon')) return '🥓';
    if (name.contains('햄') || name.contains('ham') || name.contains('스팸')) return '🍖';
    if (name.contains('소시지') || name.contains('sausage') || name.contains('핫도그')) return '🌭';
    if (name.contains('갈비') || name.contains('ribs')) return '🍖';
    if (name.contains('고기') || name.contains('meat')) return '🥩';
    
    // 해산물
    if (name.contains('생선') || name.contains('fish') || name.contains('고등어') || name.contains('연어') || 
        name.contains('삼치') || name.contains('갈치') || name.contains('참치') || name.contains('salmon') ||
        name.contains('tuna') || name.contains('mackerel')) return '🐟';
    if (name.contains('새우') || name.contains('shrimp') || name.contains('prawn')) return '🦐';
    if (name.contains('게') || name.contains('crab') || name.contains('킹크랩') || name.contains('대게')) return '🦀';
    if (name.contains('오징어') || name.contains('squid') || name.contains('갑오징어')) return '🦑';
    if (name.contains('조개') || name.contains('clam') || name.contains('바지락') || name.contains('대합') ||
        name.contains('굴') || name.contains('oyster')) return '🦪';
    if (name.contains('문어') || name.contains('octopus') || name.contains('주꾸미')) return '🐙';
    if (name.contains('랍스터') || name.contains('lobster')) return '🦞';
    
    // 계란
    if (name.contains('계란') || name.contains('달걀') || name.contains('egg')) return '🥚';
    
    // 빵류
    if (name.contains('식빵') || name.contains('bread')) return '🍞';
    if (name.contains('크루아상') || name.contains('croissant')) return '🥐';
    if (name.contains('베이글') || name.contains('bagel')) return '🥯';
    if (name.contains('도넛') || name.contains('doughnut')) return '🍩';
    if (name.contains('케이크') || name.contains('cake')) return '🍰';
    if (name.contains('쿠키') || name.contains('cookie') || name.contains('비스킷')) return '🍪';
    if (name.contains('빵') && !name.contains('식빵')) return '🥖';
    
    // 한식/두부
    if (name.contains('된장') || name.contains('고추장') || name.contains('쌈장')) return '🥫';
    if (name.contains('두부') || name.contains('tofu')) return '⬜';
    if (name.contains('콩') || name.contains('bean') || name.contains('soybean')) return '🫘';
    if (name.contains('떡') || name.contains('rice cake') || name.contains('떡볶이')) return '🍡';
    if (name.contains('김') || name.contains('seaweed') || name.contains('미역')) return '🌊';
    
    // 면류
    if (name.contains('라면') || name.contains('ramen') || name.contains('instant noodle')) return '🍜';
    if (name.contains('파스타') || name.contains('pasta') || name.contains('스파게티')) return '🍝';
    if (name.contains('우동') || name.contains('udon')) return '🍜';
    if (name.contains('냉면') || name.contains('국수') || name.contains('noodle')) return '🍜';
    
    // 밥/곡물류
    if (name.contains('밥') || name.contains('rice') || name.contains('쌀')) return '🍚';
    if (name.contains('김밥')) return '🍱';
    if (name.contains('주먹밥')) return '🍙';
    if (name.contains('초밥') || name.contains('sushi')) return '🍣';
    if (name.contains('볶음밥') || name.contains('fried rice')) return '🍛';
    if (name.contains('카레') || name.contains('curry')) return '🍛';
    if (name.contains('시리얼') || name.contains('cereal')) return '🥣';
    
    // 패스트푸드/간편식
    if (name.contains('피자') || name.contains('pizza')) return '🍕';
    if (name.contains('햄버거') || name.contains('burger')) return '🍔';
    if (name.contains('샌드위치') || name.contains('sandwich')) return '🥪';
    if (name.contains('타코') || name.contains('taco') || name.contains('부리또')) return '🌮';
    if (name.contains('핫도그') || name.contains('hot dog')) return '🌭';
    if (name.contains('감자튀김') || name.contains('fries')) return '🍟';
    if (name.contains('도시락') || name.contains('bento')) return '🍱';
    
    // 디저트/간식
    if (name.contains('초콜릿') || name.contains('초코') || name.contains('chocolate')) return '🍫';
    if (name.contains('사탕') || name.contains('candy')) return '🍬';
    if (name.contains('팝콘') || name.contains('popcorn')) return '🍿';
    if (name.contains('과자') || name.contains('snack') || name.contains('칩')) return '🍘';
    if (name.contains('젤리') || name.contains('jelly') || name.contains('gummy')) return '🍬';
    if (name.contains('푸딩') || name.contains('pudding')) return '🍮';
    if (name.contains('마카롱') || name.contains('macaron')) return '🍪';
    if (name.contains('와플') || name.contains('waffle')) return '🧇';
    if (name.contains('팬케이크') || name.contains('pancake')) return '🥞';
    
    // 조미료
    if (name.contains('소금') || name.contains('salt')) return '🧂';
    if (name.contains('설탕') || name.contains('sugar')) return '🧂';
    if (name.contains('꿀') || name.contains('honey')) return '🍯';
    if (name.contains('간장') || name.contains('soy sauce')) return '🥫';
    if (name.contains('식초') || name.contains('vinegar')) return '🥫';
    if (name.contains('기름') || name.contains('oil') || name.contains('오일')) return '🫗';
    if (name.contains('소스') || name.contains('sauce')) return '🥫';
    if (name.contains('마요') || name.contains('mayonnaise')) return '🥫';
    if (name.contains('케첩') || name.contains('ketchup')) return '🥫';
    if (name.contains('통조림') || name.contains('can')) return '🥫';
    
    // 견과류
    if (name.contains('견과') || name.contains('nuts')) return '🥜';
    if (name.contains('땅콩') || name.contains('peanut')) return '🥜';
    if (name.contains('아몬드') || name.contains('almond')) return '🥜';
    if (name.contains('호두') || name.contains('walnut')) return '🥜';
    
    // 기본값 (빈 문자열 반환하여 아이콘 사용)
    return '🥘';
  }
  
  /// 음식 아이콘 또는 이모지 빌더
  Widget _buildFoodIconOrEmoji(String foodName) {
    final emoji = _getEmojiForFood(foodName);
    
    // 이모지 표시
    return Center(
      child: Text(
        emoji,
        style: TextStyle(fontSize: 26),
      ),
    );
  }

  // 식품 삭제 (섭취/폐기)
  Future<void> _deleteItem(BuildContext context, _ExpiringItem item, String action) async {
    try {
      // Firestore에서 삭제
      final refrigeratorSnapshot = await FirebaseFirestore.instance
          .collection('Refrigerators')
          .where('room_id', isEqualTo: item.roomId)
          .where('name', isEqualTo: item.refrigeratorName)
          .limit(1)
          .get();

      if (refrigeratorSnapshot.docs.isNotEmpty) {
        final refrigeratorRef = refrigeratorSnapshot.docs.first.reference;
        
        // 식품 삭제
        await refrigeratorRef
            .collection('compartments')
            .doc(item.compartmentIndex.toString())
            .collection('ingredients')
            .doc(item.id)
            .delete();
        
        // 통계 서비스에 소비/폐기 기록
        final statisticsService = StatisticsService();
        await statisticsService.recordFoodAction(
          roomId: item.roomId,
          refrigeratorName: item.refrigeratorName,
          ingredientName: item.name,
          ingredientId: item.id,
          expiryDate: item.expiryDate,
          actionType: action == '소비' ? FoodActionType.consumed : FoodActionType.discarded,
        );
      }
    } catch (e) {
      debugPrint('식품 삭제 오류: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류가 발생했습니다'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }

  // 쿠팡 구매 여부 상태 업데이트 (Firestore + 로컬 캐시)
  Future<void> _updateCoupangPurchaseStatus(
      _ExpiringItem item, String? status) async {
    try {
      final refrigeratorSnapshot = await FirebaseFirestore.instance
          .collection('Refrigerators')
          .where('room_id', isEqualTo: item.roomId)
          .where('name', isEqualTo: item.refrigeratorName)
          .limit(1)
          .get();

      if (refrigeratorSnapshot.docs.isEmpty) {
        debugPrint('쿠팡 구매 상태 업데이트 실패: 냉장고를 찾을 수 없습니다.');
        return;
      }

      final refrigeratorRef = refrigeratorSnapshot.docs.first.reference;

      await refrigeratorRef
          .collection('compartments')
          .doc(item.compartmentIndex.toString())
          .collection('ingredients')
          .doc(item.id)
          .update({'coupangPurchaseStatus': status});

      // 로컬 캐시 업데이트
      setState(() {
        _cachedExpiringItems = _cachedExpiringItems
            .map((e) => e.matches(item) ? e.copyWith(coupangPurchaseStatus: status) : e)
            .toList();
        _cachedExpiredItems = _cachedExpiredItems
            .map((e) => e.matches(item) ? e.copyWith(coupangPurchaseStatus: status) : e)
            .toList();

        if (_pendingCoupangItem != null && _pendingCoupangItem!.matches(item)) {
          _pendingCoupangItem =
              _pendingCoupangItem!.copyWith(coupangPurchaseStatus: status);
        }
      });
    } catch (e) {
      debugPrint('쿠팡 구매 상태 업데이트 오류: $e');
    }
  }

  /// 쿠팡에서 보고 온 뒤, 해당 식품을 실제로 구매했는지 확인하는 다이얼로그
  Future<void> _showCoupangPurchaseDialog(_ExpiringItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('쿠팡에서 구매하셨나요?'),
          content: Text('"${item.name}" 상품을(를) 쿠팡에서 구매하셨는지 선택해주세요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                '아직 안 샀어요',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text(
                '구매했어요',
                style: TextStyle(
                  color: Color(0xFF4A90E2),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      await _updateCoupangPurchaseStatus(item, 'purchased');
    } else if (result == false) {
      await _updateCoupangPurchaseStatus(item, 'notPurchased');
    }

    setState(() {
      _pendingCoupangItem = null;
    });
  }

  // 안전한 URL 실행 헬퍼 함수
  Future<bool> _safeLaunchUrl(Uri uri) async {
    try {
      // 단계별로 시도하여 첫 실행 시 URL 스킴 오류 방지
      
      // 첫 번째 시도: 기본 방식 (모드 지정 없음)
      try {
        await launchUrl(uri);
        return true;
      } catch (e) {
        debugPrint('기본 방식 실행 실패: $e');
      }
      
      // 두 번째 시도: 외부 애플리케이션
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      } catch (e) {
        debugPrint('외부 애플리케이션 실행 실패: $e');
      }
      
      // 세 번째 시도: 인앱 웹뷰
      try {
        await launchUrl(uri, mode: LaunchMode.inAppWebView);
        return true;
      } catch (e) {
        debugPrint('인앱 웹뷰 실행 실패: $e');
      }
      
      return false;
    } catch (e) {
      debugPrint('URL 실행 전체 실패: $e');
      return false;
    }
  }

  // 쿠팡 검색 기능 (최적화된 버전)
  Future<void> _searchOnCoupang(
      BuildContext context, _ExpiringItem item) async {
    try {
      final productName = item.name;

      // 앱 복귀 시 구매 여부 팝업을 띄울 수 있도록 대상 식품 저장
      setState(() {
        _pendingCoupangItem = item;
        _isWaitingCoupangReturn = true;
      });

      // 한글 및 특수문자를 URL 인코딩
      final encodedQuery = Uri.encodeComponent(productName);
      final coupangUrl = 'https://www.coupang.com/np/search?q=$encodedQuery';
      
      final uri = Uri.parse(coupangUrl);
      
      // 안전한 URL 실행
      final launched = await _safeLaunchUrl(uri);
      
      if (!launched) {
        throw Exception('브라우저를 실행할 수 없습니다');
      }
      
    } catch (e) {
      debugPrint('쿠팡 검색 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text(
          widget.refrigeratorName != null 
              ? '유통기한 관리' 
              : '유통기한 관리',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey[500],
          labelStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          indicatorColor: Colors.black,
          indicatorWeight: 3,
          tabs: [
            Tab(text: '임박 식품'),
            Tab(text: '만료 식품'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 임박 식품 탭
          _buildItemList(_fetchExpiringItems(), isExpiringTab: true),
          // 만료 식품 탭
          _buildItemList(_fetchExpiredItems(), isExpiringTab: false),
        ],
      ),
    );
  }

  // 리스트 빌더 (공통)
  Widget _buildItemList(Future<List<_ExpiringItem>> future, {required bool isExpiringTab}) {
    return FutureBuilder<List<_ExpiringItem>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4E9FFF)),
                strokeWidth: 3,
              ),
            );
          }
          
          // 캐시가 있으면 캐시 우선 사용 (소비/폐기 시 즉시 UI 반영)
          List<_ExpiringItem> items;
          if (isExpiringTab && _hasLoadedExpiring) {
            items = _cachedExpiringItems;
          } else if (!isExpiringTab && _hasLoadedExpired) {
            items = _cachedExpiredItems;
          } else {
            items = snapshot.data ?? [];
          }
          
          if (items.isEmpty) {
            // 임박 탭인 경우, 만료 식품 존재 여부를 확인해서 메시지 결정
            if (isExpiringTab) {
              return FutureBuilder<List<_ExpiringItem>>(
                future: _fetchExpiredItems(),
                builder: (context, expiredSnapshot) {
                  if (expiredSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4E9FFF)),
                        strokeWidth: 3,
                      ),
                    );
                  }
                  
                  final expiredItems = expiredSnapshot.data ?? [];
                  final hasExpiredItems = expiredItems.isNotEmpty;
                  
                  // 만료 식품이 있으면: "유통기한이 임박한 식품이 없습니다"만 표시
                  // 만료 식품이 없으면: "유통기한이 임박한 식품이 없습니다 모든 식품이 신선해요! 🌱"
                  String title = '유통기한이 임박한 식품이 없습니다';
                  String? subtitle = hasExpiredItems ? null : '모든 식품이 신선해요! 🌱';
                  
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_outline, 
                            size: 64, 
                            color: Colors.green[400],
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (subtitle != null) ...[
                          SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            } else {
              // 만료 탭
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_outline, 
                        size: 64, 
                        color: Colors.green[400],
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      '만료된 식품이 없습니다',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '잘 관리하고 계시네요! 👍',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }
          }
          
          return Column(
            children: [
              // 통계 헤더 (컴팩트)
              Container(
                margin: EdgeInsets.fromLTRB(20, 16, 20, 12),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xFF6B9FFF),
                      size: 20,
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
                        color: Color(0xFF6B9FFF),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              
              // 리스트
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final now = DateTime.now();
                    final daysLeft = DateTime(item.expiryDate.year, item.expiryDate.month, item.expiryDate.day)
                        .difference(DateTime(now.year, now.month, now.day))
                        .inDays;
                    
                    final statusColor = _ddayColor(daysLeft);
                    
                    return Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Dismissible(
                        key: Key('expiring_${item.id}'),
                        background: Container(
                          decoration: BoxDecoration(
                            color: Colors.green[600],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Icon(Icons.restaurant, color: Colors.white, size: 28),
                              SizedBox(width: 8),
                              Text(
                                '소비',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          decoration: BoxDecoration(
                            color: Colors.red[600],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                '폐기',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.delete, color: Colors.white, size: 28),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          String actionText = direction == DismissDirection.startToEnd ? '소비' : '폐기';
                          String actionIcon = direction == DismissDirection.startToEnd ? '🍽️' : '🗑️';
                          
                          return await showDialog<bool>(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                title: Text('$actionIcon $actionText 확인'),
                                content: Text('${item.name}을(를) $actionText 하시겠습니까?'),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(false),
                                    child: Text('취소', style: TextStyle(color: Colors.grey[600])),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(true),
                                    child: Text(
                                      actionText,
                                      style: TextStyle(
                                        color: direction == DismissDirection.startToEnd 
                                          ? Colors.green[600] 
                                          : Colors.red[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ) ?? false;
                        },
                        onDismissed: (direction) async {
                          String action = direction == DismissDirection.startToEnd ? '소비' : '폐기';
                          
                          // 먼저 화면에서 즉시 제거하여 공백 없이 자연스럽게 줄어들도록 처리
                          setState(() {
                            if (isExpiringTab) {
                              _cachedExpiringItems.removeWhere((e) => e.id == item.id);
                            } else {
                              _cachedExpiredItems.removeWhere((e) => e.id == item.id);
                            }
                          });
                          
                          // 서버/DB 삭제 및 통계 기록은 비동기로 진행
                          await _deleteItem(context, item, action);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () {
                              // 해당 냉장고 칸으로 이동하고 해당 식품 하이라이트
                              // 하단 네비게이션 바는 '냉장고' 탭이 활성화되도록 MainScreen을 통해 이동
                              final mainState = MainScreen.instance;
                              if (mainState != null) {
                                mainState.navigateToIngredientsFromHome(
                                  roomId: item.roomId,
                                  refrigeratorName: item.refrigeratorName,
                                  compartmentName: item.compartmentName,
                                  compartmentIndex: item.compartmentIndex,
                                  targetIngredientId: item.id,
                                );
                              } else {
                                // 예외적으로 MainScreen 인스턴스를 찾지 못한 경우 기존 방식으로 fallback
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => IngredientsScreen(
                                      roomId: item.roomId,
                                      refrigeratorName: item.refrigeratorName,
                                      compartmentIndex: item.compartmentIndex,
                                      compartmentName: item.compartmentName,
                                      targetIngredientId: item.id,
                                    ),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              child: Row(
                                children: [
                         // 식품 이모지 아이콘
                         Container(
                           width: 52,
                           height: 52,
                           decoration: BoxDecoration(
                             color: Colors.white,
                             borderRadius: BorderRadius.circular(14),
                             border: Border.all(
                               color: Colors.grey[300]!,
                               width: 1.5,
                             ),
                           ),
                           child: ClipRRect(
                             borderRadius: BorderRadius.circular(13),
                             child: (item.imagePath != null && item.imagePath!.isNotEmpty)
                                 ? IngredientImageWidget(
                                     imagePath: item.imagePath!,
                                     width: 52,
                                     height: 52,
                                     fallbackIcon: _buildFoodIconOrEmoji(item.name),
                                   )
                                 : _buildFoodIconOrEmoji(item.name),
                           ),
                         ),
                                  
                                  SizedBox(width: 16),
                                  
                                  // 식품 정보
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[900],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.kitchen_rounded,
                                              size: 13,
                                              color: Colors.grey[500],
                                            ),
                                            SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${item.refrigeratorName} · ${item.compartmentName}',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[500],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  SizedBox(width: 12),
                                  
                                  // 유통기한 + 쿠팡 구매 여부 표시 영역
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // 유통기한 뱃지
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _formatDday(daysLeft),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: statusColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      _buildCoupangPurchaseStatusWidget(context, item),
                                    ],
                                  ),
                                  
                                  SizedBox(width: 12),
                                  
                                  // 구분선
                                  Container(
                                    width: 1,
                                    height: 40,
                                    color: Colors.grey[300],
                                  ),
                                  
                                  SizedBox(width: 12),
                                  
                                  // 쿠팡 구매 버튼
                                  GestureDetector(
                                    onTap: () => _searchOnCoupang(context, item),
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.shopping_cart_outlined,
                                            size: 20,
                                            color: Color(0xFF4A90E2),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            '구매',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF4A90E2),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
  }
}

class _ExpiringItem {
  final String id;
  final String name;
  final String? imagePath;
  final DateTime expiryDate;
  final String compartmentName;
  final String refrigeratorName;
  final String roomId;
  final int compartmentIndex;
  final String? coupangPurchaseStatus; // 'purchased' | 'notPurchased' | null

  _ExpiringItem({
    required this.id,
    required this.name,
    this.imagePath,
    required this.expiryDate,
    required this.compartmentName,
    required this.refrigeratorName,
    required this.roomId,
    required this.compartmentIndex,
    this.coupangPurchaseStatus,
  });

  // 동일 식품인지 비교할 때 사용
  bool matches(_ExpiringItem other) {
    return id == other.id &&
        roomId == other.roomId &&
        refrigeratorName == other.refrigeratorName &&
        compartmentIndex == other.compartmentIndex;
  }

  _ExpiringItem copyWith({
    String? coupangPurchaseStatus,
  }) {
    return _ExpiringItem(
      id: id,
      name: name,
      imagePath: imagePath,
      expiryDate: expiryDate,
      compartmentName: compartmentName,
      refrigeratorName: refrigeratorName,
      roomId: roomId,
      compartmentIndex: compartmentIndex,
      coupangPurchaseStatus: coupangPurchaseStatus ?? this.coupangPurchaseStatus,
    );
  }
}


