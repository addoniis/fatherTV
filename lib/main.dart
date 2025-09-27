// lib/main.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

// 引入我們為數據持久化建立的組件
import 'models/channel.dart'; // 引入 NewsChannel
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
      // 使用 ChannelListPage，現在它是一個 ConsumerStatefulWidget
      home: const ChannelListPage(),
    );
  }
}

// 修正：ChannelListPage 升級為 ConsumerStatefulWidget
class ChannelListPage extends ConsumerStatefulWidget {
  const ChannelListPage({super.key});

  @override
  ConsumerState<ChannelListPage> createState() => _ChannelListPageState();
}

// 新增：State類，並混合 WidgetsBindingObserver
class _ChannelListPageState extends ConsumerState<ChannelListPage>
    with WidgetsBindingObserver {
  // 追蹤 App 是否是第一次啟動 (用來避免在 initState 和 didChangeDependencies 重複鎖定)
  bool _isInitialStart = true;

  @override
  void initState() {
    super.initState();
    // 啟動生命週期監聽
    WidgetsBinding.instance.addObserver(this);
    // 首次啟動時鎖定
    _lockToLandscape();
  }

  // ❗ 關鍵修正：從 PlayerPage 返回時會觸發此方法 ❗
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_isInitialStart) {
      // 🚨 終極延遲鎖定：給系統 50 毫秒時間完成 PlayerPage 的銷毀 🚨
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

  // 導航到設定頁面的函式，避免重複程式碼
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

    // 監聽切換按鈕的狀態
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
          // ❗ 1. 新增：顯示/隱藏所有頻道按鈕 (眼睛圖示) ❗
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

          // 2. 設定按鈕 - 放大點擊範圍和圖標
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              icon: const Icon(Icons.settings, size: 36.0),
              onPressed: () => _navigateToSettings(context),
            ),
          ),
          // 3. 橫向時常有的返回 App 退出按鈕 - 放大點擊範圍和圖標
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0),
            child: IconButton(
              icon: const Icon(Icons.exit_to_app, size: 36.0),
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

          // 檢查是否為被隱藏的頻道，且當前為「顯示全部」模式
          final isHiddenAndShowingAll = isShowingAll && channel.isHidden;

          return InkWell(
            onTap: () {
              // 點擊後導航到播放器頁面
              // 備註：點擊隱藏的頻道也會播放，因為它已經在 `channels` 列表中。
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
                      borderRadius: BorderRadius.circular(25.0),
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
                      borderRadius: BorderRadius.circular(25.0),
                      child: Stack(
                        // 【修正 1】: 將 BoxFit.expand 修正為 StackFit.expand
                        fit: StackFit.expand,
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

                          // ❗ 新增：如果頻道是被隱藏的，顯示一個半透明圖層 ❗
                          if (isHiddenAndShowingAll)
                            Container(
                              color: Colors.black.withOpacity(0.6),
                              child: const Center(
                                child: Icon(
                                  Icons.visibility_off,
                                  color: Colors.white70,
                                  size: 40,
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
                    style: TextStyle(
                      // ❗ 根據狀態改變文字顏色 ❗
                      color: isHiddenAndShowingAll ? Colors.grey : Colors.white,
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

// 播放器頁面 (已包含防止手勢切換時方向錯亂的加固邏輯)
class PlayerPage extends ConsumerStatefulWidget {
  final NewsChannel channel;
  const PlayerPage({super.key, required this.channel});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late YoutubePlayerController _controller;
  // 追蹤螢幕是否鎖定
  bool _isLocked = false;
  // 【新增】: 追蹤鎖定提示層是否顯示
  bool _showLockOverlay = false;
  // 【新增】: 用於計時器
  Timer? _lockOverlayTimer;
  // 追蹤垂直拖曳的總距離
  double _dragDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _initializePlayerController(widget.channel.videoId);

    // 播放器頁面強制鎖定為橫向
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 隱藏系統狀態列和導航列 (讓畫面最大化)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }

  // 輔助方法：初始化或重新初始化播放器控制器
  void _initializePlayerController(String videoId) {
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        isLive: true,
        forceHD: true,
      ),
    )..addListener(_listener); // ❗ 關鍵：添加播放器狀態監聽 ❗
  }

  // ❗ 新增播放器狀態監聽器，加固橫屏鎖定 ❗
  void _listener() {
    // 當播放器準備好時 (例如切換頻道後)，強制重新執行橫屏鎖定。
    if (_controller.value.isReady) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
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
      _lockOverlayTimer?.cancel();
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isLocked ? '螢幕已鎖定' : '螢幕已解鎖'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // 處理拖曳開始
  void _handleDragStart(DragStartDetails details) {
    _dragDistance = 0.0; // 拖曳開始時重置距離
  }

  // 處理拖曳更新（累積距離）
  void _handleDragUpdate(DragUpdateDetails details) {
    // 累積垂直移動的距離 (details.delta.dy)
    _dragDistance += details.delta.dy;
  }

  // 處理手勢切換頻道 (現在使用累積距離判斷)
  void _handleChannelSwipe(DragEndDetails details) {
    // 設置一個距離閾值，例如：垂直移動超過 100 像素
    const double distanceThreshold = 100.0;

    if (_dragDistance.abs() > distanceThreshold) {
      final notifier = ref.read(channelListProvider.notifier);
      NewsChannel? newChannel;
      int offset;

      // 如果 _dragDistance 是負值 (向上滑動，Y軸減少)
      if (_dragDistance < 0) {
        offset = 1; // 下一個頻道
      }
      // 如果 _dragDistance 是正值 (向下滑動，Y軸增加)
      else {
        offset = -1; // 上一個頻道
      }

      newChannel = notifier.selectRelativeChannel(widget.channel, offset);

      // 檢查 newChannel 不為 null 且 ID 不同才進行導航
      if (newChannel != null && newChannel.id != widget.channel.id) {
        // 使用 pushReplacement 替換當前的 PlayerPage，以實現無縫切換
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            // 使用 newChannel! 斷言其不為 null
            builder: (context) => PlayerPage(channel: newChannel!),
          ),
        );
      }
    }

    // 拖曳結束後重置距離，準備下一次拖曳
    _dragDistance = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      // 【核心修改】：使用 GestureDetector 包裹整個頁面內容
      body: GestureDetector(
        onVerticalDragStart: _handleDragStart, // 綁定拖曳開始
        onVerticalDragUpdate: _handleDragUpdate, // 綁定拖曳更新
        onVerticalDragEnd: _handleChannelSwipe, // 綁定拖曳結束
        // 使用 Stack 堆疊影片、鎖定層和控制按鈕
        child: Stack(
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
                  onReady: () {},
                ),
              ),
            ),

            // 2. 鎖定時的浮層 (只在鎖定 AND 顯示狀態為 true 時才顯示)
            if (_isLocked && _showLockOverlay)
              Positioned.fill(
                child: GestureDetector(
                  // 點擊浮層時，重新啟動計時器 (讓鎖定提示再顯示 5 秒)
                  onTap: () {
                    if (_isLocked) {
                      _lockOverlayTimer?.cancel();
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
                    color: const Color.fromRGBO(0, 0, 0, 0.5),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 【修正】: Icon, SizedBox, Text 必須是 const
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
                left: 5,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(
                      // 【修正】: 必須是 const
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
      ),
    );
  }

  @override
  void dispose() {
    _lockOverlayTimer?.cancel();

    // 恢復系統狀態列
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    // 移除監聽器
    _controller.removeListener(_listener);

    // 關鍵修正：在退出播放器頁面時，強制維持橫向鎖定 (防止返回主頁時轉直屏)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft, // 允許橫向
      DeviceOrientation.landscapeRight,
    ]);

    _controller.dispose();
    super.dispose();
  }
}
