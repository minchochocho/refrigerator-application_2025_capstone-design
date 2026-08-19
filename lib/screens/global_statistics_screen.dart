import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/statistics_service.dart';
import '../models/statistics.dart';
import '../models/room.dart';
import '../services/room_service.dart';
import '../theme/app_theme.dart';

class GlobalStatisticsScreen extends StatefulWidget {
  const GlobalStatisticsScreen({Key? key}) : super(key: key);

  @override
  GlobalStatisticsScreenState createState() => GlobalStatisticsScreenState();
}

class GlobalStatisticsScreenState extends State<GlobalStatisticsScreen>
    with SingleTickerProviderStateMixin {
  final StatisticsService _statisticsService = StatisticsService();
  final RoomService _roomService = RoomService();
  
  bool _isLoading = true;
  RoomStatistics? _currentStats;
  Map<String, dynamic> _comparison = {};
  List<Map<String, dynamic>> _userRanking = [];
  
  List<Room> _userRooms = [];
  Room? _selectedRoom;
  DateTime _selectedMonth = DateTime.now();
  List<DateTime> _availableMonths = [];
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  StreamSubscription<List<Room>>? _roomsSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    // 스켈레톤 애니메이션 반복
    _animationController.repeat();
    _listenUserRooms();
  }

  @override
  void dispose() {
    _roomsSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  /// 외부(예: MainScreen)에서 통계 탭으로 돌아왔을 때
  /// 최신 데이터를 다시 불러오도록 호출하는 메소드
  Future<void> reloadStatistics() async {
    // 이전 값이 잠깐 보이지 않도록 즉시 로딩 상태로 전환
    setState(() {
      _isLoading = true;
      _currentStats = null;
      _comparison = {};
      _userRanking = [];
      // 스켈레톤 애니메이션 다시 시작
      _animationController.stop();
      _animationController.duration = Duration(milliseconds: 1500);
      _animationController.repeat();
    });

    if (_selectedRoom != null) {
      await _loadRoomStatistics(_selectedRoom!.id);
    } else {
      await _loadStatistics();
    }
  }

  void _listenUserRooms() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 기존 구독 취소
    _roomsSubscription?.cancel();

    _roomsSubscription =
        _roomService.getUserRoomsWithRealTimeUpdates().listen((rooms) async {
      setState(() {
        _userRooms = rooms;
      });

      if (rooms.isEmpty) {
        // 방이 하나도 없을 때
        setState(() {
          _selectedRoom = null;
          _currentStats = null;
          _comparison = {};
          _userRanking = [];
          _availableMonths = [];
          _isLoading = false;
        });
        return;
      }

      // 선택된 방이 없거나, 선택된 방이 목록에 없으면 가장 많이 사용하는 방으로 선택
      final hasSelectedInList = _selectedRoom != null &&
          rooms.any((room) => room.id == _selectedRoom!.id);

      if (_selectedRoom == null || !hasSelectedInList) {
        // 가장 많이 사용하는 그룹 찾기
        final mostUsedRoom = await _findMostUsedRoom(rooms);
        setState(() {
          _selectedRoom = mostUsedRoom ?? rooms.first;
          _isLoading = true;
        });
        _animationController.duration = Duration(milliseconds: 1500);
        _animationController.repeat();
        await _loadRoomStatistics(_selectedRoom!.id);
      }
    });
  }

  /// 가장 많이 사용하는 그룹(Room) 찾기
  /// 냉장고 방문 기록을 기반으로 가장 자주 방문한 냉장고가 속한 그룹을 반환
  Future<Room?> _findMostUsedRoom(List<Room> rooms) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final prefs = await SharedPreferences.getInstance();
      final key = 'recent_refrigerators_${user.uid}';
      final recentIdsJson = prefs.getString(key);

      if (recentIdsJson == null || recentIdsJson.isEmpty) {
        return null; // 방문 기록이 없으면 null 반환
      }

      final recentIds = List<String>.from(json.decode(recentIdsJson));
      
      // 각 냉장고가 어느 그룹에 속하는지 확인
      final roomVisitCount = <String, int>{}; // roomId -> 방문 횟수
      
      for (final refrigeratorId in recentIds) {
        try {
          final refrigeratorDoc = await FirebaseFirestore.instance
              .collection('Refrigerators')
              .doc(refrigeratorId)
              .get();
          
          if (refrigeratorDoc.exists) {
            final roomId = refrigeratorDoc.data()?['room_id'] as String?;
            if (roomId != null && roomId.isNotEmpty) {
              roomVisitCount[roomId] = (roomVisitCount[roomId] ?? 0) + 1;
            }
          }
        } catch (e) {
          print('냉장고 정보 조회 오류: $e');
        }
      }

      if (roomVisitCount.isEmpty) {
        return null;
      }

      // 가장 많이 방문한 그룹 찾기
      final mostVisitedRoomId = roomVisitCount.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      // rooms 목록에서 해당 그룹 찾기
      return rooms.firstWhere(
        (room) => room.id == mostVisitedRoomId,
        orElse: () => rooms.first,
      );
    } catch (e) {
      print('가장 많이 사용하는 그룹 찾기 오류: $e');
      return null;
    }
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final roomsStream = _roomService.getUserRooms();
      final rooms = await roomsStream.first;
      _userRooms = rooms;

      if (_selectedRoom != null) {
        await _loadRoomStatistics(_selectedRoom!.id);
      } else if (rooms.isNotEmpty) {
        // 가장 많이 사용하는 그룹 찾기
        final mostUsedRoom = await _findMostUsedRoom(rooms);
        _selectedRoom = mostUsedRoom ?? rooms.first;
        await _loadRoomStatistics(_selectedRoom!.id);
      }

    } catch (e) {
      print('통계 데이터 로드 오류: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      // 로딩 완료 후 페이드 애니메이션으로 변경
      _animationController.stop();
      _animationController.duration = Duration(milliseconds: 800);
      _animationController.forward(from: 0);
    }
  }

  Future<void> _loadRoomStatistics(String roomId) async {
    try {
      await _statisticsService.trackExpiredItems(roomId);
      final availableMonths = await _statisticsService.getAvailableStatisticsMonths(roomId);
      final stats = await _statisticsService.getRoomStatisticsByMonth(roomId, _selectedMonth);
      final comparison = await _statisticsService.getStatisticsComparisonForMonth(roomId, _selectedMonth);
      final ranking = await _statisticsService.getUserRegistrationRankingForMonth(roomId, _selectedMonth);

      setState(() {
        _currentStats = stats;
        _comparison = comparison;
        _userRanking = ranking;
        _availableMonths = availableMonths;
        _isLoading = false;
      });
      
      // 로딩 완료 후 페이드 애니메이션으로 전환
      _animationController.stop();
      _animationController.duration = Duration(milliseconds: 800);
      _animationController.forward(from: 0);
    } catch (e) {
      print('그룹 통계 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectRoom(Room room) {
    if (_selectedRoom?.id != room.id) {
      setState(() {
        _selectedRoom = room;
        _isLoading = true;
      });
      // 스켈레톤 애니메이션 다시 시작
      _animationController.duration = Duration(milliseconds: 1500);
      _animationController.repeat();
      _loadRoomStatistics(room.id);
    }
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
      _isLoading = true;
    });
    // 스켈레톤 애니메이션 다시 시작
    _animationController.duration = Duration(milliseconds: 1500);
    _animationController.repeat();
    if (_selectedRoom != null) {
      _loadRoomStatistics(_selectedRoom!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          // 앱바
          SliverAppBar(
            expandedHeight: 170,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Color(0xFFF7F8FA),
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Color(0xFFF7F8FA),
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '통계',
                          style: TextStyle(
                            color: Colors.grey[900],
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${_selectedRoom?.roomName ?? '그룹'} 데이터 분석',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 16),
                        // 그룹/월 선택
                        _buildSelectionRow(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 컨텐츠
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // 로딩 중일 때는 스켈레톤 차트만 표시
                  if (_isLoading) ...[
                    // 주요 지표 스켈레톤
                    Text(
                      '📊 월간 활동 지표',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildSkeletonChart(height: 220),
                    SizedBox(height: 24),
                    
                    // 소비/폐기 스켈레톤
                    Text(
                      '🍽️ 식품 소비·폐기 현황',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildSkeletonChart(height: 164),
                    SizedBox(height: 24),
                    
                    // 전월 대비 스켈레톤
                    Text(
                      '📈 전월 대비 추이',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildSkeletonChart(height: 284),
                    SizedBox(height: 24),
                    
                    // 사용자별 순위 스켈레톤
                    Text(
                      '🏆 이달의 등록 순위',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildSkeletonChart(height: 200),
                  ]
                  // 데이터 로드 완료 시 실제 차트 표시
                  else ...[
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 주요 지표
                          Text(
                            '📊 월간 활동 지표',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildMainChart(),
                          
                          SizedBox(height: 24),

                          // 소비/폐기 분석
                          Text(
                            '🍽️ 식품 소비·폐기 현황',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey[900],
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildConsumptionChart(),

                          SizedBox(height: 24),

                          // 전월 대비 그래프
                          if (_comparison.isNotEmpty && _comparison['previous'] != null) ...[
                            Text(
                              '📈 전월 대비 추이',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[900],
                              ),
                            ),
                            SizedBox(height: 12),
                            _buildComparisonChart(),
                            SizedBox(height: 24),
                          ],

                          // 사용자 순위
                          _buildUserRanking(),

                          SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _userRooms.length > 1 ? () => _showRoomPicker() : null,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.home_rounded, color: AppTheme.primaryColor, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedRoom?.roomName ?? '그룹',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_userRooms.length > 1)
                    Icon(Icons.expand_more, color: Colors.grey[600], size: 20),
                ],
              ),
            ),
          ),
        ),
        SizedBox(width: 12),
        GestureDetector(
          onTap: () => _showMonthPicker(),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded, color: AppTheme.primaryColor, size: 16),
                SizedBox(width: 8),
                Text(
                  '${_selectedMonth.month}월',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.expand_more, color: Colors.grey[600], size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 주요 지표 막대 그래프
  Widget _buildMainChart() {
    if (_currentStats == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(20),
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
      child: SizedBox(
        height: 200,
        child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _getMaxValue().toDouble() * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        const titles = ['등록', '만료', '소비', '폐기'];
                        return Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            titles[value.toInt()],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: _getMaxValue() > 300 ? 100 : 50,
                      getTitlesWidget: (value, meta) {
                        final interval = _getMaxValue() > 300 ? 100 : 50;
                        // 동적 단위로만 표시
                        if (value % interval != 0) return SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _getMaxValue() > 300 ? 100 : 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey[200]!,
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _buildBarGroup(0, _currentStats!.totalRegisteredItems.toDouble(), Color(0xFF00C48C)),
                  _buildBarGroup(1, _currentStats!.expiredItems.toDouble(), Color(0xFFFF9F43)),
                  _buildBarGroup(2, _currentStats!.totalConsumed.toDouble(), Color(0xFF4E9FFF)),
                  _buildBarGroup(3, _currentStats!.totalDiscarded.toDouble(), Color(0xFFFF6B6B)),
                ],
              ),
            ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 32,
          borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  int _getMaxValue() {
    if (_currentStats == null) return 10;
    final values = [
      _currentStats!.totalRegisteredItems,
      _currentStats!.expiredItems,
      _currentStats!.totalConsumed,
      _currentStats!.totalDiscarded,
    ];
    final max = values.reduce((a, b) => a > b ? a : b);
    return max < 5 ? 5 : max;
  }

  // 소비/폐기 원형 차트
  Widget _buildConsumptionChart() {
    if (_currentStats == null) return SizedBox.shrink();

    int totalConsumed = _currentStats!.totalConsumed;
    int totalDiscarded = _currentStats!.totalDiscarded;
    int total = totalConsumed + totalDiscarded;

    if (total == 0) {
      return Container(
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
              Icon(Icons.info_outline, color: Colors.grey[300], size: 48),
              SizedBox(height: 12),
              Text(
                '아직 소비 또는 폐기 데이터가 없어요',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(32),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 왼쪽 여백 + 파이 차트
          Row(
            children: [
              SizedBox(width: 16),
              SizedBox(
                width: 75,
                height: 75,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 22,
                    sections: [
                      PieChartSectionData(
                        value: totalConsumed.toDouble(),
                        title: '',
                        color: Color(0xFF4E9FFF),
                        radius: 26.5,
                      ),
                      PieChartSectionData(
                        value: totalDiscarded.toDouble(),
                        title: '',
                        color: Color(0xFFFF6B6B),
                        radius: 26.5,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 24),
          // 범례
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLegendItem(
                  '소비',
                  totalConsumed,
                  (totalConsumed / total * 100).toStringAsFixed(0),
                  Color(0xFF4E9FFF),
                ),
                SizedBox(height: 16),
                _buildLegendItem(
                  '폐기',
                  totalDiscarded,
                  (totalDiscarded / total * 100).toStringAsFixed(0),
                  Color(0xFFFF6B6B),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, String percentage, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        SizedBox(width: 20),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(width: 6),
        Text(
          '($percentage%)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // 전월 대비 선 그래프 (전월 vs 이번 달 비교)
  Widget _buildComparisonChart() {
    if (_comparison['previous'] == null) return SizedBox.shrink();
    
    final previousData = _comparison['previous'] as Map<String, dynamic>;
    
    // Map에서 필요한 값 추출
    final prevRegistered = (previousData['totalRegisteredItems'] ?? 0) as int;
    final prevExpired = (previousData['expiredItems'] ?? 0) as int;
    final prevConsumed = (previousData['totalConsumed'] ?? 0) as int;
    final prevDiscarded = (previousData['totalDiscarded'] ?? 0) as int;

    final currRegistered = _currentStats!.totalRegisteredItems;
    final currExpired = _currentStats!.expiredItems;
    final currConsumed = _currentStats!.totalConsumed;
    final currDiscarded = _currentStats!.totalDiscarded;

    // x축: 지표(등록/만료/소비/폐기)
    // 전월·이번 달 모두 선 그래프로 표현
    final maxValue = [
      prevRegistered,
      prevExpired,
      prevConsumed,
      prevDiscarded,
      currRegistered,
      currExpired,
      currConsumed,
      currDiscarded,
    ].reduce((a, b) => a > b ? a : b);

    return Container(
      padding: EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 범례
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartLegend('전월', Color(0xFFFF9F43)),
              SizedBox(width: 24),
              _buildChartLegend('이번 달', Color(0xFF4E9FFF)),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 3,
                minY: 0,
                maxY: (maxValue * 1.2).clamp(5, double.infinity).toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue > 300 ? 100 : 50,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Color(0xFFE0ECFF),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        const titles = ['등록', '만료', '소비', '폐기'];
                        final index = value.toInt();
                        if (index < 0 || index >= titles.length) {
                          return SizedBox.shrink();
                        }
                        return Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            titles[index],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxValue > 300 ? 100 : 50,
                      getTitlesWidget: (value, meta) {
                        final interval = maxValue > 300 ? 100 : 50;
                        // 동적 단위로만 표시
                        if (value % interval != 0) return SizedBox.shrink();
                        return Text(
                          value.toInt().toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // 전월 선
                  LineChartBarData(
                    spots: [
                      FlSpot(0, prevRegistered.toDouble()),
                      FlSpot(1, prevExpired.toDouble()),
                      FlSpot(2, prevConsumed.toDouble()),
                      FlSpot(3, prevDiscarded.toDouble()),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.3,
                    preventCurveOverShooting: true,
                    color: Color(0xFFFF9F43),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: Color(0xFFFF9F43),
                        );
                      },
                    ),
                  ),
                  // 이번 달 선
                  LineChartBarData(
                    spots: [
                      FlSpot(0, currRegistered.toDouble()),
                      FlSpot(1, currExpired.toDouble()),
                      FlSpot(2, currConsumed.toDouble()),
                      FlSpot(3, currDiscarded.toDouble()),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.3,
                    preventCurveOverShooting: true,
                    color: Color(0xFF4E9FFF),
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4.5,
                          color: Colors.white,
                          strokeWidth: 2,
                          strokeColor: Color(0xFF4E9FFF),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildComparisonBarGroup({
    required int x,
    required double previous,
    required double current,
  }) {
    return BarChartGroupData(
      x: x,
      barsSpace: 6,
      barRods: [
        BarChartRodData(
          toY: previous,
          width: 12,
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          color: Color(0xFFCBD5F5),
        ),
        BarChartRodData(
          toY: current,
          width: 12,
          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
          color: AppTheme.primaryColor,
        ),
      ],
    );
  }

  // 전월/이번 달 범례 표시
  Widget _buildChartLegend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildUserRanking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🏆 이달의 등록 순위',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.grey[900],
          ),
        ),
        SizedBox(height: 16),
        if (_userRanking.isEmpty)
          Container(
            padding: EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.emoji_events_outlined, color: Colors.grey[300], size: 48),
                  SizedBox(height: 12),
                  Text(
                    '아직 데이터가 없어요',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
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
              children: List.generate(_userRanking.length, (index) {
                final user = _userRanking[index];
                final isLast = index == _userRanking.length - 1;
                return _buildRankingRow(
                  rank: index + 1,
                  nickname: user['nickname'],
                  count: user['count'],
                  isCurrentUser: user['userId'] == FirebaseAuth.instance.currentUser?.uid,
                  isLast: isLast,
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildRankingRow({
    required int rank,
    required String nickname,
    required int count,
    required bool isCurrentUser,
    required bool isLast,
  }) {
    String rankEmoji;
    if (rank == 1) {
      rankEmoji = '🥇';
    } else if (rank == 2) {
      rankEmoji = '🥈';
    } else if (rank == 3) {
      rankEmoji = '🥉';
    } else {
      rankEmoji = '$rank';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isCurrentUser ? AppTheme.primaryColor.withOpacity(0.05) : Colors.transparent,
        border: !isLast 
            ? Border(bottom: BorderSide(color: Colors.grey[100]!, width: 1))
            : null,
        borderRadius: isLast 
            ? BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: rank <= 3
                  ? Text(rankEmoji, style: TextStyle(fontSize: 18))
                  : Text(
                      rankEmoji,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[600],
                      ),
                    ),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              nickname,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isCurrentUser ? FontWeight.w600 : FontWeight.w500,
                color: Colors.grey[800],
              ),
            ),
          ),
          if (isCurrentUser)
            Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ME',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }

  void _showRoomPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
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
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        '그룹 선택',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                ...List.generate(_userRooms.length, (index) {
                  final room = _userRooms[index];
                  final isSelected = _selectedRoom?.id == room.id;
                  return InkWell(
                    onTap: () {
                      _selectRoom(room);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        children: [
                          Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? AppTheme.primaryColor : Colors.grey[300],
                            size: 22,
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              room.roomName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                color: isSelected ? Colors.grey[900] : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // 스켈레톤 선택 행
  Widget _buildSkeletonSelectionRow() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.grey[200]!,
                      Colors.grey[100]!,
                      Colors.grey[200]!,
                    ],
                    stops: [
                      0.0,
                      _animationController.value,
                      1.0,
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Container(
              width: 100,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.grey[200]!,
                    Colors.grey[100]!,
                    Colors.grey[200]!,
                  ],
                  stops: [
                    0.0,
                    _animationController.value,
                    1.0,
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 스켈레톤 차트
  Widget _buildSkeletonChart({required double height}) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Container(
          height: height,
          padding: EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.grey[200]!,
                      Colors.grey[100]!,
                      Colors.grey[200]!,
                    ],
                    stops: [
                      0.0,
                      _animationController.value,
                      1.0,
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.grey[100]!,
                        Colors.grey[50]!,
                        Colors.grey[100]!,
                      ],
                      stops: [
                        0.0,
                        _animationController.value,
                        1.0,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMonthPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
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
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        '월 선택',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[900],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Container(
                  constraints: BoxConstraints(maxHeight: 400),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final now = DateTime.now();
                      final month = DateTime(now.year, now.month - index);
                      final isSelected = _selectedMonth.year == month.year && 
                                        _selectedMonth.month == month.month;
                      return InkWell(
                        onTap: () {
                          _selectMonth(month);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.check_circle : Icons.circle_outlined,
                                color: isSelected ? AppTheme.primaryColor : Colors.grey[300],
                                size: 22,
                              ),
                              SizedBox(width: 16),
                              Text(
                                '${month.year}년 ${month.month}월',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  color: isSelected ? Colors.grey[900] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
