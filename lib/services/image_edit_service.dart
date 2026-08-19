import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../screens/image_editor/crop_editor_screen.dart';

class ImageEditService {
  static final ImageEditService _instance = ImageEditService._internal();
  factory ImageEditService() => _instance;
  ImageEditService._internal();

  Future<File?> openCropEditor({
    required BuildContext context,
    required File imageFile,
    double? aspectRatio,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final File? result = await Navigator.of(context, rootNavigator: true).push<File?>(
      MaterialPageRoute(
        builder: (_) => CropEditorScreen(
          imageBytes: bytes,
          aspectRatio: aspectRatio,
        ),
      ),
    );
    return result;
  }
}


