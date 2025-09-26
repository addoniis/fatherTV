// lib/services/backup_service.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data'; // <-- 引入，用於處理檔案內容的位元組

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // 用於 debugPrint

import '../models/channel.dart';
// import 'database_service.dart'; // 移除：BackupService 不直接操作資料庫

// ---------------------------------------------
// BackupService 負責檔案操作，不直接操作資料庫
// ---------------------------------------------
class BackupService {
  // 1. 匯出頻道數據到 JSON
  // 參數: 傳入要匯出的完整頻道列表
  Future<String?> exportChannels(List<NewsChannel> channels) async {
    try {
      if (channels.isEmpty) {
        return null; // 無頻道可匯出
      }

      // 1.1 將 NewsChannel 列表轉換為 JSON 字串
      final List<Map<String, dynamic>> jsonList = channels
          .map((c) => c.toJson())
          .toList();

      // 【修正點】: 使用 JsonEncoder.withIndent 格式化 JSON
      const encoder = JsonEncoder.withIndent('  '); // 使用兩個空格縮排
      final String jsonString = encoder.convert(jsonList);

      // 1.2 將 JSON 字串轉換為 Bytes (Uint8List)
      final Uint8List fileBytes = Uint8List.fromList(utf8.encode(jsonString));

      // 取得預設檔案名稱
      final String timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[T\-\.]|:\d+'), '_')
          .substring(0, 15);

      final String defaultFileName = 'news_channels_backup_$timestamp.json';

      // 1.3 讓用戶選擇儲存位置，並將 Bytes 傳入
      String? savePath = await FilePicker.platform.saveFile(
        dialogTitle: '請選擇頻道備份檔案的儲存位置',
        fileName: defaultFileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: fileBytes, // 傳入檔案內容 (Bytes)
      );

      if (savePath != null) {
        // 使用 file_picker 傳入 bytes 後，檔案會自動儲存，不需要再手動寫入
        debugPrint('頻道列表已匯出到: $savePath');
        return savePath;
      }

      return null; // 用戶取消
    } catch (e) {
      debugPrint('匯出頻道時發生錯誤: $e');
      return null;
    }
  }

  // 2. 從 JSON 檔案匯入頻道數據 (保持不變)
  // 回傳: 匯入的 NewsChannel 列表，如果失敗則回傳 null
  Future<List<NewsChannel>?> importChannels() async {
    try {
      // 2.1 選擇檔案
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return null; // 未選擇檔案或用戶取消
      }

      final String filePath = result.files.single.path!;
      final File file = File(filePath);

      // 2.2 讀取檔案內容並解析 JSON
      final String jsonString = await file.readAsString();
      final List<dynamic> rawList = jsonDecode(jsonString);

      // 使用 NewsChannel.fromJson() 構建物件
      final List<NewsChannel> importedChannels = rawList.map((map) {
        return NewsChannel.fromJson(map as Map<String, dynamic>);
      }).toList();

      if (importedChannels.isEmpty) {
        return []; // 檔案為空，回傳空列表
      }

      debugPrint('成功從 $filePath 匯入 ${importedChannels.length} 個頻道。');
      return importedChannels; // 成功回傳列表
    } catch (e) {
      debugPrint('匯入頻道時發生錯誤: $e');
      return null;
    }
  }
}

// 供 Riverpod 使用
final backupServiceProvider = Provider((ref) => BackupService());
