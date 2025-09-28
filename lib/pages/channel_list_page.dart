// lib/pages/channel_list_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart';
import '../providers/channel_provider.dart';
import 'settings_page.dart';
import 'player_page.dart';
import '../widgets/channel_card.dart';

// -------------------------------------------------------------
// 輔助 Widget：用於添加發光/邊框焦點效果的自定義按鈕
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
  // FocusNode 保持不變，用於初始焦點和焦點循環
  final FocusNode _firstIconFocusNode = FocusNode();
  final FocusNode _firstCardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockToLandscape();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 🎯 修正處：將初始焦點設定為第一個頻道卡片
        _firstCardFocusNode.requestFocus();
      }
    });
  }

  // 保持生命週期和方向鎖定邏輯
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

  // 抽取功能按鈕列
  Widget _buildActionRow(BuildContext context, bool isShowingAll) {
    return Container(
      color: Colors.black, // 保持 Appbar 的背景色
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FocusTraversalGroup(
            // 1. 眼睛按鈕 (切換顯示) - 使用 _firstIconFocusNode
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

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(visibleChannelListProvider);
    final isShowingAll = ref.watch(showAllChannelsProvider);

    // 檢查初始載入中
    final allChannels = ref.watch(channelListProvider);

    // 狀態 1: 初始載入中 (allChannels 列表還沒有資料)
    if (allChannels.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('新聞直播頻道列表'),
          backgroundColor: Colors.black,
          actions: const [], // 載入中不需要功能按鈕
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
          actions: const [], // 這裡不放按鈕，讓焦點集中在 body
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
                // 在空狀態下，提供明確的動作按鈕
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

    // 狀態 3: 正常列表內容
    return Scaffold(
      appBar: AppBar(
        title: const Text('阿爸的電視'),
        backgroundColor: Colors.black,
        actions: const [], // 確保 AppBar actions 永遠是空的
      ),
      body: Column(
        children: [
          _buildActionRow(context, isShowingAll),

          // 將 GridView 放置在 Row 下方，並佔用剩餘空間
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

                // 傳遞 focusNode 給第一個 ChannelCard，完成焦點迴圈
                // 這是確保焦點能正確從卡片跳回功能列的關鍵
                final focusNode = index == 0 ? _firstCardFocusNode : null;

                return ChannelCard(
                  key: ValueKey(channel.id),
                  channel: channel,
                  focusNode: focusNode,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
