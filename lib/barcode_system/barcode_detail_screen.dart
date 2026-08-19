import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'barcode_model.dart';
import 'barcode_service.dart';

class BarcodeDetailScreen extends StatefulWidget {
  final BarcodeModel barcode;

  const BarcodeDetailScreen({Key? key, required this.barcode}) : super(key: key);

  @override
  State<BarcodeDetailScreen> createState() => _BarcodeDetailScreenState();
}

class _BarcodeDetailScreenState extends State<BarcodeDetailScreen> {
  late BarcodeModel _currentBarcode;
  bool _isUpdatingImage = false;

  @override
  void initState() {
    super.initState();
    _currentBarcode = widget.barcode;
  }

  // 바코드 값 클립보드에 복사
  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _currentBarcode.barcodeId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('바코드 값이 클립보드에 복사되었습니다.')),
      );
    }
  }

  // 이미지 삭제
  Future<void> _deleteImage() async {
    if (_isUpdatingImage) return;

    setState(() => _isUpdatingImage = true);

    try {
      const defaultImageUrl = '';
      await BarcodeService().updateBarcodeImage(_currentBarcode.id, defaultImageUrl);

      setState(() {
        _currentBarcode = _currentBarcode.copyWith(imageUrl: defaultImageUrl);
        _isUpdatingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미지가 삭제되었습니다.')),
        );
      }
    } catch (e) {
      setState(() => _isUpdatingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 삭제 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('바코드 상세 정보'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box),
            onPressed: () => Navigator.pop(context, 'add_ingredient'),
            tooltip: '재료로 추가',
          ),
          IconButton(
            icon: const Icon(Icons.content_copy),
            onPressed: _copyToClipboard,
            tooltip: '바코드 복사',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBarcodeInfoCard(),
            const SizedBox(height: 20),
            _buildProductInfoCard(),
          ],
        ),
      ),
    );
  }

  // 바코드 정보 카드
  Widget _buildBarcodeInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('바코드 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildInfoRow('바코드 값', _currentBarcode.barcodeId),
            _buildInfoRow('바코드 유형', _currentBarcode.barcodeType),
            _buildInfoRow('스캔 날짜', _currentBarcode.formattedDate),
            if (_currentBarcode.expirationDate.isNotEmpty)
              _buildInfoRow('유통기한', _currentBarcode.expirationDate),
          ],
        ),
      ),
    );
  }

  // 상품 정보 카드
  Widget _buildProductInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('상품 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            _buildProductImageSection(),
            const SizedBox(height: 16),
            Text(
              _currentBarcode.foodName.isNotEmpty ? _currentBarcode.foodName : '상품 정보가 없습니다',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (_currentBarcode.expirationDate.isNotEmpty) _buildExpirationDateSection(),
          ],
        ),
      ),
    );
  }

  // 상품 이미지 섹션
  Widget _buildProductImageSection() {
    return Container(
      width: double.infinity,
      height: 200,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Container(
              width: double.infinity,
              height: 200,
              child: _buildProductImage(),
            ),
          ),
          if (_currentBarcode.imageUrl.isNotEmpty && _currentBarcode.imageUrl != '' && !_isUpdatingImage)
            _buildDeleteButton(),
          if (_isUpdatingImage) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  // 상품 이미지 위젯
  Widget _buildProductImage() {
    if (_currentBarcode.isLocalImage) {
      return Image.asset(
        _currentBarcode.assetPath,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _buildNoImagePlaceholder(),
      );
    } else if (_currentBarcode.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _currentBarcode.imageUrl,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
        errorWidget: (_, __, ___) => _buildNoImagePlaceholder(),
      );
    } else {
      return _buildNoImagePlaceholder();
    }
  }

  // 삭제 버튼
  Widget _buildDeleteButton() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.delete, color: Colors.white, size: 20),
          onPressed: _deleteImage,
          tooltip: '이미지 삭제',
        ),
      ),
    );
  }

  // 로딩 오버레이
  Widget _buildLoadingOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  // 이미지 플레이스홀더
  Widget _buildNoImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
          SizedBox(height: 8),
          Text('이미지가 없습니다', style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }

  // 유통기한 섹션
  Widget _buildExpirationDateSection() {
    return Container(
      margin: const EdgeInsets.only(top: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            '유통기한: ${_currentBarcode.expirationDate}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  // 정보 행 위젯
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}