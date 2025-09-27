import 'package:flutter/material.dart';
// ❗ 確保導入 changelog 頁面 ❗
import 'changelog_page.dart';
// 移除：import 'faq_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  // 輔助方法：建構 List Tile (現在只用於更新內容)
  Widget _buildChangelogTile(
    BuildContext context,
    IconData icon,
    String title,
    Widget targetPage,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (ctx) => targetPage));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('關於此 App'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.tv, color: Colors.redAccent, size: 80),
              const SizedBox(height: 20),
              const Text(
                '新聞直播 App',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '版本號: 1.2.2',
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
              const SizedBox(height: 40),

              // --- 資訊選項列表 ---
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    // ❗ 只保留：本次更新內容按鈕 ❗
                    _buildChangelogTile(
                      context,
                      Icons.history,
                      '本次更新內容',
                      const ChangelogPage(), // 導航至 ChangelogPage
                    ),
                    // 移除：FAQ 的 ListTile 和 Divider
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // --- 底部版權和說明 ---
              const Text(
                '此應用程式旨在為長輩提供一個極簡、操作便利的新聞直播觀看體驗。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 5),
              const Text(
                '資料來源：YouTube 公開直播頻道。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
