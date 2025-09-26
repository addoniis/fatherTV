import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('關於此 App'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black, // 深色背景
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.tv, // 使用一個電視圖標
                color: Colors.redAccent,
                size: 80,
              ),
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
                '版本號: 1.0.0 (長輩專用優化版)',
                style: TextStyle(color: Colors.grey, fontSize: 18),
              ),
              const SizedBox(height: 30),
              // 加上一些簡單的使用說明或版權資訊
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
