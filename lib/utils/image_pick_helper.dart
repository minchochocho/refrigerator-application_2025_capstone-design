import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_edit_service.dart';

class ImagePickerHelper {
  /// 이미지 소스 선택 → 촬영/선택 → 크롭 편집기 → 편집된 경로 반환
  static Future<String?> pickAndCrop(BuildContext context) async {
    try {
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('이미지 선택'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('카메라로 촬영'),
                  onTap: () => Navigator.of(context).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('갤러리에서 선택'),
                  onTap: () => Navigator.of(context).pop(ImageSource.gallery),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
            ],
          );
        },
      );

      if (source == null) return null;

      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 90,
      );

      if (pickedFile == null) return null;

      final editor = ImageEditService();
      final editedFile = await editor.openCropEditor(
        context: context,
        imageFile: File(pickedFile.path),
      );

      return editedFile?.path;
    } catch (e) {
      debugPrint('이미지 선택/크기 조정 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지 선택 중 오류가 발생했습니다: $e')),
      );
      return null;
    }
  }
}


