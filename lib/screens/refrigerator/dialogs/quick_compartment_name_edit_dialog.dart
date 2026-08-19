import 'package:flutter/material.dart';

Future<void> showQuickCompartmentNameEditDialog(
  BuildContext context, {
  required String currentName,
  required VoidCallback onOpenSettings,
  required Future<void> Function(String newName) onSubmit,
}) async {
  final controller = TextEditingController(text: currentName);

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(Icons.edit_outlined, color: Colors.blue[600]),
          SizedBox(width: 8),
          Text('칸 이름 수정'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '이 칸의 이름을 변경하시겠습니까?',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: '칸 이름',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            maxLength: 20,
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('취소'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onOpenSettings();
          },
          child: Text('전체 설정'),
        ),
        ElevatedButton(
          onPressed: () async {
            final newName = controller.text.trim();
            if (newName.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('칸 이름을 입력해주세요')),
              );
              return;
            }
            Navigator.pop(context);
            await onSubmit(newName);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text('변경'),
        ),
      ],
    ),
  );
}


