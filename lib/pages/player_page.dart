// lib/pages/player_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/channel.dart'; // 引入 NewsChannel model
import '../providers/channel_provider.dart'; // 引入 Riverpod Providers

// ------------------- PlayerPage 程式碼開始 -------------------

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

// ------------------- PlayerPage 程式碼結束 -------------------
