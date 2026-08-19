import 'package:flutter/material.dart';

/// 식품 추가 방법 바텀시트를 표시합니다.
Future<void> showAddMethodSheet(
  BuildContext context, {
  required VoidCallback onReceiptScan,
  required VoidCallback onBarcodeScan,
  required VoidCallback onBatchRegistration,
  required VoidCallback onManualAdd,
}) async {
  await showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 드래그 핸들
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                SizedBox(height: 24),
                
                // 제목
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(0xFF6B9FFF),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      '식품 추가',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // 옵션들 (요청 순서: 개별 추가 → 바코드 스캔 → 일괄등록 → 영수증 스캔)
                _AddMethodTile(
                  icon: Icons.edit_rounded,
                  title: '개별 추가',
                  subtitle: '식품 정보를 직접 입력하여 추가',
                  color: Color(0xFF6B9FFF),
                  onTap: () {
                    Navigator.pop(context);
                    onManualAdd();
                  },
                ),
                SizedBox(height: 12),
                
                _AddMethodTile(
                  icon: Icons.qr_code_scanner_rounded,
                  title: '바코드 스캔',
                  subtitle: '제품 바코드를 스캔하여 즉시 등록',
                  color: Color(0xFF6B9FFF),
                  onTap: () {
                    Navigator.pop(context);
                    onBarcodeScan();
                  },
                ),
                SizedBox(height: 12),
                
                _AddMethodTile(
                  icon: Icons.playlist_add_rounded,
                  title: '일괄등록',
                  subtitle: '여러 제품을 연속으로 스캔하여 등록',
                  color: Color(0xFF6B9FFF),
                  onTap: () {
                    Navigator.pop(context);
                    onBatchRegistration();
                  },
                ),
                SizedBox(height: 12),
                
                _AddMethodTile(
                  icon: Icons.receipt_long_rounded,
                  title: '영수증 스캔',
                  subtitle: '카메라로 영수증을 스캔하여 자동 등록',
                  color: Color(0xFF6B9FFF),
                  onTap: () {
                    Navigator.pop(context);
                    onReceiptScan();
                  },
                ),
                
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AddMethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AddMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.all(16),
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
              // 아이콘 배경
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 26,
                ),
              ),
              SizedBox(width: 14),
              
              // 텍스트
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
              
              // 화살표
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


