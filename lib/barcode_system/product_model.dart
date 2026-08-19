class ProductModel {
  final String id;
  final String barcodeId;
  final String name;
  final String description;
  final String imageUrl;

  ProductModel({
    required this.id,
    required this.barcodeId,
    required this.name,
    required this.description,
    required this.imageUrl,
  });

  // Firestore에서 가져온 데이터를 ProductModel로 변환
  factory ProductModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return ProductModel(
      id: documentId,
      barcodeId: data['barcodeId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  // ProductModel을 Firestore에 저장할 형태로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'barcodeId': barcodeId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
    };
  }
}