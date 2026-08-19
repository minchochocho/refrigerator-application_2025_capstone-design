import 'receipt_item.dart';

class SelectableReceiptItem {
  final ReceiptItem item;
  bool selected;
  int quantity;

  SelectableReceiptItem({
    required this.item,
    this.selected = true,
    this.quantity = 1,
  });
}
