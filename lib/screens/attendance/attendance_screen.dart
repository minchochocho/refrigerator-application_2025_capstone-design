import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  bool _isCheckedInToday = false;
  int _consecutiveDays = 0;
  List<String> _attendanceHistory = [];

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheckIn = prefs.getString('last_check_in');
    final consecutiveDays = prefs.getInt('consecutive_days') ?? 0;
    final history = prefs.getStringList('attendance_history') ?? [];
    
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    setState(() {
      _isCheckedInToday = lastCheckIn == todayString;
      _consecutiveDays = consecutiveDays;
      _attendanceHistory = history;
    });
  }

  Future<void> _checkIn() async {
    if (_isCheckedInToday) return;
    
    final prefs = await SharedPreferences.getInstance();
    final lastCheckIn = prefs.getString('last_check_in');
    final today = DateTime.now();
    final todayString = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    int newConsecutiveDays = 1;
    
    if (lastCheckIn != null) {
      try {
        final lastDate = DateTime.parse(lastCheckIn);
        final todayMidnight = DateTime(today.year, today.month, today.day);
        final lastMidnight = DateTime(lastDate.year, lastDate.month, lastDate.day);
        final difference = todayMidnight.difference(lastMidnight).inDays;
        
        if (difference == 1) {
          newConsecutiveDays = _consecutiveDays + 1;
        }
      } catch (e) {
        print('날짜 파싱 오류: $e');
      }
    }
    
    // 출석 기록 추가
    final history = prefs.getStringList('attendance_history') ?? [];
    if (!history.contains(todayString)) {
      history.add(todayString);
      await prefs.setStringList('attendance_history', history);
    }
    
    await prefs.setString('last_check_in', todayString);
    await prefs.setInt('consecutive_days', newConsecutiveDays);
    
    setState(() {
      _isCheckedInToday = true;
      _consecutiveDays = newConsecutiveDays;
      _attendanceHistory = history;
    });
    
    // 출석 완료 메시지
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Text('✅', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('출석 완료! ${newConsecutiveDays}일 연속 방문 🎉'),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _isAttendedOn(DateTime date) {
    final dateString = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return _attendanceHistory.contains(dateString);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    return Scaffold(
      backgroundColor: Color(0xFFF7F8FA),
      appBar: AppBar(
        title: Text('출석체크'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[900],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 상단 통계 카드
            Container(
              margin: EdgeInsets.fromLTRB(20, 20, 20, 16),
              padding: EdgeInsets.all(24),
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
              child: Column(
                children: [
                  // 연속 출석일
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFF6B9FFF).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🔥',
                          style: TextStyle(fontSize: 28),
                        ),
                      ),
                      SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '연속 출석',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$_consecutiveDays',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF6B9FFF),
                                  height: 1,
                                ),
                              ),
                              SizedBox(width: 4),
                              Padding(
                                padding: EdgeInsets.only(bottom: 4),
                                child: Text(
                                  '일',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  // 출석 버튼
                  if (!_isCheckedInToday)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _checkIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF6B9FFF),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 22),
                            SizedBox(width: 8),
                            Text(
                              '출석하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Color(0xFF6B9FFF).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: Color(0xFF6B9FFF), size: 22),
                          SizedBox(width: 8),
                          Text(
                            '오늘 출석 완료',
                            style: TextStyle(
                              color: Color(0xFF6B9FFF),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // 달력
            Container(
              margin: EdgeInsets.fromLTRB(20, 0, 20, 16),
              padding: EdgeInsets.all(20),
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
              child: Column(
                children: [
                  // 월 표시
                  Text(
                    '${now.year}년 ${now.month}월',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[900],
                    ),
                  ),
                  SizedBox(height: 20),
                  // 요일 헤더
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: ['일', '월', '화', '수', '목', '금', '토'].map((day) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: day == '일' ? Colors.red[400] : Colors.grey[600],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  SizedBox(height: 12),
                  // 날짜 그리드
                  ...List.generate((daysInMonth + firstWeekday + 6) ~/ 7, (weekIndex) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(7, (dayIndex) {
                          final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 1;
                          
                          if (dayNumber < 1 || dayNumber > daysInMonth) {
                            return Expanded(child: SizedBox(height: 40));
                          }
                          
                          final date = DateTime(now.year, now.month, dayNumber);
                          final isToday = date.day == now.day && date.month == now.month && date.year == now.year;
                          final isAttended = _isAttendedOn(date);
                          final isFuture = date.isAfter(now);
                          
                          return Expanded(
                            child: Container(
                              height: 40,
                              child: Center(
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isAttended 
                                        ? Color(0xFF6B9FFF)
                                        : (isToday ? Color(0xFF6B9FFF).withOpacity(0.08) : null),
                                    shape: BoxShape.circle,
                                    border: isToday && !isAttended
                                        ? Border.all(color: Color(0xFF6B9FFF), width: 2)
                                        : null,
                                  ),
                                  child: Center(
                                    child: isAttended
                                        ? Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 18,
                                          )
                                        : Text(
                                            '$dayNumber',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                              color: isFuture
                                                  ? Colors.grey[400]
                                                  : (isToday ? Color(0xFF6B9FFF) : Colors.grey[800]),
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                  SizedBox(height: 16),
                  // 범례
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Color(0xFF6B9FFF),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '출석 완료',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 16),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Color(0xFF6B9FFF), width: 2),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '오늘',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 총 출석일수
            Container(
              margin: EdgeInsets.fromLTRB(20, 0, 20, 20),
              padding: EdgeInsets.all(20),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFF6B9FFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: Color(0xFF6B9FFF),
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    '총 출석일수',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '${_attendanceHistory.length}일',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B9FFF),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

