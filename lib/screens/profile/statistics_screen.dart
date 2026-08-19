import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/statistics_service.dart';
import '../../models/statistics.dart';
import '../../theme/app_theme.dart';

class StatisticsScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const StatisticsScreen({
    Key? key,
    required this.roomId,
    required this.roomName,
  }) : super(key: key);

  @override
  _StatisticsScreenState createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  final StatisticsService _statisticsService = StatisticsService();
  bool _isLoading = true;
  RoomStatistics? _currentStats;
  Map<String, dynamic> _comparison = {};
  List<Map<String, dynamic>> _userRanking = [];
  
  // 통계 보기 모드
  bool _isCumulativeMode = false;
  DateTime? _selectedMonth;
  List<DateTime> _availableMonths = [];
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _loadStatistics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _statisticsService.trackExpiredItems(widget.roomId);
      final availableMonths = await _statisticsService.getAvailableStatisticsMonths(widget.roomId);
      
      RoomStatistics? stats;
      Map<String, dynamic> comparison = {};
      List<Map<String, dynamic>> ranking = [];
      
      if (_isCumulativeMode) {
        stats = await _statisticsService.getCumulativeRoomStatistics(widget.roomId);
        ranking = await _statisticsService.getCumulativeUserRegistrationRanking(widget.roomId);
      } else {
        if (_selectedMonth != null) {
          stats = await _statisticsService.getRoomStatisticsByMonth(widget.roomId, _selectedMonth!);
          comparison = await _statisticsService.getStatisticsComparisonForMonth(widget.roomId, _selectedMonth!);
          ranking = await _statisticsService.getUserRegistrationRankingForMonth(widget.roomId, _selectedMonth!);
        }
      }

      setState(() {
        _currentStats = stats;
        _comparison = comparison;
        _userRanking = ranking;
        _availableMonths = availableMonths;
        _isLoading = false;
      });
      
      _animationController.forward(from: 0);
    } catch (e) {
      print('❌ 통계 데이터 로드 오류: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleStatisticsMode() {
    setState(() {
      _isCumulativeMode = !_isCumulativeMode;
      if (!_isCumulativeMode && _selectedMonth == null) {
        _selectedMonth = DateTime.now();
      }
    });
    _loadStatistics();
  }

  void _selectMonth(DateTime month) {
    setState(() {
      _selectedMonth = month;
    });
    _loadStatistics();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        slivers: [
          // 미니멀한 앱바
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            leading: IconButton(
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back_ios_new, color: Colors.grey[800], size: 16),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // 모드 토글
              Container(
                margin: EdgeInsets.only(right: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _toggleStatisticsMode,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isCumulativeMode ? Icons.query_stats_rounded : Icons.calendar_today_rounded,
                            color: Colors.grey[800],
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            _isCumulativeMode ? '누적' : '월별',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // 월 선택
              if (!_isCumulativeMode && _availableMonths.isNotEmpty)
                PopupMenuButton<DateTime>(
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.expand_more, color: Colors.grey[800], size: 20),
                  ),
                  onSelected: _selectMonth,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  offset: Offset(0, 50),
                  itemBuilder: (context) {
                    return _availableMonths.map((month) {
                      final isSelected = _selectedMonth?.year == month.year && 
                                       _selectedMonth?.month == month.month;
                      return PopupMenuItem<DateTime>(
                        value: month,
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.grey[900] : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                '${month.year}년 ${month.month}월',
                                style: TextStyle(
                                  color: isSelected ? Colors.grey[900] : Colors.grey[600],
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList();
                  },
                ),
              SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.white,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(24, 60, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '통계',
                          style: TextStyle(
                            color: Colors.grey[900],
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          _isCumulativeMode 
                              ? '전체 기간'
                              : '${_selectedMonth?.year ?? DateTime.now().year}년 ${_selectedMonth?.month ?? DateTime.now().month}월',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.3,
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      '데이터 불러오는 중',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 주요 수치 (큰 카드)
                      _buildMainMetrics(),
                      
                      SizedBox(height: 32),

                      // 상세 통계
                      _buildDetailedStats(),

                      SizedBox(height: 32),

                      // 전월 대비 (월별 모드일 때만)
                      if (!_isCumulativeMode && _comparison.isNotEmpty && _comparison['previous'] != null)
                        _buildComparisonSection(),

                      if (!_isCumulativeMode && _comparison.isNotEmpty && _comparison['previous'] != null)
                        SizedBox(height: 32),

                      // 사용자 순위
                      _buildUserRanking(),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 주요 수치 (심플하고 큰 디자인)
  Widget _buildMainMetrics() {
    if (_currentStats == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  '등록',
                  _currentStats!.totalRegisteredItems,
                  Icons.add_circle_outline_rounded,
                  Color(0xFF00C48C),
                ),
              ),
              Container(width: 1, height: 60, color: Colors.grey[200]),
              SizedBox(width: 24),
              Expanded(
                child: _buildMetricItem(
                  '만료',
                  _currentStats!.expiredItems,
                  Icons.error_outline_rounded,
                  Color(0xFFFF9F43),
                ),
              ),
            ],
          ),
          SizedBox(height: 28),
          Container(height: 1, color: Colors.grey[200]),
          SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  '소비',
                  _currentStats!.totalConsumed,
                  Icons.check_circle_outline_rounded,
                  Color(0xFF4E9FFF),
                ),
              ),
              Container(width: 1, height: 60, color: Colors.grey[200]),
              SizedBox(width: 24),
              Expanded(
                child: _buildMetricItem(
                  '폐기',
                  _currentStats!.totalDiscarded,
                  Icons.cancel_outlined,
                  Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        SizedBox(height: 12),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.grey[900],
            letterSpacing: -1,
            height: 1,
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.grey[500],
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // 상세 통계 (소비/폐기 분석)
  Widget _buildDetailedStats() {
    if (_currentStats == null) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '상세 분석',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.grey[900],
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 16),
        
        // 소비 분석
        _buildDetailItem(
          '소비',
          _currentStats!.consumedBeforeExpiry,
          _currentStats!.consumedAfterExpiry,
          Color(0xFF4E9FFF),
        ),
        
        SizedBox(height: 16),
        
        // 폐기 분석
        _buildDetailItem(
          '폐기',
          _currentStats!.discardedBeforeExpiry,
          _currentStats!.discardedAfterExpiry,
          Color(0xFFFF6B6B),
        ),
      ],
    );
  }

  Widget _buildDetailItem(String title, int before, int after, Color color) {
    int total = before + after;
    double beforeRatio = total > 0 ? before / total : 0;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                '$total',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // 프로그레스 바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                if (before > 0)
                  Expanded(
                    flex: before,
                    child: Container(
                      height: 6,
                      color: Color(0xFF00C48C),
                    ),
                  ),
                if (after > 0)
                  Expanded(
                    flex: after,
                    child: Container(
                      height: 6,
                      color: Color(0xFFFF9F43),
                    ),
                  ),
              ],
            ),
          ),
          
          SizedBox(height: 14),
          
          Row(
            children: [
              _buildRatioLabel('만료 전', before, beforeRatio, Color(0xFF00C48C)),
              SizedBox(width: 16),
              _buildRatioLabel('만료 후', after, 1 - beforeRatio, Color(0xFFFF9F43)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatioLabel(String label, int count, double ratio, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6),
        Text(
          '$label $count',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: 4),
        Text(
          '(${(ratio * 100).toStringAsFixed(0)}%)',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // 전월 대비
  Widget _buildComparisonSection() {
    final changes = _comparison['changes'] as Map<String, dynamic>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '전월 대비',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.grey[900],
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 16),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!, width: 1),
          ),
          child: Column(
            children: [
              _buildComparisonRow('등록', changes['totalRegistered'] ?? 0),
              SizedBox(height: 14),
              _buildComparisonRow('만료', changes['expiredItems'] ?? 0),
              SizedBox(height: 14),
              _buildComparisonRow('소비', changes['totalConsumed'] ?? 0),
              SizedBox(height: 14),
              _buildComparisonRow('폐기', changes['totalDiscarded'] ?? 0),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonRow(String label, int change) {
    Color changeColor = change > 0 ? Color(0xFFFF6B6B) : change < 0 ? Color(0xFF00C48C) : Colors.grey[400]!;
    IconData icon = change > 0 ? Icons.arrow_upward_rounded : 
                   change < 0 ? Icons.arrow_downward_rounded : Icons.remove;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Icon(icon, color: changeColor, size: 16),
            SizedBox(width: 4),
            Text(
              '${change > 0 ? '+' : ''}$change',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: changeColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 사용자 순위
  Widget _buildUserRanking() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '순위',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.grey[900],
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 16),
        
        if (_userRanking.isEmpty)
          Container(
            padding: EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.emoji_events_outlined, color: Colors.grey[400], size: 48),
                  SizedBox(height: 12),
                  Text(
                    '아직 데이터가 없어요',
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!, width: 1),
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
    Color rankColor;
    
    if (rank == 1) {
      rankEmoji = '🥇';
      rankColor = Color(0xFFFFD700);
    } else if (rank == 2) {
      rankEmoji = '🥈';
      rankColor = Color(0xFFC0C0C0);
    } else if (rank == 3) {
      rankEmoji = '🥉';
      rankColor = Color(0xFFCD7F32);
    } else {
      rankEmoji = '';
      rankColor = Colors.grey[400]!;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isCurrentUser ? Colors.grey[50] : Colors.transparent,
        border: !isLast 
            ? Border(bottom: BorderSide(color: Colors.grey[200]!, width: 1))
            : null,
        borderRadius: isLast 
            ? BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: rank <= 3
                  ? Text(rankEmoji, style: TextStyle(fontSize: 16))
                  : Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 13,
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
                color: isCurrentUser ? Colors.grey[900] : Colors.grey[700],
              ),
            ),
          ),
          if (isCurrentUser)
            Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'ME',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey[900],
            ),
          ),
        ],
      ),
    );
  }
}

