import 'package:flutter/material.dart';

class ExpiringBottomSheet extends StatelessWidget {
  final List<Map<String, dynamic>> expiringItems;
  final IconData Function(String) foodIconForName;
  final String Function(int) dayText;
  final Color Function(int) dayColor;

  const ExpiringBottomSheet({
    super.key,
    required this.expiringItems,
    required this.foodIconForName,
    required this.dayText,
    required this.dayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[600]),
              SizedBox(width: 8),
              Text(
                '유통기한 임박 식품',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: expiringItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64,
                          color: Colors.green[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          '유통기한이 임박한 식품이 없습니다',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: expiringItems.length,
                    itemBuilder: (context, index) {
                      final ingredient = expiringItems[index];
                      final expiryDate = ingredient['expiryDate']?.toDate();
                      final now = DateTime.now();
                      final daysLeft = expiryDate != null
                          ? DateTime(expiryDate.year, expiryDate.month, expiryDate.day)
                              .difference(DateTime(now.year, now.month, now.day))
                              .inDays
                          : 0;
                      final isExpired = daysLeft < 0;
                      return Container(
                        margin: EdgeInsets.only(bottom: 12),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isExpired ? Colors.red[50] : Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isExpired ? Colors.red[300]! : Colors.orange[300]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              foodIconForName(ingredient['name'] ?? ''),
                              color: isExpired ? Colors.red[600] : Colors.orange[600],
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ingredient['name'] ?? '',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    dayText(daysLeft),
                                    style: TextStyle(
                                      color: dayColor(daysLeft),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isExpired)
                              Icon(
                                Icons.dangerous,
                                color: Colors.red[600],
                                size: 20,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


