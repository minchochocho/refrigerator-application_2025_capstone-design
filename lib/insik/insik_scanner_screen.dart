import 'package:flutter/material.dart';
import 'legacy_scanner.dart' show ReceiptScannerHomePage;

/// 기존 친구 코드의 화면(ReceiptScannerHomePage)을
/// 앱 내 라우트에서 바로 열 수 있도록 래핑한 위젯
class InsikReceiptScannerScreen extends StatelessWidget {
  const InsikReceiptScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ReceiptScannerHomePage();
  }
}


