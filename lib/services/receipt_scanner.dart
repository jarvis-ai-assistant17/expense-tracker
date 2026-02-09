import 'dart:io';
import 'package:image_picker/image_picker.dart';

class ReceiptScanner {
  final ImagePicker _picker = ImagePicker();

  // 從相機拍照
  Future<File?> takePhoto() async {
    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    return photo != null ? File(photo.path) : null;
  }

  // 從相簿選擇
  Future<File?> pickFromGallery() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    return image != null ? File(image.path) : null;
  }

  void dispose() {}
}
