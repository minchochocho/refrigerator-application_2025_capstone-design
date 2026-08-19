import 'package:flutter/material.dart';
import '../../../widgets/ingredients/scroll_date_picker_dialog.dart';

/// 날짜 선택 필드 위젯
class DateFieldWidget extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final DateTime? selectedDate;
  final Function(DateTime?) onDateSelected;
  final bool isRequired;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final bool isReadOnly; // 선택 불가 옵션 추가
  
  const DateFieldWidget({
    Key? key,
    required this.label,
    required this.controller,
    required this.selectedDate,
    required this.onDateSelected,
    required this.isRequired,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.isReadOnly = false,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    DateTime currentDate = selectedDate ?? initialDate ?? DateTime.now();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (isRequired ? '*' : ' (선택)'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        SizedBox(height: 6),
        Row(
          children: [
            // 날짜 표시 텍스트 (클릭 가능)
            Expanded(
              child: InkWell(
                onTap: isReadOnly ? null : () {
                  _showScrollDatePicker(context, currentDate);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: isReadOnly ? Colors.grey.shade200 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: isReadOnly ? Colors.grey[100] : Colors.white,
                  ),
                  child: Text(
                    controller.text.isEmpty 
                      ? '$label을 선택하세요' 
                      : controller.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: isReadOnly ? Colors.grey[400] : (controller.text.isEmpty ? Colors.grey[500] : Colors.black87),
                    ),
                  ),
                ),
              ),
            ),
            
            SizedBox(width: 8),
            
            // 달력 아이콘 (기존 달력 선택 기능)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: isReadOnly ? null : () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: currentDate,
                    firstDate: firstDate ?? DateTime(2000),
                    lastDate: lastDate ?? DateTime(2030),
                  );
                  if (picked != null) {
                    onDateSelected(picked);
                    controller.text = '${picked.year}년 ${picked.month}월 ${picked.day}일';
                  }
                },
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.calendar_today, 
                    color: isReadOnly ? Colors.grey[300] : Colors.blue[600], 
                    size: 20,
                  ),
                ),
              ),
            ),
            
            SizedBox(width: 4),
            
            // Clear/Reset 버튼
            if (!isRequired && !isReadOnly) 
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    onDateSelected(null);
                    controller.clear();
                  },
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.clear, color: Colors.grey[600], size: 20),
                  ),
                ),
              )
            else if (isRequired && !isReadOnly)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () {
                    final today = DateTime.now();
                    onDateSelected(today);
                    controller.text = '${today.year}년 ${today.month}월 ${today.day}일';
                  },
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.today, color: Colors.green[600], size: 20),
                  ),
                ),
              )
            else if (isReadOnly)
              Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.lock_outline, color: Colors.grey[400], size: 20),
              ),
          ],
        ),
      ],
    );
  }
  
  /// 스크롤 날짜 선택 다이얼로그
  void _showScrollDatePicker(BuildContext context, DateTime currentDate) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ScrollDatePickerDialog(
          currentDate: currentDate,
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime(2030),
          onDateSelected: (date) {
            onDateSelected(date);
            controller.text = '${date.year}년 ${date.month}월 ${date.day}일';
          },
        );
      },
    );
  }
}

