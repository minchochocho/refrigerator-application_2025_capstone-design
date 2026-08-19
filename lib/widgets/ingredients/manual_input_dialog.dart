import 'package:flutter/material.dart';

class ManualInputDialog extends StatefulWidget {
  final String type;
  final String currentValue;
  final Function(DateTime) onDateSelected;
  final int minValue;
  final int maxValue;
  final int selectedYear;
  final int selectedMonth;
  final int selectedDay;

  const ManualInputDialog({
    Key? key,
    required this.type,
    required this.currentValue,
    required this.onDateSelected,
    required this.minValue,
    required this.maxValue,
    required this.selectedYear,
    required this.selectedMonth,
    required this.selectedDay,
  }) : super(key: key);

  @override
  _ManualInputDialogState createState() => _ManualInputDialogState();
}

class _ManualInputDialogState extends State<ManualInputDialog> {
  late TextEditingController _yearController;
  late TextEditingController _monthController;
  late TextEditingController _dayController;
  late FocusNode _yearFocusNode;
  late FocusNode _monthFocusNode;
  late FocusNode _dayFocusNode;

  @override
  void initState() {
    super.initState();
    _yearController = TextEditingController(text: widget.selectedYear.toString());
    _monthController = TextEditingController(text: widget.selectedMonth.toString());
    _dayController = TextEditingController(text: widget.selectedDay.toString());
    
    _yearFocusNode = FocusNode();
    _monthFocusNode = FocusNode();
    _dayFocusNode = FocusNode();
    
    // 클릭한 항목에 따라 해당 필드에 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.type == '년') {
        _yearFocusNode.requestFocus();
        _yearController.selection = TextSelection.fromPosition(
          TextPosition(offset: _yearController.text.length),
        );
      } else if (widget.type == '월') {
        _monthFocusNode.requestFocus();
        _monthController.selection = TextSelection.fromPosition(
          TextPosition(offset: _monthController.text.length),
        );
      } else {
        _dayFocusNode.requestFocus();
        _dayController.selection = TextSelection.fromPosition(
          TextPosition(offset: _dayController.text.length),
        );
      }
    });
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _yearFocusNode.dispose();
    _monthFocusNode.dispose();
    _dayFocusNode.dispose();
    super.dispose();
  }

  void _onConfirmPressed() {
    String yearValue = _yearController.text.trim();
    String monthValue = _monthController.text.trim();
    String dayValue = _dayController.text.trim();
    
    if (yearValue.isEmpty || monthValue.isEmpty || dayValue.isEmpty) {
      _showErrorMessage('모든 값을 입력해주세요.');
      return;
    }
    
    int year = int.tryParse(yearValue) ?? 0;
    int month = int.tryParse(monthValue) ?? 0;
    int day = int.tryParse(dayValue) ?? 0;
    
    // 범위 검증
    if (year < widget.minValue || year > widget.maxValue) {
      _showErrorMessage('${widget.minValue}년~${widget.maxValue}년 범위의 값을 입력해주세요.');
      return;
    }
    
    if (month < 1 || month > 12) {
      _showErrorMessage('1월~12월 범위의 값을 입력해주세요.');
      return;
    }
    
    // 해당 년/월의 최대 일수 확인
    int maxDayInMonth = DateTime(year, month + 1, 0).day;
    if (day < 1 || day > maxDayInMonth) {
      _showErrorMessage('${year}년 ${month}월은 1일~${maxDayInMonth}일까지 있습니다.');
      return;
    }
    
    // 모든 검증을 통과했으면 날짜 업데이트
    final selectedDate = DateTime(year, month, day);
    widget.onDateSelected(selectedDate);
    Navigator.of(context).pop();
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 320,
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 날짜 표시 (2025년 9월 ▲ 형태)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.selectedYear}년 ${widget.selectedMonth}월',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_up,
                  color: Colors.grey[600],
                  size: 20,
                ),
              ],
            ),
            
            SizedBox(height: 24),
            
            // 현재 선택된 날짜 표시 (2025 09 22 형태) - 각각 클릭 가능
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 년도 입력 필드
                  GestureDetector(
                    onTap: () => _yearFocusNode.requestFocus(),
                    child: Container(
                      width: 80,
                      child: TextField(
                        controller: _yearController,
                        focusNode: _yearFocusNode,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _monthFocusNode.requestFocus(),
                      ),
                    ),
                  ),
                  
                  // 월 입력 필드
                  GestureDetector(
                    onTap: () => _monthFocusNode.requestFocus(),
                    child: Container(
                      width: 60,
                      child: TextField(
                        controller: _monthController,
                        focusNode: _monthFocusNode,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _dayFocusNode.requestFocus(),
                      ),
                    ),
                  ),
                  
                  // 일 입력 필드
                  GestureDetector(
                    onTap: () => _dayFocusNode.requestFocus(),
                    child: Container(
                      width: 60,
                      child: TextField(
                        controller: _dayController,
                        focusNode: _dayFocusNode,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onSubmitted: (_) => _onConfirmPressed(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // 하단 버튼들
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _onConfirmPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      '완료',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
