import 'package:cloud_firestore/cloud_firestore.dart';

/// 영수증에서 인식된 상품 정보 모델
class ReceiptItem {
  final String name;        // 상품명
  final double? price;      // 가격 (옵션)
  final int? quantity;      // 수량 (옵션)
  final String? category;   // 카테고리 (음식, 생활용품 등)
  final DateTime? expiryDate; // 유통기한 (옵션)

  ReceiptItem({
    required this.name,
    this.price,
    this.quantity,
    this.category,
    this.expiryDate,
  });

  /// Firestore에서 데이터를 가져올 때 사용
  factory ReceiptItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ReceiptItem(
      name: data['name'] ?? '',
      price: data['price']?.toDouble(),
      quantity: data['quantity']?.toInt(),
      category: data['category'],
      expiryDate: data['expiryDate'] != null 
          ? (data['expiryDate'] as Timestamp).toDate()
          : null,
    );
  }

  /// Firestore에 저장할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'price': price,
      'quantity': quantity,
      'category': category,
      'expiryDate': expiryDate != null 
          ? Timestamp.fromDate(expiryDate!)
          : null,
      'createdAt': Timestamp.now(),
    };
  }

  /// 재료 모델로 변환 (냉장고에 추가할 때 사용)
  Map<String, dynamic> toIngredient({
    required String compartmentId,
    String? userId,
  }) {
    return {
      'name': name,
      'quantity': quantity ?? 1,
      'unit': _getDefaultUnit(),
      'expiryDate': expiryDate != null 
          ? Timestamp.fromDate(expiryDate!)
          : null,
      'category': category ?? _categorizeItem(name),
      'compartmentId': compartmentId,
      'userId': userId,
      'addedAt': Timestamp.now(),
      'isExpired': false,
      'source': 'receipt', // 영수증에서 추가됨을 표시
    };
  }

  /// 상품명으로 기본 단위 추정
  String _getDefaultUnit() {
    String lowerName = name.toLowerCase();
    
    if (lowerName.contains('우유') || lowerName.contains('음료') || 
        lowerName.contains('주스') || lowerName.contains('물')) {
      return 'L';
    } else if (lowerName.contains('고기') || lowerName.contains('생선') ||
               lowerName.contains('치킨') || lowerName.contains('돼지') ||
               lowerName.contains('소고기')) {
      return 'kg';
    } else if (lowerName.contains('빵') || lowerName.contains('과자') ||
               lowerName.contains('사탕') || lowerName.contains('초콜릿')) {
      return '개';
    } else if (lowerName.contains('야채') || lowerName.contains('과일') ||
               lowerName.contains('당근') || lowerName.contains('양파') ||
               lowerName.contains('사과') || lowerName.contains('바나나')) {
      return 'kg';
    }
    
    return '개'; // 기본값
  }

  /// 상품명으로 카테고리 추정
  String _categorizeItem(String itemName) {
    String lowerName = itemName.toLowerCase();
    
    // 육류
    if (lowerName.contains('고기') || lowerName.contains('생선') ||
        lowerName.contains('치킨') || lowerName.contains('돼지') ||
        lowerName.contains('소고기') || lowerName.contains('닭')) {
      return '육류';
    }
    
    // 유제품
    if (lowerName.contains('우유') || lowerName.contains('치즈') ||
        lowerName.contains('요구르트') || lowerName.contains('버터')) {
      return '유제품';
    }
    
    // 채소
    if (lowerName.contains('야채') || lowerName.contains('당근') ||
        lowerName.contains('양파') || lowerName.contains('배추') ||
        lowerName.contains('무') || lowerName.contains('시금치')) {
      return '채소';
    }
    
    // 과일
    if (lowerName.contains('과일') || lowerName.contains('사과') ||
        lowerName.contains('바나나') || lowerName.contains('딸기') ||
        lowerName.contains('포도') || lowerName.contains('오렌지')) {
      return '과일';
    }
    
    // 음료
    if (lowerName.contains('음료') || lowerName.contains('주스') ||
        lowerName.contains('사이다') || lowerName.contains('콜라') ||
        lowerName.contains('물') || lowerName.contains('차')) {
      return '음료';
    }
    
    // 간식
    if (lowerName.contains('과자') || lowerName.contains('사탕') ||
        lowerName.contains('초콜릿') || lowerName.contains('빵') ||
        lowerName.contains('쿠키') || lowerName.contains('아이스크림')) {
      return '간식';
    }
    
    return '기타'; // 기본값
  }

  /// 값 복사하여 새 인스턴스 생성 (수량 변경 등에 사용)
  ReceiptItem copyWith({
    String? name,
    double? price,
    int? quantity,
    String? category,
    DateTime? expiryDate,
  }) {
    return ReceiptItem(
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  @override
  String toString() {
    return 'ReceiptItem(name: $name, price: $price, quantity: $quantity, category: $category)';
  }
}

/// 영수증 전체 정보 모델
class Receipt {
  final String id;
  final String storeName;      // 상점명
  final DateTime date;         // 구매 날짜
  final List<ReceiptItem> items; // 상품 목록
  final double? totalAmount;   // 총 금액
  final String? userId;        // 사용자 ID

  Receipt({
    required this.id,
    required this.storeName,
    required this.date,
    required this.items,
    this.totalAmount,
    this.userId,
  });

  /// Firestore에서 데이터를 가져올 때 사용
  factory Receipt.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    List<ReceiptItem> items = [];
    if (data['items'] != null) {
      items = (data['items'] as List)
          .map((item) => ReceiptItem(
                name: item['name'] ?? '',
                price: item['price']?.toDouble(),
                quantity: item['quantity']?.toInt(),
                category: item['category'],
              ))
          .toList();
    }

    return Receipt(
      id: doc.id,
      storeName: data['storeName'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      items: items,
      totalAmount: data['totalAmount']?.toDouble(),
      userId: data['userId'],
    );
  }

  /// Firestore에 저장할 때 사용
  Map<String, dynamic> toFirestore() {
    return {
      'storeName': storeName,
      'date': Timestamp.fromDate(date),
      'items': items.map((item) => {
        'name': item.name,
        'price': item.price,
        'quantity': item.quantity,
        'category': item.category,
      }).toList(),
      'totalAmount': totalAmount,
      'userId': userId,
      'createdAt': Timestamp.now(),
    };
  }
} 