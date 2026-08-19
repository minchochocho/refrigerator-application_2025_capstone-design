import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:extended_image/extended_image.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class CropEditorScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final double? aspectRatio; // null이면 자유 크롭

  const CropEditorScreen({
    super.key,
    required this.imageBytes,
    this.aspectRatio,
  });

  @override
  State<CropEditorScreen> createState() => _CropEditorScreenState();
}

class _CropEditorScreenState extends State<CropEditorScreen> {
  final GlobalKey<ExtendedImageEditorState> _editorKey = GlobalKey<ExtendedImageEditorState>();
  bool _isCropping = false;

  Future<void> _onDone() async {
    if (_isCropping) return;
    setState(() {
      _isCropping = true;
    });
    final state = _editorKey.currentState;
    if (state == null) {
      setState(() => _isCropping = false);
      return;
    }
    final cropRect = state.getCropRect();
    if (cropRect == null) {
      setState(() => _isCropping = false);
      return;
    }
    try {
      // 원본 디코드
      final original = img.decodeImage(widget.imageBytes);
      if (original == null) {
        setState(() => _isCropping = false);
        return;
      }
      // 크롭 좌표 클램프
      final int x = cropRect.left.clamp(0, original.width.toDouble()).toInt();
      final int y = cropRect.top.clamp(0, original.height.toDouble()).toInt();
      final int w = cropRect.width.clamp(1, (original.width - x).toDouble()).toInt();
      final int h = cropRect.height.clamp(1, (original.height - y).toDouble()).toInt();

      final cropped = img.copyCrop(original, x: x, y: y, width: w, height: h);
      final bytes = img.encodeJpg(cropped, quality: 90);

      final tmpDir = await getTemporaryDirectory();
      final file = File('${tmpDir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        Navigator.of(context).pop<File?>(file);
      }
    } catch (e) {
      // 실패 시 종료 처리
      if (mounted) {
        setState(() => _isCropping = false);
        Navigator.of(context).pop<File?>(null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isCropping) return false;
        return true; // 뒤로가기 허용
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('이미지 편집'),
          actions: [
            // 사용 중인 crop_your_image 버전에서 컨트롤러 회전/스케일/리셋 API 미제공 → 간소화
            TextButton(
              onPressed: _isCropping ? null : _onDone,
              child: const Text('완료', style: TextStyle(color: Colors.blue, fontSize: 16)),
            ),
          ],
        ),
      body: Stack(
        children: [
          Positioned.fill(
            child: ExtendedImage.memory(
              widget.imageBytes,
              fit: BoxFit.contain,
              mode: ExtendedImageMode.editor,
              extendedImageEditorKey: _editorKey,
              initEditorConfigHandler: (state) {
                return EditorConfig(
                  maxScale: 12.0,
                  hitTestSize: 36.0,
                  cropRectPadding: const EdgeInsets.all(8),
                  cornerColor: Colors.blueAccent,
                  cornerSize: const Size(20, 3),
                  lineColor: Colors.white70,
                  lineHeight: 1.2,
                  initCropRectType: InitCropRectType.imageRect,
                  cropAspectRatio: widget.aspectRatio,
                );
              },
            ),
          ),
          if (_isCropping)
            const Align(
              alignment: Alignment.center,
              child: CircularProgressIndicator(color: Colors.white),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _isCropping ? null : () => Navigator.of(context).pop<File?>(null),
                icon: const Icon(Icons.close, color: Colors.white70),
                label: const Text('취소', style: TextStyle(color: Colors.white70)),
              ),
              const Text('핀치/드래그로 조절하세요', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
      ),
    );
  }
}


