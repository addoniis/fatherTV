// lib/pages/faq_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
// 移除所有 Markdown 套件的導入

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  // 輔助方法：讀取 FAQ.md 檔案
  Future<String> _loadFaqContent() async {
    try {
      // 確保路徑是正確的 (專案根目錄下的 FAQ.md)
      return await rootBundle.loadString('FAQ.txt');
    } catch (e) {
      // 如果檔案不存在，則返回一個錯誤提示
      return '無法載入 FAQ 檔案。請確認 FAQ.txt 檔案存在於專案根目錄，並已在 pubspec.yaml 中宣告。錯誤: $e';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 定義顏色常量
    const Color backgroundColor = Colors.black;
    const Color textColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '常見問題 (FAQ)',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
      ),
      backgroundColor: backgroundColor,
      body: FutureBuilder<String>(
        future: _loadFaqContent(),
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

          // ❗ 修正：使用 SingleChildScrollView 和 Text 顯示內容 ❗
          // 這樣內容會以純文字格式顯示，但保證不會有任何編譯錯誤。
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              snapshot.data!,
              style: const TextStyle(
                color: textColor,
                fontSize: 16.0,
                // 設定字體間距，讓 Markdown 格式看起來不那麼擁擠
                height: 1.5,
              ),
            ),
          );
        },
      ),
    );
  }
}
