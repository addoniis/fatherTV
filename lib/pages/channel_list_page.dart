// lib/pages/channel_list_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart'; // 這裡可能定義了 NewsChannel 或 Channel
import '../providers/channel_provider.dart';
import 'settings_page.dart';
import 'player_page.dart';
import '../widgets/channel_card.dart';

// -------------------------------------------------------------
// 輔助 Widget：用於添加發光/邊框焦點效果的自定義按鈕 (TV 專用)
// -------------------------------------------------------------
class _FocusIconAction extends StatefulWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final FocusNode? focusNode;
  final Color focusColor;

  const _FocusIconAction({
    super.key,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.focusNode,
    this.focusColor = Colors.redAccent,
  });

  @override
  _FocusIconActionState createState() => _FocusIconActionState();
}

class _FocusIconActionState extends State<_FocusIconAction> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    const double focusBorderWidth = 3.0;
    final Color effectiveColor = _isFocused ? widget.focusColor : widget.color;

    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
      },
      onKey: (FocusNode node, RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            widget.onPressed();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        padding: const EdgeInsets.all(5.0),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(
            color: _isFocused ? widget.focusColor : Colors.transparent,
            width: _isFocused ? focusBorderWidth : 0.0,
          ),
          boxShadow: [
            if (_isFocused)
              BoxShadow(
                color: widget.focusColor.withOpacity(0.5),
                spreadRadius: 2,
                blurRadius: 10,
              ),
          ],
        ),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Icon(widget.icon, size: 36.0, color: effectiveColor),
        ),
      ),
    );
  }
}

// ------------------- ChannelListPage 程式碼開始 -------------------

class ChannelListPage extends ConsumerStatefulWidget {
  const ChannelListPage({super.key});

  @override
  ConsumerState<ChannelListPage> createState() => _ChannelListPageState();
}

class _ChannelListPageState extends ConsumerState<ChannelListPage>
    with WidgetsBindingObserver {
  bool _isInitialStart = true;
  final FocusNode _firstIconFocusNode = FocusNode();
  final FocusNode _firstCardFocusNode = FocusNode();

  // 💡 核心：將 getter 改為方法，接收 context 參數
  bool _isTvMode(BuildContext context) {
    const double tvWidthThreshold = 1200.0;
    final double screenWidth = MediaQuery.of(context).size.width;
    return screenWidth > tvWidthThreshold;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockToLandscape();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        if (_isTvMode(context)) {
          _firstCardFocusNode.requestFocus();
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialStart) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _lockToLandscape();
        }
      });
    }
    _isInitialStart = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _lockToLandscape();
    }
  }

  void _lockToLandscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firstIconFocusNode.dispose();
    _firstCardFocusNode.dispose();
    super.dispose();
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsPage()),
    );
  }

  void _toggleChannelVisibility(BuildContext context) {
    final currentStatus = ref.read(showAllChannelsProvider);
    ref.read(showAllChannelsProvider.notifier).state = !currentStatus;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(!currentStatus ? '已顯示所有頻道 (包含隱藏)' : '已隱藏設定中隱藏的頻道'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // 🎯 修正錯誤：將 Channel 改為 NewsChannel
  void _navigateToPlayer(BuildContext context, NewsChannel channel) {
    // 允許所有方向
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlayerPage(channel: channel)),
    ).then((_) {
      // 返回頻道列表時，重新鎖定為橫向
      _lockToLandscape();
    });
  }

  // 💡 TV 模式專用的功能按鈕列 (在 body 頂部)
  Widget _buildActionRow(BuildContext context, bool isShowingAll) {
    if (!_isTvMode(context)) {
      return const SizedBox.shrink(); // 手機模式下不顯示
    }

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FocusTraversalGroup(
            // 1. 眼睛按鈕 (切換顯示)
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: _FocusIconAction(
                focusNode: _firstIconFocusNode,
                icon: isShowingAll ? Icons.visibility : Icons.visibility_off,
                color: Colors.white,
                focusColor: isShowingAll ? Colors.redAccent : Colors.white,
                onPressed: () => _toggleChannelVisibility(context),
              ),
            ),
          ),

          // 2. 設定按鈕
          _FocusIconAction(
            icon: Icons.settings,
            color: Colors.white,
            onPressed: () => _navigateToSettings(context),
          ),

          // 3. 退出按鈕
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 20.0),
            child: _FocusIconAction(
              icon: Icons.exit_to_app,
              color: Colors.white,
              focusColor: Colors.red,
              onPressed: () => SystemNavigator.pop(),
            ),
          ),
        ],
      ),
    );
  }

  // 💡 手機模式專用的 AppBar Actions
  // lib/pages/channel_list_page.dart (約第 267 行)

  // 💡 手機模式專用的 AppBar Actions
  List<Widget> _buildAppBarActions(BuildContext context, bool isShowingAll) {
    if (_isTvMode(context)) {
      return const [];
    }

    // 🎯 調整 Icon 的 size 和 IconButton 的間距
    return [
      // 1. 眼睛按鈕 (切換顯示)
      IconButton(
        // 調整 size 可以改變圖標大小
        icon: Icon(
          isShowingAll ? Icons.visibility : Icons.visibility_off,
          color: isShowingAll ? Colors.redAccent : Colors.white,
          size: 40.0, // 👈 調整這裡：例如從 28.0 增加到 30.0
        ),
        // 調整 padding 屬性 (如果需要)
        padding: const EdgeInsets.symmetric(
          horizontal: 14.0,
        ), // 👈 調整間距：例如改為 4.0
        onPressed: () => _toggleChannelVisibility(context),
      ),
      // 2. 設定按鈕
      IconButton(
        icon: const Icon(
          Icons.settings,
          color: Colors.white,
          size: 40.0,
        ), // 👈 調整這裡
        padding: const EdgeInsets.symmetric(horizontal: 14.0), // 👈 調整間距
        onPressed: () => _navigateToSettings(context),
      ),
      // 3. 退出按鈕
      IconButton(
        icon: const Icon(
          Icons.exit_to_app,
          color: Colors.white,
          size: 40.0,
        ), // 👈 調整這裡
        padding: const EdgeInsets.symmetric(
          horizontal: 50.0,
        ), // 👈 調整這裡可以讓最右邊的間距大一點
        onPressed: () => SystemNavigator.pop(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(visibleChannelListProvider);
    final isShowingAll = ref.watch(showAllChannelsProvider);
    final allChannels = ref.watch(channelListProvider);
    final bool isTvMode = _isTvMode(context);

    // 狀態 1: 初始載入中
    if (allChannels.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('新聞直播頻道列表'),
          backgroundColor: Colors.black,
          actions: const [],
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 狀態 2: 列表已載入，但篩選後為空
    if (channels.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('新聞直播頻道列表'),
          backgroundColor: Colors.black,
          actions: _buildAppBarActions(context, isShowingAll),
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

    // 狀態 3: 正常列表內容 (響應式設計的關鍵)
    return Scaffold(
      appBar: AppBar(
        // 🎯 調整這裡的 TextStyle 來自訂字體大小、顏色、粗細等
        title: const Text(
          '阿爸的電視',
          style: TextStyle(
            fontSize: 36.0, // 👈 關鍵調整：將字體大小改為你想要的值（例如 28.0）
            fontWeight: FontWeight.bold, // 可選：讓字體更粗
            color: Colors.white, // 可選：確保顏色正確
          ),
        ),
        backgroundColor: Colors.black,
        actions: _buildAppBarActions(context, isShowingAll),
      ),
      body: Column(
        children: [
          if (isTvMode) _buildActionRow(context, isShowingAll),

          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 165.0,
                mainAxisSpacing: 15.0,
                crossAxisSpacing: 20.0,
                childAspectRatio: 1.2,
              ),
              padding: const EdgeInsets.all(10.0),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                final focusNode = isTvMode && index == 0
                    ? _firstCardFocusNode
                    : null;

                return ChannelCard(
                  key: ValueKey(channel.id),
                  channel: channel,
                  focusNode: focusNode,
                  onTap: () => _navigateToPlayer(context, channel),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
