// lib/pages/channel_list_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart'; // 引入 NewsChannel model
import '../providers/channel_provider.dart'; // 引入 Riverpod Providers
import 'settings_page.dart'; // 引入設定頁面
import 'player_page.dart'; // 引入播放器頁面

// 🚨 修正錯誤：這是重構的成果，確保路徑正確 🚨
import '../widgets/channel_card.dart';

// ------------------- ChannelListPage 程式碼開始 -------------------

// ChannelListPage 升級為 ConsumerStatefulWidget
class ChannelListPage extends ConsumerStatefulWidget {
  const ChannelListPage({super.key});

  @override
  ConsumerState<ChannelListPage> createState() => _ChannelListPageState();
}

// State類，並混合 WidgetsBindingObserver
class _ChannelListPageState extends ConsumerState<ChannelListPage>
    with WidgetsBindingObserver {
  // 追蹤 App 是否是第一次啟動
  bool _isInitialStart = true;

  @override
  void initState() {
    super.initState();
    // 啟動生命週期監聽
    WidgetsBinding.instance.addObserver(this);
    // 首次啟動時鎖定
    _lockToLandscape();
  }

  // 從 PlayerPage 返回時會觸發此方法
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialStart) {
      // 給系統 50 毫秒時間完成 PlayerPage 的銷毀
      Future.delayed(const Duration(milliseconds: 50), () {
        // 確保 Widget 仍然在畫面上 (mounted)，才執行鎖定
        if (mounted) {
          _lockToLandscape();
        }
      });
    }
    // 標記為非首次啟動
    _isInitialStart = false;
  }

  // 當 App 從背景或直屏頁面 (Settings) 返回時會觸發
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 每次應用程式恢復時，強制鎖定橫屏
      _lockToLandscape();
    }
  }

  // 輔助函式：強制鎖定為橫屏
  void _lockToLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // 移除生命週期監聽，避免記憶體洩漏
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 導航到設定頁面的函式
  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  // 處理頻道顯示切換
  void _toggleChannelVisibility(BuildContext context) {
    // 使用 ref.read 存取狀態
    final currentStatus = ref.read(showAllChannelsProvider);
    // 切換狀態
    ref.read(showAllChannelsProvider.notifier).state = !currentStatus;

    // 提示用戶狀態已切換
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!currentStatus ? '已顯示所有頻道 (包含隱藏)' : '已隱藏設定中隱藏的頻道'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 監聽 "可見" 的頻道列表
    final channels = ref.watch(visibleChannelListProvider);

    // 監聽切換按鈕的狀態 (我們保留它，因為 AppBar 需要它)
    final isShowingAll = ref.watch(showAllChannelsProvider);

    // 處理初始化載入中狀態
    if (channels.isEmpty &&
        ref.read(channelListProvider.notifier).state.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('新聞直播頻道列表'),
          backgroundColor: Colors.black,
          actions: [
            // 由於是初始載入中，這裡的眼睛按鈕不顯示或保持預設狀態
            IconButton(
              icon: const Icon(Icons.settings, size: 36.0),
              onPressed: () => _navigateToSettings(context),
            ),
          ],
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 處理列表為空（已載入完畢，但沒有頻道）的狀態
    if (channels.isEmpty &&
        ref.read(channelListProvider.notifier).state.isNotEmpty &&
        !isShowingAll) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('新聞直播頻道列表'),
          backgroundColor: Colors.black,
          actions: [
            // 處理空狀態時的「顯示全部」按鈕
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: IconButton(
                icon: Icon(
                  isShowingAll ? Icons.visibility : Icons.visibility_off,
                  size: 36.0,
                  color: isShowingAll ? Colors.redAccent : Colors.white,
                ),
                onPressed: () => _toggleChannelVisibility(context),
              ),
            ),

            IconButton(
              icon: const Icon(Icons.settings, size: 36.0),
              onPressed: () => _navigateToSettings(context),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: IconButton(
                icon: const Icon(Icons.exit_to_app, size: 36.0),
                onPressed: () => SystemNavigator.pop(),
              ),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.tv_off, color: Colors.grey, size: 80),
                const SizedBox(height: 20),
                const Text(
                  '當前沒有可見的直播頻道。',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  '請點擊右上角的設定按鈕，進入「頻道管理」頁面新增或顯示頻道，或點擊眼睛圖示顯示隱藏頻道。',
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton.icon(
                  onPressed: () => _navigateToSettings(context),
                  icon: const Icon(Icons.settings, size: 30),
                  label: const Text('前往設定頁面', style: TextStyle(fontSize: 20)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 實際列表內容 - 卡片式橫向網格佈局
    return Scaffold(
      appBar: AppBar(
        title: const Text('阿爸的電視'),
        backgroundColor: Colors.black,
        actions: [
          // 1. 顯示/隱藏所有頻道按鈕 (眼睛圖示)
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: Icon(
                // 根據狀態切換圖示：顯示全部時為睜開眼，否則為閉上眼
                isShowingAll ? Icons.visibility : Icons.visibility_off,
                size: 36.0,
                color: isShowingAll
                    ? Colors.redAccent
                    : Colors.white, // 給予切換時不同的顏色提示
              ),
              onPressed: () => _toggleChannelVisibility(context),
            ),
          ),

          // 2. 設定按鈕
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: const Icon(Icons.settings, size: 36.0),
              onPressed: () => _navigateToSettings(context),
            ),
          ),
          // 3. 退出按鈕
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: IconButton(
              icon: const Icon(Icons.exit_to_app, size: 36.0),
              onPressed: () => SystemNavigator.pop(),
            ),
          ),
        ],
      ),

      // 【關鍵：簡化後的 GridView.builder】
      body: GridView.builder(
        // 使用 MaxCrossAxisExtent，設置每個卡片的最大寬度
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 165.0, // 設定每個卡片的最大寬度
          mainAxisSpacing: 15.0, // 主軸間距
          crossAxisSpacing: 20.0, // 交叉軸間距
          childAspectRatio: 1.2, // 寬高比
        ),
        padding: const EdgeInsets.all(10.0),
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];

          // 🚨 重構成果：直接使用 ChannelCard 元件 🚨
          return ChannelCard(channel: channel);
        },
      ),
    );
  }
}
// ------------------- ChannelListPage 程式碼結束 -------------------
