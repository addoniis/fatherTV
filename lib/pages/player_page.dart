// lib/pages/player_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/channel.dart'; // 引入 NewsChannel model
import '../providers/channel_provider.dart'; // 引入 Riverpod Providers

import '../services/player_service_interface.dart';
import '../services/youtube_player_service.dart'; // 假設您使用這個實作

// ------------------- PlayerPage 程式碼開始 -------------------

// 播放器頁面 (已包含防止手勢切換時方向錯亂的加固邏輯)
class PlayerPage extends ConsumerStatefulWidget {
  final NewsChannel channel;
  const PlayerPage({super.key, required this.channel});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late PlayerServiceInterface _playerService;

  // 💡 新增：用於監聽 D-Pad 事件的 FocusNode
  final FocusNode _keyListenerFocusNode = FocusNode();

  // 追蹤螢幕是否鎖定
  bool _isLocked = false;
  // 追蹤鎖定提示層是否顯示
  bool _showLockOverlay = false;
  // 用於計時器
  Timer? _lockOverlayTimer;
  // 追蹤垂直拖曳的總距離
  double _dragDistance = 0.0;

  // 【新增】: 監聽播放器狀態流的 Subscription
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();

    _initializePlayerService(widget.channel.videoId);

    // 播放器頁面強制鎖定為橫向
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // 隱藏系統狀態列和導航列 (讓畫面最大化)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);

    // 請求焦點，以便 RawKeyboardListener 能夠捕獲按鍵
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _keyListenerFocusNode.requestFocus();
      }
    });
  }

  // 輔助方法：初始化或重新初始化播放器服務
  void _initializePlayerService(String videoId) {
    _playerService = YouTubePlayerService(videoId);

    _playerStateSubscription?.cancel(); // 取消舊的監聽
    _playerStateSubscription = _playerService.onPlayerStateChange.listen((
      state,
    ) {
      if (state == PlayerState.ready) {
        // 當播放器準備好時 (例如切換頻道後)，強制重新執行橫屏鎖定。
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    });
  }

  // ===========================================
  // 💡 修正 2: 處理 D-Pad 上下鍵切換頻道的邏輯
  // (簽名修正為 RawKeyboardListener 所需的 'void Function(RawKeyEvent)')
  // ===========================================
  void _handleChannelSwitchByKey(RawKeyEvent event) {
    // 只需要處理 RawKeyDownEvent
    if (event is RawKeyDownEvent) {
      // 確保只處理上鍵和下鍵
      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        final notifier = ref.read(channelListProvider.notifier);
        NewsChannel? newChannel;
        int offset;

        // 向上鍵 (arrowUp) = 上一個頻道
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          offset = -1;
        }
        // 向下鍵 (arrowDown) = 下一個頻道
        else {
          offset = 1;
        }

        newChannel = notifier.selectRelativeChannel(widget.channel, offset);

        if (newChannel != null && newChannel.id != widget.channel.id) {
          // 使用 pushReplacement 替換當前的 PlayerPage，實現無縫切換
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PlayerPage(channel: newChannel!),
            ),
          );
          // 此處無需返回 'handled'
        }
      }
    }
  }

  // 鎖定/解鎖操作 (保持不變)
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
    const double distanceThreshold = 100.0;

    if (_dragDistance.abs() > distanceThreshold) {
      final notifier = ref.read(channelListProvider.notifier);
      NewsChannel? newChannel;
      int offset;

      if (_dragDistance < 0) {
        offset = 1; // 向上划動 (拖曳距離為負) -> 下一個頻道
      } else {
        offset = -1; // 向下划動 (拖曳距離為正) -> 上一個頻道
      }

      newChannel = notifier.selectRelativeChannel(widget.channel, offset);

      if (newChannel != null && newChannel.id != widget.channel.id) {
        // 使用 pushReplacement 替換當前的 PlayerPage，以實現無縫切換
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PlayerPage(channel: newChannel!),
          ),
        );
      }
    }

    _dragDistance = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    // 💡 修正 3: 將 RawKeyboardListener 放在最外層
    return RawKeyboardListener(
      focusNode: _keyListenerFocusNode,
      onKey: _handleChannelSwitchByKey,
      child: Scaffold(
        backgroundColor: Colors.black,

        // 【核心修改】：使用 GestureDetector 包裹整個頁面內容
        body: GestureDetector(
          onVerticalDragStart: _handleDragStart,
          onVerticalDragUpdate: _handleDragUpdate,
          onVerticalDragEnd: _handleChannelSwipe,
          child: Stack(
            children: [
              // 1. 影片播放器 (被 IgnorePointer 包裹，實現鎖定效果)
              Positioned.fill(
                child: IgnorePointer(
                  // 只有在鎖定狀態下，才忽略對播放器的觸控
                  ignoring: _isLocked,
                  child: _playerService.buildPlayerWidget(
                    widget.channel.videoId,
                  ),
                ),
              ),

              // 2. 鎖定時的浮層 (保持不變)
              if (_isLocked && _showLockOverlay)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      if (_isLocked) {
                        _lockOverlayTimer?.cancel();
                        setState(() {
                          _showLockOverlay = true;
                        });
                        _lockOverlayTimer = Timer(
                          const Duration(seconds: 5),
                          () {
                            if (mounted) {
                              setState(() {
                                _showLockOverlay = false;
                              });
                            }
                          },
                        );
                      }
                    },
                    child: Container(
                      color: const Color.fromRGBO(0, 0, 0, 0.5),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, color: Colors.white, size: 80),
                            SizedBox(height: 10),
                            Text(
                              '螢幕已鎖定',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. 退出按鈕 (左上角) - 鎖定時隱藏 (保持不變)
              if (!_isLocked)
                Positioned(
                  top: 20,
                  left: 5,
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

              // 4. 鎖定/解鎖按鈕 (右上角) - 永遠可點擊 (保持不變)
              Positioned(
                top: 20,
                right: 20,
                child: SafeArea(
                  child: IconButton(
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
      ),
    );
  }

  @override
  void dispose() {
    _lockOverlayTimer?.cancel();

    _playerService.dispose();

    _playerStateSubscription?.cancel();

    // 恢復系統狀態列
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );

    // 關鍵修正：在退出播放器頁面時，強制維持橫向鎖定 (防止返回主頁時轉直屏)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft, // 允許橫向
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp, // 允許直向
      DeviceOrientation.portraitDown,
    ]);

    _keyListenerFocusNode.dispose(); // 釋放 FocusNode

    super.dispose();
  }
}
