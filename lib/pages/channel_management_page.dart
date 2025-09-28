// lib/pages/channel_management_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 保持別名導入：將 models/channel.dart 導入為 models
import '../models/channel.dart' as models;
import '../providers/channel_provider.dart';
import './add_channel_page.dart';

class ChannelManagementPage extends ConsumerWidget {
  const ChannelManagementPage({super.key});

  // 輔助函數：顯示 SnackBar 訊息
  void _showSnackbar(
    BuildContext context,
    String message, {
    Color color = Colors.green,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ----------------------------------------------------
  // 【保留】: 批量操作和刪除的確認對話框 (UI 互動)
  // ----------------------------------------------------
  Future<bool> _showConfirmationDialog(
    BuildContext context,
    String title,
    String content,
    String confirmText,
    Color confirmColor,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    confirmText,
                    style: TextStyle(color: confirmColor),
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // ----------------------------------------------------
  // ❗ 移除 _handleChannelDeletion 邏輯，簡化 build 內部 ❗
  // ----------------------------------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 監聽所有頻道列表，包括隱藏的
    final channels = ref.watch(channelListProvider);
    final notifier = ref.read(channelListProvider.notifier);

    // 定義顏色常量
    const Color visibleColor = Colors.white;
    const Color hiddenColor = Colors.white54;
    const Color appBarColor = Colors.black;

    // ... (空列表檢查邏輯保留不變) ...
    if (channels.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('頻道管理與排序'),
          backgroundColor: appBarColor,
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            '目前沒有任何頻道。請從設定頁面匯入。',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('頻道管理與排序'),
        backgroundColor: appBarColor,
        foregroundColor: Colors.white,

        // ----------------------------------------------------
        // 批量操作按鈕，直接呼叫 notifier 方法
        // ----------------------------------------------------
        actions: [
          // 1. 一鍵隱藏所有頻道
          IconButton(
            icon: const Icon(Icons.visibility_off, color: Colors.white),
            tooltip: '一鍵隱藏所有頻道',
            onPressed: () async {
              final confirmed = await _showConfirmationDialog(
                context,
                '確認全部隱藏？',
                '確定要將所有頻道在主頁隱藏嗎？',
                '確認隱藏',
                Colors.red,
              );

              if (confirmed) {
                // ❗ 呼叫 Provider 方法 ❗
                await notifier.hideAllChannels();
                _showSnackbar(context, '所有頻道已隱藏！');
              }
            },
          ),

          // 2. 一鍵顯示所有頻道
          IconButton(
            icon: const Icon(Icons.visibility, color: Colors.green),
            tooltip: '一鍵顯示所有頻道',
            onPressed: () async {
              // ❗ 呼叫 Provider 方法 ❗
              await notifier.showAllChannels();
              _showSnackbar(context, '所有頻道已顯示！');
            },
          ),
        ],
      ),
      backgroundColor: Colors.black,

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            // 移除了 const 警告
            padding: EdgeInsets.only(
              top: 16.0,
              bottom: 8.0,
              left: 16.0,
              right: 16.0,
            ),
            child: Text(
              '💡 提示：\n    向左滑動任一頻道即可刪除。\n    長按左側圖示可拖曳排序。',
              style: TextStyle(
                color: Colors.yellowAccent,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: ReorderableListView.builder(
              itemCount: channels.length,
              onReorder: (oldIndex, newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                // ❗ 呼叫 Provider 方法 ❗
                notifier.updateOrder(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final channel = channels[index];

                final Color textColor = channel.isHidden
                    ? hiddenColor
                    : visibleColor;

                return Dismissible(
                  key: ValueKey(channel.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),

                  // ❗ 核心簡化：將檢查和刪除邏輯集中在這裡 ❗
                  confirmDismiss: (direction) async {
                    // 1. 執行最少保留一個的檢查
                    if (channels.length <= 1) {
                      _showSnackbar(
                        context,
                        '必須保留至少一個頻道！請前往「設定」使用重置功能。',
                        color: Colors.orange,
                      );
                      return false;
                    }

                    // 2. 彈出確認對話框 (UI 互動)
                    final confirmed = await _showConfirmationDialog(
                      context,
                      '確認刪除',
                      '確定要刪除頻道: ${channel.name} 嗎？此操作不可逆！',
                      '確定',
                      Colors.red,
                    );

                    if (confirmed) {
                      // 3. 呼叫 Provider 方法執行刪除 (Provider 負責狀態修改和持久化)
                      notifier.removeChannel(channel);
                      _showSnackbar(context, '已刪除頻道: ${channel.name}');
                      return true; // 允許 Dismissible 移除 Widget
                    }

                    return false; // 取消刪除
                  },

                  // 列表項
                  child: ListTile(
                    key: ValueKey(channel.id),
                    tileColor: Colors.black,
                    // 拖拽圖示
                    leading: Icon(Icons.drag_handle, color: textColor),

                    title: Text(
                      channel.name,
                      style: TextStyle(color: textColor, fontSize: 18),
                    ),
                    subtitle: Text(
                      'ID: ${channel.videoId}',
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),

                    // 編輯和隱藏/顯示按鈕
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 1. 編輯按鈕
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () {
                            // 導航到 AddChannelPage，並傳入要編輯的頻道
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    AddChannelPage(channelToEdit: channel),
                              ),
                            );
                          },
                        ),
                        // 2. 隱藏/顯示切換按鈕
                        IconButton(
                          icon: Icon(
                            channel.isHidden
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: channel.isHidden
                                ? Colors.grey
                                : Colors.green,
                          ),
                          onPressed: () {
                            // ❗ 呼叫 Provider 方法 ❗
                            notifier.toggleHidden(channel);
                            _showSnackbar(
                              context,
                              channel.isHidden
                                  ? '已顯示 ${channel.name}'
                                  : '已隱藏 ${channel.name}',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
