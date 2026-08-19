import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../services/home_service.dart';
import '../../models/statistics.dart';
import '../../theme/app_theme.dart';
import '../expiration/expiring_overview_screen.dart';
import '../refrigerator/refrigerator_compartment_screen.dart';
import '../refrigerator/ingredients_screen.dart';
import '../main_screen.dart';
import '../attendance/attendance_screen.dart';
import '../refrigerator/constants/food_category_icons.dart';
import '../refrigerator/widgets/ingredient_image_widget.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onRefresh;
  
  const HomeScreen({Key? key, this.onRefresh}) : super(key: key);

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final HomeService _homeService = HomeService();
  bool _isLoading = true;
  List<ExpiringItem> _expiringItems = [];
  List<RecentRefrigerator> _recentRefrigerators = [];
  
  // 배너 관련
  late PageController _bannerController;
  int _currentBannerIndex = 0;
  Timer? _bannerTimer;
  // 출석 배너 이미지 비율 (width / height)
  double? _attendanceBannerAspectRatio;
  
  // 출석체크 관련
  bool _isCheckedInToday = false;
  int _consecutiveDays = 0;

  // 홈 화면에서 표시할 임박 식품의 쿠팡 구매 여부 캐시
  // key: ingredientId, value: 'purchased' | 'notPurchased'
  final Map<String, String> _homeCoupangStatus = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bannerController = PageController();
    _startBannerAutoSlide();
    _loadAttendanceBannerAspectRatio();
    _loadAttendanceData();
    loadData();
  }
  
  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ==== 쿠팡 구매 여부 연동을 위한 상태 ====
  ExpiringItem? _pendingCoupangItem;
  bool _isWaitingCoupangReturn = false;

  // Firestore + 로컬 캐시에 쿠팡 구매 여부 반영
  Future<void> _updateHomeCoupangPurchaseStatus(
      ExpiringItem item, String? status) async {
    try {
      // 냉장고 ID가 있는 경우에만 업데이트
      if (item.refrigeratorId.isEmpty) {
        debugPrint('쿠팡 구매 상태 업데이트 실패: refrigeratorId가 비어 있습니다.');
        return;
      }

      await FirebaseFirestore.instance
          .collection('Refrigerators')
          .doc(item.refrigeratorId)
          .collection('compartments')
          .doc(item.compartmentIndex.toString())
          .collection('ingredients')
          .doc(item.id)
          .update({'coupangPurchaseStatus': status});

      // 홈 화면 전용 캐시 업데이트
      setState(() {
        if (status == null) {
          _homeCoupangStatus.remove(item.id);
        } else {
          _homeCoupangStatus[item.id] = status;
        }
      });
    } catch (e) {
      debugPrint('홈 쿠팡 구매 상태 업데이트 오류: $e');
    }
  }

  // 쿠팡 검색 실행 (홈 화면용)
  Future<void> _searchOnCoupangFromHome(ExpiringItem item) async {
    try {
      // 복귀 시 구매 여부 팝업을 띄우기 위해 대상 아이템을 저장
      setState(() {
        _pendingCoupangItem = item;
        _isWaitingCoupangReturn = true;
      });

      final url = _homeService.getCoupangSearchUrl(item.name);
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('쿠팡 URL 실행 실패');
      }
    } catch (e) {
      debugPrint('홈 쿠팡 검색 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('쿠팡을 열 수 없습니다')),
        );
      }
    }
  }

  /// 홈 화면에서 쿠팡 다녀온 뒤 구매 여부를 물어보는 팝업
  Future<void> _showCoupangPurchaseDialog(ExpiringItem item) async {
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
      await _updateHomeCoupangPurchaseStatus(item, 'purchased');
    } else if (result == false) {
      await _updateHomeCoupangPurchaseStatus(item, 'notPurchased');
    }

    setState(() {
      _pendingCoupangItem = null;
    });
  }

  // 홈 카드에서 사용할 쿠팡 구매 여부 뱃지
  Widget _buildHomeCoupangPurchaseStatusWidget(ExpiringItem item) {
    final status = _homeCoupangStatus[item.id];

    if (status == null) {
      // 아직 쿠팡 링크를 한 번도 타지 않았거나, 구매 여부를 선택하지 않은 경우 → 아무 것도 표시하지 않음
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

    // 뱃지를 탭하면 팝업을 다시 띄워서 상태를 수정할 수 있게 함
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
  
  void _startBannerAutoSlide() {
    _bannerTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (_bannerController.hasClients) {
        int nextPage = (_currentBannerIndex + 1) % 3; // 3개 배너
        _bannerController.animateToPage(
          nextPage,
          duration: Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // 출석 배너 이미지의 실제 비율을 미리 계산하여 레이아웃에 반영
  void _loadAttendanceBannerAspectRatio() {
    final imageProvider = const AssetImage('assets/images/attendance_banner.png');
    final stream = imageProvider.resolve(const ImageConfiguration());
    stream.addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        final width = info.image.width.toDouble();
        final height = info.image.height.toDouble();
        if (height == 0) return;
        setState(() {
          _attendanceBannerAspectRatio = width / height;
        });
      }),
    );
  }
  
  // 출석 데이터 로드
  Future<void> _loadAttendanceData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckIn = prefs.getString('last_check_in');
    final consecutiveDays = prefs.getInt('consecutive_days') ?? 0;
    
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    setState(() {
      _isCheckedInToday = lastCheckIn == todayString;
      _consecutiveDays = consecutiveDays;
    });
  }
  

  Future<void> loadData() async {
    print('🔄 홈 화면 데이터 로딩 시작');
    setState(() => _isLoading = true);
    
    try {
      final results = await Future.wait([
        _homeService.getExpiringItems(maxDays: 3), // limit 제거 - 전체 임박식품 가져오기
        _homeService.getRecentRefrigerators(limit: 4),
      ]);

      setState(() {
        _expiringItems = results[0] as List<ExpiringItem>;
        _recentRefrigerators = results[1] as List<RecentRefrigerator>;
        _isLoading = false;

        // Firestore에서 불러온 임박 식품 중, 이미 저장된 쿠팡 구매 여부가 있으면 캐시에 반영
        _homeCoupangStatus.clear();
        for (final item in _expiringItems) {
          if (item.coupangPurchaseStatus != null) {
            _homeCoupangStatus[item.id] = item.coupangPurchaseStatus!;
          }
        }
      });
      
      print('✅ 임박식품 ${_expiringItems.length}개 로드됨');
    } catch (e) {
      print('홈 데이터 로딩 오류: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 홈 화면에서 쿠팡으로 나갔다가 돌아온 경우에도 구매 여부 팝업 표시
    if (state == AppLifecycleState.resumed &&
        _isWaitingCoupangReturn &&
        _pendingCoupangItem != null &&
        mounted) {
      _isWaitingCoupangReturn = false;
      _showCoupangPurchaseDialog(_pendingCoupangItem!);
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: Color(0xFFF7F8FA),
      body: RefreshIndicator(
        onRefresh: loadData,
        color: AppTheme.primaryColor,
        child: CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: [
            // 심플한 앱바 (토스 스타일)
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Color(0xFFF7F8FA),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  color: Color(0xFFF7F8FA),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(24, 28, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 큰 타이틀 (토스 스타일)
                          Text(
                            '냉가드',
                            style: TextStyle(
                              color: Colors.grey[900],
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '오늘도 신선한 하루 🌱',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 컨텐츠
            if (_isLoading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    strokeWidth: 3,
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 배너
                      _buildBanner(),
                      
                      SizedBox(height: 40),
                      
                      // 유통기한 임박 섹션
                      _buildExpiringSection(),
                      
                      SizedBox(height: 40),
                      
                      // 최근 본 냉장고 섹션
                      _buildRecentRefrigeratorsSection(),
                      
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiringSection() {
    // 임박 식품 (daysLeft >= 0)
    final expiringOnly = _expiringItems.where((item) => item.daysLeft >= 0).toList();
    // 만료 식품 (daysLeft < 0)
    final expiredOnly = _expiringItems.where((item) => item.daysLeft < 0).toList();
    
    // 임박 식품이 없으면 만료 식품 표시
    final displayItems = expiringOnly.isNotEmpty 
        ? expiringOnly.take(3).toList() 
        : expiredOnly.take(3).toList();
    
    final hasExpiring = expiringOnly.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더 (토스 스타일 - 심플)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '유통기한 관리',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.grey[900],
                letterSpacing: -0.5,
              ),
            ),
            if (_expiringItems.isNotEmpty)
              TextButton(
                onPressed: () {
                  // 임박 식품이 없으면 만료 탭으로, 있으면 임박 탭으로
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ExpiringOverviewScreen(
                        initialTab: hasExpiring ? 0 : 1, // 0: 임박, 1: 만료
                      ),
                    ),
                  ).then((_) {
                    // 유통기한 관리 화면에서 식품을 소비/폐기하고 돌아온 경우
                    // 홈 화면의 유통기한 관리 미리보기도 최신 상태로 갱신
                    if (mounted) {
                      loadData();
                    }
                  });
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      '전체 ${_expiringItems.length}개',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
          ],
        ),
        
        SizedBox(height: 12),
        
        // 식품 목록
        if (_expiringItems.isEmpty)
          Container(
            padding: EdgeInsets.all(40),
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
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[400]!, Colors.green[300]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '모든 식품이 신선해요',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '임박한 식품이 없습니다',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
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
            child: Column(
              children: displayItems.map((item) {
                final index = displayItems.indexOf(item);
                return _buildExpiringItemRow(item, index == 0, index == displayItems.length - 1);
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildExpiringItemRow(ExpiringItem item, bool isFirst, bool isLast) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    // 냉장고와 동일한 색상 스키마 적용
    if (item.daysLeft < 0) {
      statusColor = Colors.red[600]!; // 만료됨 - 빨강
      statusText = 'D+${item.daysLeft.abs()}';
      statusIcon = Icons.cancel_rounded;
    } else if (item.daysLeft == 0) {
      statusColor = Colors.orange[600]!; // 오늘 - 주황
      statusText = 'D-Day';
      statusIcon = Icons.error_rounded;
    } else if (item.daysLeft == 1) {
      statusColor = Colors.amber[600]!; // 내일 - 노랑
      statusText = 'D-${item.daysLeft}';
      statusIcon = Icons.warning_amber_rounded;
    } else if (item.daysLeft <= 3) {
      statusColor = Colors.yellow[700]!; // 3일 이내 - 연노랑
      statusText = 'D-${item.daysLeft}';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = Colors.green[600]!; // 일반 - 초록
      statusText = 'D-${item.daysLeft}';
      statusIcon = Icons.info_rounded;
    }

    return Dismissible(
      key: Key('expiring_${item.id}'),
      background: Container(
        decoration: BoxDecoration(
          color: Colors.green[600],
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
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('$actionIcon $actionText 확인'),
              content: Text('${item.name}을(를) $actionText 하시겠습니까?'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('취소', style: TextStyle(color: Colors.grey[600])),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
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
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _markAsConsumed(item);
        } else if (direction == DismissDirection.endToStart) {
          _markAsDiscarded(item);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: !isLast 
              ? BorderSide(color: Colors.grey[100]!, width: 1)
              : BorderSide.none,
          ),
        ),
        child: InkWell(
          onTap: () {
            // 해당 냉장고 칸으로 이동하고 해당 식품 하이라이트
            // 이때 하단 네비게이션 바는 '냉장고' 탭이 활성화되도록 MainScreen을 통해 이동
            final mainState = MainScreen.instance;
            if (mainState != null) {
              mainState.navigateToIngredientsFromHome(
                roomId: item.roomId,
                refrigeratorName: item.refrigeratorName,
                compartmentName: item.compartmentName,
                compartmentIndex: item.compartmentIndex,
                targetIngredientId: item.id, // 해당 식품 ID 전달하여 포커싱
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
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // 식품 이미지 또는 아이콘
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
                
                // 유통기한 뱃지 + 쿠팡 구매 여부 표시
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    _buildHomeCoupangPurchaseStatusWidget(item),
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
                  onTap: () async {
                    await _searchOnCoupangFromHome(item);
                  },
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
    );
  }

  Widget _buildRecentRefrigeratorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Text(
          '빠른 접근',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.grey[900],
            letterSpacing: -0.5,
          ),
        ),
        
        SizedBox(height: 12),
        
        if (_recentRefrigerators.isEmpty)
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                '냉장고를 생성하거나 그룹에 참여해보세요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            itemCount: _recentRefrigerators.length,
            itemBuilder: (context, index) {
              final fridge = _recentRefrigerators[index];
              return _buildRecentRefrigeratorCard(fridge);
            },
          ),
      ],
    );
  }

  Widget _buildRecentRefrigeratorCard(RecentRefrigerator fridge) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          onTap: () async {
            final refrigeratorDoc = await FirebaseFirestore.instance
                .collection('Refrigerators')
                .doc(fridge.id)
                .get();
            
            if (refrigeratorDoc.exists) {
              final data = refrigeratorDoc.data()!;
              
              // 냉장고로 이동하기 전에 방문 기록 저장
              await _homeService.recordRefrigeratorVisit(fridge.id);

              if (!mounted) return;

              final mainState = MainScreen.instance;
              if (mainState != null) {
                // 메인 탭을 '냉장고'로 전환하면서 해당 냉장고 화면으로 이동
                mainState.navigateToRefrigeratorFromHome(
                  roomId: fridge.roomId,
                  refrigeratorName: fridge.name,
                  layout: data['layout'] ?? 'vertical',
                );
              } else {
                // 예외적으로 MainScreen 인스턴스를 찾지 못한 경우 기존 네비게이션으로 fallback
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RefrigeratorCompartmentScreen(
                      roomId: fridge.roomId,
                      refrigeratorName: fridge.name,
                      layout: data['layout'] ?? 'vertical',
                    ),
                  ),
                ).then((_) {
                  // 냉장고에서 돌아올 때 데이터 새로고침
                  if (mounted) {
                    loadData();
                  }
                });
              }
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF4E9FFF), Color(0xFF6BB6FF)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.kitchen_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    Spacer(),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fridge.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Color(0xFF4E9FFF).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            fridge.roomName,
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF4E9FFF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '${fridge.itemCount}개',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        SizedBox(height: 14),
        Text(
          value,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.grey[900],
            letterSpacing: -0.8,
            height: 1.0,
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

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
  
  /// 음식 아이콘 또는 이모지 빌더 (작은 크기)
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
  
  /// 음식 아이콘 또는 이모지 빌더 (큰 크기)
  Widget _buildFoodIconOrEmojiLarge(String foodName) {
    final emoji = _getEmojiForFood(foodName);
    
    // 이모지 표시
    return Center(
      child: Text(
        emoji,
        style: TextStyle(fontSize: 32),
      ),
    );
  }

  // 섭취 처리
  Future<void> _markAsConsumed(ExpiringItem item) async {
    try {
      final refrigeratorRef = FirebaseFirestore.instance
          .collection('Refrigerators')
          .doc(item.refrigeratorId);
      
      // 식품 삭제
      await refrigeratorRef
          .collection('compartments')
          .doc(item.compartmentIndex.toString())
          .collection('ingredients')
          .doc(item.id)
          .delete();
      
      // 통계 서비스에 소비 기록
      await _homeService.statisticsService.recordFoodAction(
        roomId: item.roomId,
        refrigeratorName: item.refrigeratorName,
        ingredientName: item.name,
        ingredientId: item.id,
        expiryDate: item.expiryDate,
        actionType: FoodActionType.consumed,
      );
    } catch (e) {
      print('섭취 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 폐기 처리
  Future<void> _markAsDiscarded(ExpiringItem item) async {
    try {
      await FirebaseFirestore.instance
          .collection('Refrigerators')
          .doc(item.refrigeratorId)
          .collection('compartments')
          .doc(item.compartmentIndex.toString())
          .collection('ingredients')
          .doc(item.id)
          .delete();

      // 통계 서비스에 폐기 기록
      await _homeService.statisticsService.recordFoodAction(
        roomId: item.roomId,
        refrigeratorName: item.refrigeratorName,
        ingredientName: item.name,
        ingredientId: item.id,
        expiryDate: item.expiryDate,
        actionType: FoodActionType.discarded,
      );
    } catch (e) {
      print('폐기 처리 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('오류가 발생했습니다'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showItemDetailDialog(ExpiringItem item) {
    Color statusColor;
    String statusText;
    
    if (item.daysLeft < 0) {
      statusColor = Colors.grey[700]!;
      statusText = '만료됨';
    } else if (item.daysLeft == 0) {
      statusColor = Color(0xFFFF6B6B);
      statusText = '오늘 만료';
    } else if (item.daysLeft <= 3) {
      statusColor = Color(0xFFFF9F43);
      statusText = '${item.daysLeft}일 남음';
    } else {
      statusColor = Color(0xFF4E9FFF);
      statusText = '${item.daysLeft}일 남음';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 핸들 바
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // 식품 정보
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _buildFoodIconOrEmojiLarge(item.name),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey[900],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 6),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            // 구분선
            Divider(color: Colors.grey[200], height: 1),
            
            SizedBox(height: 20),
            
            // 상세 정보
            _buildDetailRow(
              Icons.kitchen_rounded,
              '냉장고',
              item.refrigeratorName,
            ),
            SizedBox(height: 14),
            _buildDetailRow(
              Icons.space_dashboard_rounded,
              '위치',
              item.compartmentName,
            ),
            SizedBox(height: 14),
            _buildDetailRow(
              Icons.calendar_today_rounded,
              '유통기한',
              '${item.expiryDate.year}.${item.expiryDate.month.toString().padLeft(2, '0')}.${item.expiryDate.day.toString().padLeft(2, '0')}',
            ),
            if (item.quantity != null && item.quantity!.isNotEmpty) ...[
              SizedBox(height: 14),
              _buildDetailRow(
                Icons.inventory_2_rounded,
                '수량',
                item.quantity!,
              ),
            ],
            
            SizedBox(height: 28),
            
            // 액션 버튼들
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      // 냉장고 위치로 이동
                      final refrigeratorDoc = await FirebaseFirestore.instance
                          .collection('Refrigerators')
                          .doc(item.refrigeratorId)
                          .get();
                      
                      if (refrigeratorDoc.exists && mounted) {
                        final data = refrigeratorDoc.data()!;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RefrigeratorCompartmentScreen(
                              roomId: item.roomId,
                              refrigeratorName: item.refrigeratorName,
                              layout: data['layout'] ?? 'vertical',
                            ),
                          ),
                        );
                      }
                    },
                    icon: Icon(Icons.place_rounded, size: 20),
                    label: Text(
                      '위치 보기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _launchCoupangSearch(item.name);
                    },
                    icon: Icon(Icons.shopping_bag_rounded, size: 20),
                    label: Text(
                      '쿠팡 구매',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Color(0xFF4E9FFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: Colors.grey[700]),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[900],
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _launchCoupangSearch(String productName) async {
    final url = _homeService.getCoupangSearchUrl(productName);
    final uri = Uri.parse(url);
    
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('쿠팡을 열 수 없습니다')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('오류가 발생했습니다: $e')),
      );
    }
  }

  // 자동 슬라이드 배너
  Widget _buildBanner() {
    // 이미지 실제 비율(가로/세로)에 맞춰 배너 높이 계산
    final screenWidth = MediaQuery.of(context).size.width;
    final aspect = _attendanceBannerAspectRatio ?? (16 / 9); // 기본값 16:9
    final bannerHeight = (screenWidth / aspect) * 0.75; // 높이를 75%로 줄임

    return Column(
      children: [
        Container(
          height: bannerHeight,
          child: PageView(
            controller: _bannerController,
            onPageChanged: (index) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
            children: [
              _buildImageBanner('assets/images/banner1.png'),
              _buildImageBanner('assets/images/banner2.png'),
              _buildImageBanner('assets/images/banner3.png'),
            ],
          ),
        ),
        SizedBox(height: 10),
        // 인디케이터
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return Container(
              margin: EdgeInsets.symmetric(horizontal: 3),
              width: _currentBannerIndex == index ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _currentBannerIndex == index 
                    ? Color(0xFF6B9FFF) 
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
      ],
    );
  }

  // 이미지 배너
  Widget _buildImageBanner(String imagePath) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) {
            // 이미지 로드 실패 시 기본 배너 표시
            return Container(
              decoration: BoxDecoration(
                color: Color(0xFF6B9FFF),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Center(
                child: Text(
                  '이미지를 불러올 수 없습니다',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 출석체크 배너 (기존 코드는 주석처리하거나 삭제 가능)
  Widget _buildAttendanceBanner() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AttendanceScreen(),
          ),
        );
        // 출석체크 화면에서 돌아왔을 때 데이터 새로고침
        _loadAttendanceData();
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.asset(
            'assets/images/attendance_banner.png',
            // 배너 비율(16:9)에 맞춰 꽉 차게 표시
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              // 이미지 로드 실패 시 기본 배너 표시
              return Container(
                decoration: BoxDecoration(
                  color: Color(0xFF6B9FFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _isCheckedInToday ? Icons.check_circle : Icons.event_available_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isCheckedInToday ? '오늘 출석 완료!' : '출석체크',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            _consecutiveDays > 0 
                                ? '🔥 ${_consecutiveDays}일 연속'
                                : '매일 방문하고 출석도장 받기',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white.withOpacity(0.9),
                      size: 16,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureBanner({
    required Color color,
    required String title,
    required String subtitle,
    required IconData icon,
    required String badge,
  }) {
    return GestureDetector(
      onTap: () {
        // 배너 클릭 시 해당 기능으로 이동
        if (title == '영수증 스캔') {
          _navigateToReceiptScan();
        } else if (title == '바코드 스캔') {
          _navigateToBarcodeScanner();
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              // 아이콘
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              SizedBox(width: 14),
              // 텍스트
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        // 배지
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // 화살표
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withOpacity(0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 영수증 스캔으로 이동
  void _navigateToReceiptScan() async {
    if (_recentRefrigerators.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('먼저 냉장고를 생성하거나 참여해주세요'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // 최근 냉장고의 첫 번째 냉장고로 이동
    final fridge = _recentRefrigerators[0];
    final refrigeratorDoc = await FirebaseFirestore.instance
        .collection('Refrigerators')
        .doc(fridge.id)
        .get();
    
    if (refrigeratorDoc.exists && mounted) {
      final data = refrigeratorDoc.data()!;
      
      // 냉장고로 이동하기 전에 방문 기록 저장
      await _homeService.recordRefrigeratorVisit(fridge.id);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RefrigeratorCompartmentScreen(
            roomId: fridge.roomId,
            refrigeratorName: fridge.name,
            layout: data['layout'] ?? 'vertical',
          ),
        ),
      ).then((_) {
        // 냉장고에서 돌아올 때 데이터 새로고침
        if (mounted) {
          loadData();
        }
      });
    }
  }

  // 바코드 스캔으로 이동
  void _navigateToBarcodeScanner() async {
    if (_recentRefrigerators.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('먼저 냉장고를 생성하거나 참여해주세요'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    // 최근 냉장고의 첫 번째 냉장고로 이동
    final fridge = _recentRefrigerators[0];
    final refrigeratorDoc = await FirebaseFirestore.instance
        .collection('Refrigerators')
        .doc(fridge.id)
        .get();
    
    if (refrigeratorDoc.exists && mounted) {
      final data = refrigeratorDoc.data()!;
      
      // 냉장고로 이동하기 전에 방문 기록 저장
      await _homeService.recordRefrigeratorVisit(fridge.id);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RefrigeratorCompartmentScreen(
            roomId: fridge.roomId,
            refrigeratorName: fridge.name,
            layout: data['layout'] ?? 'vertical',
          ),
        ),
      ).then((_) {
        // 냉장고에서 돌아올 때 데이터 새로고침
        if (mounted) {
          loadData();
        }
      });
    }
  }
}

