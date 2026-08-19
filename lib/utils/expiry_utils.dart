import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ExpiryUtils {
  static Future<int> getExpiringItemsCount({
    required String roomId,
    required String refrigeratorName,
  }) async {
    try {
      final now = DateTime.now();
      int count = 0;

      final refrigeratorSnapshot = await FirebaseFirestore.instance
          .collection('Refrigerators')
          .where('room_id', isEqualTo: roomId)
          .where('name', isEqualTo: refrigeratorName)
          .limit(1)
          .get();

      if (refrigeratorSnapshot.docs.isNotEmpty) {
        final refrigeratorDoc = refrigeratorSnapshot.docs.first;
        final refrigeratorData = refrigeratorDoc.data();

        final compartmentNames = List<String>.from(
          refrigeratorData['compartment_names'] ?? [],
        );

        for (int compartmentIndex = 0;
            compartmentIndex < compartmentNames.length;
            compartmentIndex++) {
          final ingredientsSnapshot = await refrigeratorDoc.reference
              .collection('compartments')
              .doc(compartmentIndex.toString())
              .collection('ingredients')
              .get();

          for (final ingredientDoc in ingredientsSnapshot.docs) {
            final ingredientData = ingredientDoc.data();
            final dynamic expiryField = ingredientData['expiryDate'];

            DateTime? expiryDate;
            if (expiryField is Timestamp) {
              expiryDate = expiryField.toDate();
            } else if (expiryField is String) {
              expiryDate = DateTime.tryParse(expiryField);
            }

            if (expiryDate == null) continue;

            final daysLeft = DateTime(
              expiryDate.year,
              expiryDate.month,
              expiryDate.day,
            ).difference(DateTime(now.year, now.month, now.day)).inDays;

            if (daysLeft <= 3) {
              count++;
            }
          }
        }
      }

      return count;
    } catch (e) {
      debugPrint('만료 예정 아이템 카운트 오류: $e');
      return 0;
    }
  }
}


