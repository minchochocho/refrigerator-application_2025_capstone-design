import 'package:flutter/material.dart';
import '../../../models/receipt_item.dart';
import '../../../models/selectable_receipt_item.dart';
import '../utils/ingredient_utils.dart';

/// 영수증 스캔 옵션 선택 다이얼로그
class ReceiptScanDialog extends StatelessWidget {
  final VoidCallback onCameraTap;
  final VoidCallback onGalleryTap;
  
  const ReceiptScanDialog({
    Key? key,
    required this.onCameraTap,
    required this.onGalleryTap,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 아이콘
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Color(0xFF6B9FFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFF6B9FFF),
                size: 28,
              ),
            ),
            SizedBox(height: 20),
            
            // 제목
            Text(
              '영수증으로 일괄 추가',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            
            // 설명
            Text(
              '영수증을 스캔하여 여러 식품을\n한번에 등록할 수 있습니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            
            // 옵션들
            Column(
              children: [
                _buildOptionTile(
                  icon: Icons.camera_alt_rounded,
                  title: '카메라로 촬영',
                  subtitle: '영수증을 직접 촬영하여 스캔',
                  onTap: () {
                    Navigator.pop(context);
                    onCameraTap();
                  },
                ),
                SizedBox(height: 12),
                _buildOptionTile(
                  icon: Icons.photo_library_rounded,
                  title: '갤러리에서 선택',
                  subtitle: '저장된 영수증 이미지 선택',
                  onTap: () {
                    Navigator.pop(context);
                    onGalleryTap();
                  },
                ),
              ],
            ),
            SizedBox(height: 20),
            
            // 취소 버튼
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: Text(
                '취소',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.withOpacity(0.15),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Color(0xFF6B9FFF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Color(0xFF6B9FFF), size: 26),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 영수증 결과 확인 화면 (일괄등록 수량 선택 UI와 유사한 전체 화면)
class ReceiptResultDialog extends StatefulWidget {
  final Receipt receipt;
  final Future<void> Function(List<SelectableReceiptItem> selectedItems) onSave;

  const ReceiptResultDialog({
    Key? key,
    required this.receipt,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ReceiptResultDialog> createState() => _ReceiptResultDialogState();
}

class _ReceiptResultDialogState extends State<ReceiptResultDialog> {
  late List<SelectableReceiptItem> selectable;

  @override
  void initState() {
    super.initState();
    selectable = widget.receipt.items
        .map((i) => SelectableReceiptItem(
              item: i,
              selected: true,
              quantity: i.quantity ?? 1,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = selectable.where((e) => e.selected).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        title: const Text(
          '수량 선택',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 상단 구매 정보
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '구매일: ${IngredientUtils.formatDate(widget.receipt.date)}'
                '${widget.receipt.totalAmount != null ? ' · 총액: ${widget.receipt.totalAmount!.toStringAsFixed(0)}원' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),
          // 목록
          Expanded(
            child: selectable.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: 40,
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '인식된 항목이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                    itemCount: selectable.length,
                    itemBuilder: (context, index) {
                      final s = selectable[index];
                      final item = s.item;
                      return Container(
                        margin: EdgeInsets.only(
                            bottom: index == selectable.length - 1 ? 0 : 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.grey.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 아이콘 영역
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: const Color(0xFFF5F5F5),
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                ),
                              ),
                              child: Icon(
                                Icons.shopping_basket_rounded,
                                size: 24,
                                color: Colors.grey[400],
                              ),
                            ),
                            const SizedBox(width: 14),
                            // 텍스트 영역
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[900],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  if (item.price != null)
                                    Text(
                                      '${item.price!.toStringAsFixed(0)}원',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 수량 조절
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: s.quantity > 1
                                      ? () {
                                          setState(() {
                                            s.quantity -= 1;
                                          });
                                        }
                                      : null,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: s.quantity > 1
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.remove,
                                      size: 16,
                                      color: s.quantity > 1
                                          ? Colors.red[400]
                                          : Colors.grey[400],
                                    ),
                                  ),
                                ),
                                Container(
                                  width: 32,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${s.quantity}',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[900],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      s.quantity += 1;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(
                                      Icons.add,
                                      size: 16,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // 선택 체크박스
                                Checkbox(
                                  value: s.selected,
                                  onChanged: (v) {
                                    setState(() {
                                      s.selected = v ?? true;
                                    });
                                  },
                                  activeColor: const Color(0xFF6B9FFF),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // 하단 버튼
          if (selectable.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '선택된 항목: $selectedCount개',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: selectedCount == 0
                            ? null
                            : () async {
                                final selected = selectable
                                    .where((e) => e.selected)
                                    .toList();
                                await widget.onSave(selected);
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B9FFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.download_rounded, size: 20),
                            SizedBox(width: 6),
                            Text(
                              '선택 항목 추가',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}

