import 'package:flutter/material.dart';
import 'manual_input_dialog.dart';

class ScrollDatePickerDialog extends StatefulWidget {
  final DateTime currentDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Function(DateTime) onDateSelected;

  const ScrollDatePickerDialog({
    Key? key,
    required this.currentDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  _ScrollDatePickerDialogState createState() => _ScrollDatePickerDialogState();
}

class _ScrollDatePickerDialogState extends State<ScrollDatePickerDialog> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late int selectedYear;
  late int selectedMonth;
  late int selectedDay;
  
  late FixedExtentScrollController yearController;
  late FixedExtentScrollController monthController;
  late FixedExtentScrollController dayController;

  @override
  void initState() {
    super.initState();
    
    // 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    
    // 애니메이션 시작
    _animationController.forward();
    
    selectedYear = widget.currentDate.year;
    selectedMonth = widget.currentDate.month;
    selectedDay = widget.currentDate.day;
    
    // 년도 범위 계산
    final yearRange = List.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.firstDate.year + index,
    );
    
    yearController = FixedExtentScrollController(
      initialItem: yearRange.indexOf(selectedYear),
    );
    monthController = FixedExtentScrollController(
      initialItem: selectedMonth - 1,
    );
    dayController = FixedExtentScrollController(
      initialItem: selectedDay - 1,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    yearController.dispose();
    monthController.dispose();
    dayController.dispose();
    super.dispose();
  }

  List<int> get yearRange {
    return List.generate(
      widget.lastDate.year - widget.firstDate.year + 1,
      (index) => widget.firstDate.year + index,
    );
  }

  int get daysInMonth {
    return DateTime(selectedYear, selectedMonth + 1, 0).day;
  }

  void _updateDay() {
    final maxDay = daysInMonth;
    if (selectedDay > maxDay) {
      selectedDay = maxDay;
      dayController.animateToItem(
        selectedDay - 1,
        duration: Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  Widget _buildScrollWheel({
    required List<String> items,
    required FixedExtentScrollController controller,
    required Function(int) onSelectedItemChanged,
    required String label,
    required int currentIndex,
    Function()? onTapNumber,
  }) {
    return Expanded(
      child: Column(
        children: [
          // 라벨
          Container(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          
          // 스크롤 휠
          Expanded(
            child: Stack(
              children: [
                // 선택 영역 하이라이트
                Center(
                  child: GestureDetector(
                    onTap: onTapNumber,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Color(0xFF3B82F6).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Color(0xFF3B82F6).withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                // 스크롤 휠
                ListWheelScrollView.useDelegate(
                  controller: controller,
                  itemExtent: 48,
                  perspective: 0.002,
                  diameterRatio: 1.5,
                  physics: FixedExtentScrollPhysics(),
                  onSelectedItemChanged: onSelectedItemChanged,
                  childDelegate: ListWheelChildBuilderDelegate(
                    builder: (context, index) {
                      if (index < 0 || index >= items.length) return null;
                      
                      bool isSelected = index == currentIndex;
                      
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        height: 48,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          onTap: () {
                            if (isSelected && onTapNumber != null) {
                              // 선택된 숫자를 탭하면 수기 입력 다이얼로그 열기
                              onTapNumber();
                            } else {
                              // 선택되지 않은 숫자를 탭하면 해당 위치로 스크롤
                              controller.animateToItem(
                                index,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          child: Text(
                            items[index],
                            style: TextStyle(
                              fontSize: isSelected ? 22 : 18,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Color(0xFF3B82F6) : Colors.black54,
                              height: 1.2,
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: items.length,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 수기 입력 다이얼로그 표시
  void _showManualInputDialog(String type, String currentValue, Function(DateTime) onDateSelected) {
    String numericValue = currentValue.replaceAll(RegExp(r'[^0-9]'), '');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ManualInputDialog(
          type: type,
          currentValue: numericValue,
          onDateSelected: onDateSelected,
          minValue: widget.firstDate.year,
          maxValue: widget.lastDate.year,
          selectedYear: selectedYear,
          selectedMonth: selectedMonth,
          selectedDay: selectedDay,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    children: [
                      Text(
                        '날짜 선택',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 16),
                      // 현재 선택된 날짜 표시
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${selectedYear}년 ${selectedMonth}월 ${selectedDay}일',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 스크롤 휠들
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 20),
                  height: 260,
                  child: Row(
                    children: [
                      // 년도 선택
                      _buildScrollWheel(
                        items: yearRange.map((year) => '$year').toList(),
                        controller: yearController,
                        label: '년',
                        currentIndex: yearRange.indexOf(selectedYear),
                        onSelectedItemChanged: (index) {
                          setState(() {
                            selectedYear = yearRange[index];
                            _updateDay();
                          });
                        },
                        onTapNumber: () {
                          _showManualInputDialog(
                            '년',
                            '$selectedYear',
                            (newDate) {
                              setState(() {
                                selectedYear = newDate.year;
                                selectedMonth = newDate.month;
                                selectedDay = newDate.day;
                                
                                // 스크롤 위치 업데이트
                                yearController.jumpToItem(yearRange.indexOf(selectedYear));
                                monthController.jumpToItem(selectedMonth - 1);
                                dayController.jumpToItem(selectedDay - 1);
                              });
                            },
                          );
                        },
                      ),
                      
                      SizedBox(width: 8),
                      
                      // 월 선택
                      _buildScrollWheel(
                        items: List.generate(12, (index) => '${index + 1}'),
                        controller: monthController,
                        label: '월',
                        currentIndex: selectedMonth - 1,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            selectedMonth = index + 1;
                            _updateDay();
                          });
                        },
                        onTapNumber: () {
                          _showManualInputDialog(
                            '월',
                            '$selectedMonth',
                            (newDate) {
                              setState(() {
                                selectedYear = newDate.year;
                                selectedMonth = newDate.month;
                                selectedDay = newDate.day;
                                
                                // 스크롤 위치 업데이트
                                yearController.jumpToItem(yearRange.indexOf(selectedYear));
                                monthController.jumpToItem(selectedMonth - 1);
                                dayController.jumpToItem(selectedDay - 1);
                              });
                            },
                          );
                        },
                      ),
                      
                      SizedBox(width: 8),
                      
                      // 일 선택
                      _buildScrollWheel(
                        items: List.generate(daysInMonth, (index) => '${index + 1}'),
                        controller: dayController,
                        label: '일',
                        currentIndex: selectedDay - 1,
                        onSelectedItemChanged: (index) {
                          setState(() {
                            selectedDay = index + 1;
                          });
                        },
                        onTapNumber: () {
                          _showManualInputDialog(
                            '일',
                            '$selectedDay',
                            (newDate) {
                              setState(() {
                                selectedYear = newDate.year;
                                selectedMonth = newDate.month;
                                selectedDay = newDate.day;
                                
                                // 스크롤 위치 업데이트
                                yearController.jumpToItem(yearRange.indexOf(selectedYear));
                                monthController.jumpToItem(selectedMonth - 1);
                                dayController.jumpToItem(selectedDay - 1);
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
                
                // 버튼들
                Container(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      // 취소 버튼
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            '취소',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      
                      SizedBox(width: 12),
                      
                      // 확인 버튼
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final selectedDate = DateTime(selectedYear, selectedMonth, selectedDay);
                            widget.onDateSelected(selectedDate);
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            '확인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
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
