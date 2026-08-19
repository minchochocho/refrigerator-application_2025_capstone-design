import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/refrigerator.dart';
import '../services/refrigerator_service.dart';
import '../widgets/animated_touch_button.dart';
import '../widgets/custom_page_transitions.dart';
import '../widgets/hero_widget.dart';
import 'home/home_screen.dart';
import 'room/room_list_screen.dart';
import 'profile_screen.dart';
import 'global_statistics_screen.dart';
import 'refrigerator/refrigerator_compartment_screen.dart';
import 'refrigerator/refrigerator_selection_screen.dart';
import 'refrigerator/ingredients_screen.dart';
import 'search/search_screen.dart';
import '../widgets/common_bottom_navigation.dart';

class MainScreen extends StatefulWidget {
  final User? user;
  final int initialIndex;
  
  // MainScreen의 현재 State에 전역적으로 접근하기 위한 정적 인스턴스
  static _MainScreenState? _instance;

  /// 다른 화면(예: 홈)에서 현재 MainScreen 상태에 접근할 때 사용
  static _MainScreenState? get instance => _instance;

  const MainScreen({
    Key? key,
    this.user,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  late int _selectedIndex;
  final RefrigeratorService _refrigeratorService = RefrigeratorService();
  late AnimationController _animationController;

  // 각 탭의 네비게이터 키
  final Map<int, GlobalKey<NavigatorState>> _navigatorKeys = {
    0: GlobalKey<NavigatorState>(),
    1: GlobalKey<NavigatorState>(),
    2: GlobalKey<NavigatorState>(),
    3: GlobalKey<NavigatorState>(),
  };

  // 홈 화면 상태 키
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();
  // 통계 화면 상태 키
  final GlobalKey<GlobalStatisticsScreenState> _statisticsScreenKey = GlobalKey<GlobalStatisticsScreenState>();
  
  @override
  void initState() {
    super.initState();
    // 전역 인스턴스 등록
    MainScreen._instance = this;
    _selectedIndex = widget.initialIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    
    // 애니메이션 자동 시작
    _animationController.forward();
  }
  
  @override
  void dispose() {
    // 전역 인스턴스 해제
    MainScreen._instance = null;
    _animationController.dispose();
    super.dispose();
  }
  
  // 외부에서 탭 변경할 수 있는 메서드
  void changeTab(int index) {
    if (mounted && index >= 0 && index < 4) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  /// 홈 화면 등 다른 탭에서 특정 냉장고 칸의 식품 목록(IngredientsScreen)으로
  /// 바로 이동하면서, 하단 네비게이션 탭은 '냉장고' 탭으로 보이도록 하는 메서드.
  void navigateToIngredientsFromHome({
    required String roomId,
    required String refrigeratorName,
    required String compartmentName,
    required int compartmentIndex,
    String? targetIngredientId,
  }) {
    if (!mounted) return;

    // 하단 네비게이션을 '냉장고' 탭(1번)으로 전환
    setState(() {
      _selectedIndex = 1;
      _animationController.reset();
      _animationController.forward();
    });

    // 냉장고 탭의 네비게이터에서 화면 push
    final navigator = _navigatorKeys[1]!.currentState;
    navigator?.push(
      MaterialPageRoute(
        builder: (context) => IngredientsScreen(
          roomId: roomId,
          refrigeratorName: refrigeratorName,
          compartmentName: compartmentName,
          compartmentIndex: compartmentIndex,
          targetIngredientId: targetIngredientId,
        ),
      ),
    );
  }

  /// 홈 화면의 '빠른 접근' 등에서 냉장고 카드를 눌렀을 때
  /// 냉장고 탭으로 전환하면서 해당 냉장고 칸 화면으로 이동하는 메서드.
  void navigateToRefrigeratorFromHome({
    required String roomId,
    required String refrigeratorName,
    required String layout,
  }) {
    if (!mounted) return;

    // 하단 네비게이션을 '냉장고' 탭(1번)으로 전환
    setState(() {
      _selectedIndex = 1;
      _animationController.reset();
      _animationController.forward();
    });

    // 냉장고 탭 네비게이터에서 냉장고 상세 화면으로 이동
    final navigator = _navigatorKeys[1]!.currentState;
    navigator?.push(
      MaterialPageRoute(
        settings: RouteSettings(name: 'refrigerator_compartment'),
        builder: (context) => RefrigeratorCompartmentScreen(
          roomId: roomId,
          refrigeratorName: refrigeratorName,
          layout: layout,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 현재 탭의 네비게이터에서 뒤로가기 처리
        final isFirstRouteInCurrentTab = 
            !await _navigatorKeys[_selectedIndex]!.currentState!.maybePop();
        
        if (isFirstRouteInCurrentTab) {
          // 현재 탭이 루트 화면이면 앱 종료
          if (_selectedIndex != 0) {
            // 홈 탭이 아니면 홈 탭으로 이동
            setState(() {
              _selectedIndex = 0;
            });
            return false;
          }
        }
        
        return isFirstRouteInCurrentTab;
      },
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            // 홈 탭 (인덱스 0) - 기존 HomeScreen 사용
            _buildNavigator(0, HomeScreen(key: _homeScreenKey)),
            // 냉장고(그룹 목록) 탭 (인덱스 1)
            _buildNavigator(1, RoomListScreen()),
            // 통계 탭 (인덱스 2)
            _buildNavigator(2, GlobalStatisticsScreen(key: _statisticsScreenKey)),
            // 마이페이지 탭 (인덱스 3)
            _buildNavigator(
              3,
              ProfileScreen(
                user: widget.user,
                onSignOut: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: CommonBottomNavigation(
          currentIndex: _selectedIndex,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
  
  // 각 탭에 독립적인 네비게이터 생성
  Widget _buildNavigator(int index, Widget child) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (routeSettings) {
        return MaterialPageRoute(
          builder: (context) => AnimatedBuilder(
            animation: _animationController,
            builder: (context, animChild) => FadeTransition(
              opacity: CurvedAnimation(
                parent: _animationController,
                curve: Interval(0.0, 0.5, curve: Curves.easeOut),
              ),
              child: animChild,
            ),
            child: child,
          ),
        );
      },
    );
  }
  
  // 탭 선택 처리
  void _onTabTapped(int index) {
    if (_selectedIndex == index) {
      // 같은 탭을 다시 눌렀을 때 루트로 이동
      _navigatorKeys[index]!.currentState!.popUntil((route) => route.isFirst);
      
      // 홈 탭이면 새로고침
      if (index == 0) {
        _homeScreenKey.currentState?.loadData();
        print('🔄 홈 탭 새로고침 (같은 탭 재클릭)');
      } else if (index == 2) {
        // 통계 탭이면 통계 데이터 재로딩
        _statisticsScreenKey.currentState?.reloadStatistics();
        print('🔄 통계 탭 새로고침 (같은 탭 재클릭)');
      }
    } else {
      final previousIndex = _selectedIndex;
      
      // 다른 탭으로 전환
      setState(() {
        _selectedIndex = index;
        // 탭 변경 시 애니메이션 재시작
        _animationController.reset();
        _animationController.forward();
      });
      
      // 홈 탭으로 돌아올 때 데이터 새로고침
      if (index == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _homeScreenKey.currentState?.loadData();
          print('🔄 홈 탭으로 전환 - 데이터 새로고침');
        });
      }

      // 통계 탭으로 전환될 때 통계 데이터 새로고침
      if (index == 2) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _statisticsScreenKey.currentState?.reloadStatistics();
          print('🔄 통계 탭으로 전환 - 데이터 새로고침');
        });
      }
    }
  }
  
  // 냉장고 모양 선택 화면으로 이동하는 메소드 수정
  void _navigateToRefrigeratorSelection() {
    // 개인 냉장고 추가 다이얼로그 표시
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('개인 냉장고 추가'),
        content: Text('개인 냉장고를 추가하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _createPersonalRefrigerator();
            },
            child: Text('추가'),
          ),
        ],
      ),
    );
  }

  // 개인 냉장고 생성
  Future<void> _createPersonalRefrigerator() async {
    try {
      // 로딩 다이얼로그 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('개인 냉장고를 생성하고 있습니다...'),
                ],
              ),
            ),
          );
        },
      );

      final refrigeratorService = RefrigeratorService();
      final refrigerator = await refrigeratorService.createPersonalRefrigerator();

      // 로딩 다이얼로그 닫기
      Navigator.of(context).pop();

      if (refrigerator != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('개인 냉장고가 성공적으로 생성되었습니다!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('개인 냉장고 생성에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      print('개인 냉장고 생성 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('개인 냉장고 생성 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // 냉장고 상세 화면으로 이동 메소드 수정
  void _navigateToRefrigeratorDetail(Refrigerator refrigerator) {
    Navigator.push(
      context,
      SlideRightPageRoute(
        settings: RouteSettings(name: 'refrigerator_compartment'),
        page: RefrigeratorCompartmentScreen(
          roomId: refrigerator.roomId,
          refrigeratorName: refrigerator.name,
          layout: refrigerator.layout,
        ),
        duration: Duration(milliseconds: 300),
      ),
    );
  }
  
}