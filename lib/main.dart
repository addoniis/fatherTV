// lib/main.dart

import 'dart:async'; // 引入 Timer 類
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart'; // 引入 System 服務

// 引入我們為數據持久化建立的組件
import 'models/channel.dart';
import 'providers/channel_provider.dart';
// 這裡引入了 ChannelManagementPage，雖然沒有在主頁面使用，但設定頁面可能會使用
import 'pages/channel_management_page.dart';
// 引入新的設定頁面
import 'package:news_stream_app/pages/settings_page.dart';

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
      // 使用 ChannelListPage，現在它是一個 ConsumerWidget
      home: const ChannelListPage(),
    );
  }
}

// 主頁：頻道列表 (改為 ConsumerWidget 以監聽 Riverpod 狀態)
class ChannelListPage extends ConsumerWidget {
  const ChannelListPage({super.key});

  // 導航到設定頁面的函式，避免重複程式碼
  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 監聽 "可見" 的頻道列表
    final channels = ref.watch(visibleChannelListProvider);

    // 處理初始化載入中狀態
    if (channels.isEmpty &&
        ref.read(channelListProvider.notifier).state.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('新聞直播頻道列表'),
          backgroundColor: Colors.black,
          actions: [
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
        ref.read(channelListProvider.notifier).state.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('新聞直播頻道列表'),
          backgroundColor: Colors.black,
          actions: [
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
                  '請點擊右上角的設定按鈕，進入「頻道管理」頁面新增或顯示頻道。',
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
          // 1. 設定按鈕 - 放大點擊範圍和圖標
          Padding(
            padding: const EdgeInsets.only(right: 12.0), // ⬅ 新增右邊距 12.0 像素
            child: IconButton(
              icon: const Icon(
                Icons.settings,
                size: 36.0, // ⬅ 放大設定圖標
              ),
              onPressed: () => _navigateToSettings(context),
            ),
          ),
          // 2. 橫向時常有的返回 App 退出按鈕 - 放大點擊範圍和圖標
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: IconButton(
              icon: const Icon(
                Icons.exit_to_app,
                size: 36.0, // ⬅ 放大退出圖標
              ),
              onPressed: () => SystemNavigator.pop(),
            ),
          ),
        ],
      ),

      // 【關鍵修正：使用 MaxExtent 確保 5 欄顯示】
      body: GridView.builder(
        // 使用 MaxCrossAxisExtent，設置每個卡片的最大寬度
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          // 設定每個卡片的最大寬度為 180 像素。 Adonis
          maxCrossAxisExtent: 165.0, //原150.0
          mainAxisSpacing: 15.0, // 主軸間距
          crossAxisSpacing: 20.0, // 交叉軸間距
          // 修正：調整寬高比為 1.2，為下方的頻道名稱騰出空間
          childAspectRatio: 1.2, // ⬅ 調整頻道縮圖比例 Adonis
        ),
        padding: const EdgeInsets.all(10.0),
        itemCount: channels.length,
        itemBuilder: (context, index) {
          final channel = channels[index];
          // 根據 videoId 構造縮圖 URL
          final thumbnailUrl =
              'https://img.youtube.com/vi/${channel.videoId}/hqdefault.jpg';

          return InkWell(
            onTap: () {
              // 點擊後導航到播放器頁面
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PlayerPage(channel: channel),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 頂部的縮圖區域 (佔滿剩餘垂直空間)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black, // 背景色，用於圖片載入失敗時
                      borderRadius: BorderRadius.circular(8.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          spreadRadius: 1,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Stack(
                        fit: StackFit.expand, // 讓 Stack 充滿父容器
                        children: [
                          // 【縮圖圖片】
                          Image.network(
                            thumbnailUrl,
                            fit: BoxFit.cover, // 確保圖片覆蓋整個卡片
                            // 圖片載入失敗時，顯示一個預設圖示
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.error_outline,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              );
                            },
                          ),

                          // 模擬 LIVE 標籤 (位於卡片右上方) - 保留
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 2. 獨立的頻道名稱 (新增到 Expanded 圖片的下方)
                Padding(
                  // 增加一些垂直和水平內邊距
                  padding: const EdgeInsets.only(
                    top: 0.0, //頻道名稱文字的padding Adonis
                    left: 4.0,
                    right: 4.0,
                    bottom: 0.0,
                  ),
                  child: Text(
                    channel.name,
                    textAlign: TextAlign.center, // 讓名稱置中
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14, //頻道名稱文字的大小 Adonis
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2, // 允許名稱換行
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 播放器頁面 (已修正為單按鈕鎖定/解鎖，並確保按鈕顯示)
class PlayerPage extends StatefulWidget {
  final NewsChannel channel;
  const PlayerPage({super.key, required this.channel});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late YoutubePlayerController _controller;
  // 追蹤螢幕是否鎖定
  bool _isLocked = false;
  // 【新增】: 追蹤鎖定提示層是否顯示
  bool _showLockOverlay = false;
  // 【新增】: 用於計時器
  Timer? _lockOverlayTimer;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.channel.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        isLive: true,
        forceHD: true,
      ),
    );

    // 播放器頁面強制鎖定為橫向
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 隱藏系統狀態列和導航列 (讓畫面最大化)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  // 鎖定/解鎖操作
  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked; // 切換鎖定狀態
    });

    if (_isLocked) {
      // 【鎖定時】: 顯示提示，並啟動 5 秒計時器
      setState(() {
        _showLockOverlay = true;
      });
      // 取消舊的計時器 (如果存在)
      _lockOverlayTimer?.cancel();
      // 啟動新的 5 秒計時器
      _lockOverlayTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showLockOverlay = false; // 5 秒後隱藏浮層
          });
        }
      });
    } else {
      // 【解鎖時】: 立即隱藏提示，並取消計時器
      _lockOverlayTimer?.cancel();
      setState(() {
        _showLockOverlay = false;
      });
    }

    // 提供視覺回饋 (可選，Snackbar 可能會與全螢幕體驗衝突，但暫時保留)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isLocked ? '螢幕已鎖定' : '螢幕已解鎖'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // 使用 Stack 堆疊影片、鎖定層和控制按鈕
      body: Stack(
        children: [
          // 1. 影片播放器 (被 IgnorePointer 包裹，實現鎖定效果)
          Positioned.fill(
            child: IgnorePointer(
              // 【關鍵】: 只有在鎖定狀態下，才忽略對播放器的觸控
              ignoring: _isLocked,
              child: YoutubePlayer(
                controller: _controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: Colors.redAccent,
                onReady: () {
                  debugPrint('Player is ready.');
                },
              ),
            ),
          ),

          // 2. 鎖定時的浮層 (只在鎖定 AND 顯示狀態為 true 時才顯示)
          if (_isLocked && _showLockOverlay)
            Positioned.fill(
              // 透過 GestureDetector 確保即使在浮層上點擊也不會影響鎖定狀態
              child: GestureDetector(
                // 點擊浮層時，可以再次顯示鎖定提示 (如果需要)
                onTap: () {
                  if (_isLocked && !_showLockOverlay) {
                    _toggleLock(); // 重新觸發一次，但馬上解鎖
                    // 這裡的邏輯是確保點擊螢幕時，如果已經鎖定，則重新顯示提示
                    // 但由於 _toggleLock 已經包含了 Timer 邏輯，
                    // 為了簡單化，我們可以讓點擊浮層時只重置 Timer
                    if (_lockOverlayTimer?.isActive == true) {
                      _lockOverlayTimer?.cancel();
                    }
                    setState(() {
                      _showLockOverlay = true;
                    });
                    _lockOverlayTimer = Timer(const Duration(seconds: 5), () {
                      if (mounted) {
                        setState(() {
                          _showLockOverlay = false;
                        });
                      }
                    });
                  }
                },
                child: Container(
                  // 半透明遮罩
                  //color: Colors.black.withOpacity(0.5),
                  color: const Color.fromRGBO(0, 0, 0, 0.5),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock, color: Colors.white, size: 80),
                        SizedBox(height: 10),
                        Text(
                          '螢幕已鎖定',
                          style: TextStyle(color: Colors.white, fontSize: 24),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 3. 退出按鈕 (左上角) - 鎖定時隱藏
          if (!_isLocked)
            Positioned(
              top: 20,
              left: 20,
              child: SafeArea(
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ),

          // 4. 鎖定/解鎖按鈕 (右上角) - 永遠可點擊，確保它在最上層
          Positioned(
            top: 20,
            right: 20,
            child: SafeArea(
              child: IconButton(
                // 鎖頭圖標根據狀態切換
                icon: Icon(
                  _isLocked ? Icons.lock : Icons.lock_open,
                  color: Colors.white,
                  size: 40,
                ),
                onPressed: _toggleLock, // 單擊即可切換鎖定/解鎖
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // 離開頁面前，取消計時器
    _lockOverlayTimer?.cancel();

    // 恢復系統狀態列
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    // 離開播放器時，重新鎖定為橫向 (回到主頁的設定)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _controller.dispose();
    super.dispose();
  }
}
