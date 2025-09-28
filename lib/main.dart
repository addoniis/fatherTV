// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// 🚨 僅保留必要的基礎導入 🚨
import 'pages/channel_list_page.dart'; // 導入主頁面

void main() async {
  // 確保 Flutter 服務已初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 【全域鎖定螢幕方向為橫向】 (保持不變，鎖定整個 App 的預設方向)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 由於我們使用了 Riverpod 和異步初始化，所以需要用 ProviderScope 包裹
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '新聞直播 App',
      theme: ThemeData(
        // 確保 App 使用最新的 Material 3 設計
        useMaterial3: true,
        primarySwatch: Colors.red,
        // 調整 AppBar 樣式以配合橫向深色主題
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black, // 深色 AppBar
          foregroundColor: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.black, // 設定深色背景
      ),
      // 使用 ChannelListPage，現在它是一個 ConsumerStatefulWidget
      home: const ChannelListPage(),
    );
  }
}
