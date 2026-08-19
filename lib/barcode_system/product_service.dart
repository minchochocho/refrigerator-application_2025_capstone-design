import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_model.dart';

class ProductService {
  // Firestore 인스턴스
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 상품 정보 Firestore에 저장
  Future<void> saveProductToFirestore(ProductModel product) async {
    try {
      // 상품 컬렉션에 새 문서 추가
      await _firestore.collection('products').add(product.toFirestore());
    } catch (e) {
      print('상품 정보 저장 중 오류 발생: $e');
      throw e;
    }
  }

  // 바코드 ID로 상품 정보 가져오기
  Future<ProductModel?> getProductByBarcodeId(String barcodeId) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('barcodeId', isEqualTo: barcodeId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        return ProductModel.fromFirestore(doc.data(), doc.id);
      }

      return null;
    } catch (e) {
      print('상품 정보 조회 중 오류 발생: $e');
      return null;
    }
  }

  // 바코드 ID로 상품 정보 삭제
  Future<void> deleteProductByBarcodeId(String barcodeId) async {
    try {
      final querySnapshot = await _firestore
          .collection('products')
          .where('barcodeId', isEqualTo: barcodeId)
          .get();

      // 관련된 모든 상품 정보 삭제
      final batch = _firestore.batch();
      for (var doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('상품 정보 삭제 중 오류 발생: $e');
      throw e;
    }
  }
}