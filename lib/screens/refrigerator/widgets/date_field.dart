import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../widgets/ingredients/scroll_date_picker_dialog.dart';

/// 통일된 날짜 선택 필드 위젯
class DateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final DateTime? selectedDate;
  final void Function(DateTime?) onDateSelected;
  final bool isRequired;
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;

  const DateField({
    super.key,
    required this.label,
    required this.controller,
    required this.selectedDate,
    required this.onDateSelected,
    required this.isRequired,
    this.initialDate,
    this.firstDate,
    this.lastDate,
  });

  void _showScrollDatePicker({
    required BuildContext context,
    required DateTime currentDate,
    required void Function(DateTime) onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ScrollDatePickerDialog(
          currentDate: currentDate,
          firstDate: firstDate ?? DateTime(2000),
          lastDate: lastDate ?? DateTime(2030),
          onDateSelected: onConfirm,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime currentDate = selectedDate ?? initialDate ?? DateTime.now();

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
            Expanded(
              child: InkWell(
                onTap: () {
                  _showScrollDatePicker(
                    context: context,
                    currentDate: currentDate,
                    onConfirm: (date) {
                      onDateSelected(date);
                      controller.text = '${date.year}년 ${date.month}월 ${date.day}일';
                    },
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    controller.text.isEmpty
                        ? '$label을 선택하세요'
                        : controller.text,
                    style: TextStyle(
                      fontSize: 16,
                      color: controller.text.isEmpty
                          ? Colors.grey[500]
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () async {
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
                  child: Icon(Icons.calendar_today, color: Colors.blue[600], size: 20),
                ),
              ),
            ),
            SizedBox(width: 4),
            if (!isRequired)
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
            else
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
              ),
          ],
        ),
      ],
    );
  }
}


