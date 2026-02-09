import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ScanResult {
  final double? amount;
  final String? storeName;
  final DateTime? date;
  final String rawText;
  final List<String> allAmounts;

  ScanResult({
    this.amount,
    this.storeName,
    this.date,
    required this.rawText,
    required this.allAmounts,
  });
}

class ReceiptScanner {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.chinese,
  );

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

  // 掃描圖片並辨識文字
  Future<ScanResult> scanReceipt(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
    
    final rawText = recognizedText.text;
    
    // 找出所有金額
    final allAmounts = _extractAllAmounts(rawText);
    
    // 嘗試找出最可能的金額（通常是最大的，或在「合計」「總計」後面的）
    final amount = _findMainAmount(rawText, allAmounts);
    
    // 嘗試找出店名（通常在發票最上方）
    final storeName = _extractStoreName(recognizedText);
    
    // 嘗試找出日期
    final date = _extractDate(rawText);

    return ScanResult(
      amount: amount,
      storeName: storeName,
      date: date,
      rawText: rawText,
      allAmounts: allAmounts,
    );
  }

  // 提取所有金額
  List<String> _extractAllAmounts(String text) {
    final amounts = <String>[];
    
    // 匹配各種金額格式
    // $123, NT$456, 123元, 123.00, 1,234
    final patterns = [
      RegExp(r'(?:NT\$?|＄|\$)\s*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)'),
      RegExp(r'(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*元'),
      RegExp(r'(?:合計|總計|總額|應付|實付|金額|小計)[^\d]*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)'),
      RegExp(r'(\d{2,6}(?:\.\d{1,2})?)(?=\s|$|\n)'),
    ];

    for (var pattern in patterns) {
      for (var match in pattern.allMatches(text)) {
        if (match.groupCount >= 1) {
          final amountStr = match.group(1)?.replaceAll(',', '');
          if (amountStr != null) {
            final value = double.tryParse(amountStr);
            if (value != null && value > 0 && value < 1000000) {
              amounts.add(amountStr);
            }
          }
        }
      }
    }

    return amounts.toSet().toList(); // 去重
  }

  // 找出主要金額
  double? _findMainAmount(String text, List<String> amounts) {
    if (amounts.isEmpty) return null;

    // 先找「合計」「總計」等關鍵字後的金額
    final totalPatterns = [
      RegExp(r'(?:合計|總計|總額|應付|實付|實收)[^\d]*(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)'),
    ];

    for (var pattern in totalPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.groupCount >= 1) {
        final amountStr = match.group(1)?.replaceAll(',', '');
        if (amountStr != null) {
          final value = double.tryParse(amountStr);
          if (value != null && value > 0) {
            return value;
          }
        }
      }
    }

    // 否則取最大的金額（通常是總額）
    double maxAmount = 0;
    for (var amountStr in amounts) {
      final value = double.tryParse(amountStr.replaceAll(',', '')) ?? 0;
      if (value > maxAmount) {
        maxAmount = value;
      }
    }

    return maxAmount > 0 ? maxAmount : null;
  }

  // 提取店名
  String? _extractStoreName(RecognizedText recognizedText) {
    if (recognizedText.blocks.isEmpty) return null;
    
    // 通常店名在發票最上方的前幾行
    for (var i = 0; i < recognizedText.blocks.length && i < 3; i++) {
      final text = recognizedText.blocks[i].text.trim();
      // 排除明顯不是店名的（日期、統編等）
      if (text.length >= 2 && 
          text.length <= 30 &&
          !RegExp(r'^\d+$').hasMatch(text) &&
          !RegExp(r'\d{4}[/-]\d{1,2}[/-]\d{1,2}').hasMatch(text)) {
        return text;
      }
    }
    return null;
  }

  // 提取日期
  DateTime? _extractDate(String text) {
    // 常見日期格式
    final patterns = [
      RegExp(r'(\d{4})[/-](\d{1,2})[/-](\d{1,2})'),
      RegExp(r'(\d{3})年(\d{1,2})月(\d{1,2})日'), // 民國年
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})'),
    ];

    for (var pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        try {
          int year, month, day;
          
          if (pattern.pattern.contains('年')) {
            // 民國年轉西元年
            year = int.parse(match.group(1)!) + 1911;
            month = int.parse(match.group(2)!);
            day = int.parse(match.group(3)!);
          } else if (match.group(1)!.length == 4) {
            year = int.parse(match.group(1)!);
            month = int.parse(match.group(2)!);
            day = int.parse(match.group(3)!);
          } else {
            month = int.parse(match.group(1)!);
            day = int.parse(match.group(2)!);
            year = int.parse(match.group(3)!);
          }

          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            return DateTime(year, month, day);
          }
        } catch (e) {
          continue;
        }
      }
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
