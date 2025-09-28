// lib/widgets/channel_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart';
import '../pages/player_page.dart';
import '../providers/channel_provider.dart';

// 靜態常數：設定 TV 焦點邊框樣式
const double _focusBorderWidth = 5.0;
const Color _focusBorderColor = Colors.white;

// -------------------------------------------------------------
// ChannelCard 新增 focusNode 和 onTap 參數
// -------------------------------------------------------------
class ChannelCard extends ConsumerWidget {
  final NewsChannel channel;
  final FocusNode? focusNode;
  final VoidCallback? onTap; // 🎯 修正 1A：新增 onTap 參數

  // 構造函數新增 focusNode 和 onTap 參數
  const ChannelCard({
    super.key,
    required this.channel,
    this.focusNode,
    this.onTap, // 🎯 修正 1B：在建構子中接收它
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isShowingAll = ref.watch(showAllChannelsProvider);
    final isHiddenAndShowingAll = isShowingAll && channel.isHidden;

    return _FocusChannelCard(
      channel: channel,
      isHiddenAndShowingAll: isHiddenAndShowingAll,
      focusNode: focusNode,
      onTap: onTap, // 🎯 修正 1C：傳遞 onTap 給內部的 Widget
    );
  }
}

// -------------------------------------------------------------
// _FocusChannelCard 處理焦點狀態和鍵盤事件
// -------------------------------------------------------------
class _FocusChannelCard extends StatefulWidget {
  final NewsChannel channel;
  final bool isHiddenAndShowingAll;
  final FocusNode? focusNode;
  final VoidCallback? onTap; // 🎯 修正 2：新增 onTap 參數

  const _FocusChannelCard({
    required this.channel,
    required this.isHiddenAndShowingAll,
    this.focusNode,
    this.onTap, // 🎯 修正 2：在建構子中接收它
  });

  @override
  State<_FocusChannelCard> createState() => _FocusChannelCardState();
}

class _FocusChannelCardState extends State<_FocusChannelCard> {
  bool _isFocused = false;
  late FocusNode _effectiveFocusNode;

  // ❌ 修正 3A：移除冗餘的 _navigateToPlayer 方法 (導航邏輯已在 channel_list_page 處理)
  // void _navigateToPlayer() { ... }

  // 🎯 修正 3B：修改 _handleKeyEvent，改為調用 widget.onTap
  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        if (_effectiveFocusNode.hasFocus) {
          // 💡 當 TV 遙控器按下 OK 鍵時，調用外部傳入的 onTap
          widget.onTap?.call();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  // 焦點變更處理函式 (保持不變)
  void _handleFocusChange() {
    if (_effectiveFocusNode.hasFocus != _isFocused) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl =
        'https://img.youtube.com/vi/${widget.channel.videoId}/hqdefault.jpg';

    // 🎯 修正 3C：使用 GestureDetector 包裹 Focus，處理行動裝置的點擊事件
    return GestureDetector(
      onTap: widget.onTap, // 💡 當手機點擊時，調用外部傳入的 onTap
      child: Focus(
        focusNode: _effectiveFocusNode,
        onKey: _handleKeyEvent,
        autofocus: false,

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 頂部的縮圖區域
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(25.0),
                  border: Border.all(
                    color: _focusBorderColor,
                    width: _isFocused ? _focusBorderWidth : 0.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isFocused
                          ? _focusBorderColor.withOpacity(0.8)
                          : Colors.black.withOpacity(0.5),
                      spreadRadius: _isFocused ? 5 : 1,
                      blurRadius: _isFocused ? 15 : 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    25.0 - (_isFocused ? _focusBorderWidth : 0.0),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.error_outline,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ),
                      // 隱藏頻道圖示
                      if (widget.isHiddenAndShowingAll)
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
            // 2. 頻道名稱
            Padding(
              padding: const EdgeInsets.only(
                top: 4.0,
                left: 4.0,
                right: 4.0,
                bottom: 0.0,
              ),
              child: Text(
                widget.channel.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: widget.isHiddenAndShowingAll
                      ? Colors.grey
                      : Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
