// lib/pages/changelog_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class ChangelogPage extends StatelessWidget {
  const ChangelogPage({super.key});

  // 輔助方法：讀取 changelog.txt 檔案
  Future<String> _loadChangelogContent() async {
    try {
      // ❗ 載入 changelog.txt ❗
      return await rootBundle.loadString('changelog.txt');
    } catch (e) {
      return '無法載入改版內容。請確認 changelog.txt 檔案存在於專案根目錄，並已在 pubspec.yaml 中宣告。錯誤: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Colors.black;
    const Color textColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '本次更新內容',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
      ),
      backgroundColor: backgroundColor,
      body: FutureBuilder<String>(
        future: _loadChangelogContent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Text(
                '載入失敗: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          // 顯示純文字內容
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              snapshot.data!,
              style: const TextStyle(
                color: textColor,
                fontSize: 16.0,
                height: 1.5,
              ),
            ),
          );
        },
      ),
    );
  }
}
