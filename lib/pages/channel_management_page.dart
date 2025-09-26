// lib/pages/channel_management_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:news_stream_app/models/channel.dart';
import 'package:news_stream_app/providers/channel_provider.dart';
// import 'package:news_stream_app/services/backup_service.dart'; // <--- 備份服務不再這裡使用，可移除

class ChannelManagementPage extends ConsumerWidget {
  const ChannelManagementPage({super.key});

  // 輔助函數：顯示 SnackBar 訊息 (保留，用於刪除和隱藏操作的反饋)
  void _showSnackbar(
    BuildContext context,
    String message, {
    Color color = Colors.green,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ------------------------- 匯出/匯入邏輯已移除 -------------------------

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 監聽所有頻道列表，包括隱藏的
    final channels = ref.watch(channelListProvider);
    final notifier = ref.read(channelListProvider.notifier);

    // 定義顏色常量
    // 頻道可見時的文字顏色
    const Color visibleColor = Colors.white;
    // 頻道隱藏時的灰白色
    const Color hiddenColor = Colors.white54;

    // 設定 AppBar 顏色
    const Color appBarColor = Colors.black; // 統一使用黑色作為深色主題的 AppBar

    // 如果列表是空的，可以顯示一個提示
    if (channels.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('頻道管理與排序'),
          backgroundColor: appBarColor,
          foregroundColor: Colors.white,
        ),
        backgroundColor: Colors.black, // 設定深色背景
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
      ),
      backgroundColor: Colors.black, // 設定深色背景
      // 【主要修正】: 使用 Column 包裹提示文字和 ReorderableListView
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 【新增】: 提示文字區塊 (放大且醒目)
          Padding(
            padding: const EdgeInsets.only(
              top: 16.0,
              bottom: 8.0,
              left: 16.0,
              right: 16.0,
            ),
            child: Text(
              '💡 提示：\n    向左滑動任一頻道即可刪除。\n    長按左側圖示可拖曳排序。',
              style: TextStyle(
                color: Colors.yellowAccent, // 使用醒目的黃色
                fontSize: 14, // 放大字體
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 【原來的 ReorderableListView.builder】
          Expanded(
            child: ReorderableListView.builder(
              itemCount: channels.length,
              onReorder: (oldIndex, newIndex) {
                // 處理 ReorderableListView 特有的 newIndex 修正
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                // 調用 Notifier 中的更新排序方法
                notifier.updateOrder(oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final channel = channels[index];

                // 根據隱藏狀態設定當前文字顏色
                final Color textColor = channel.isHidden
                    ? hiddenColor
                    : visibleColor;

                // 使用 Dismissible 實現滑動刪除功能
                return Dismissible(
                  key: ValueKey(channel.id), // 必須使用一個唯一的 Key
                  direction: DismissDirection.endToStart, // 僅允許右向左滑動
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    // 彈出確認對話框
                    return await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('確認刪除'),
                              content: Text('確定要刪除頻道: ${channel.name} 嗎？'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: const Text('取消'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: const Text(
                                    '確定',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            );
                          },
                        ) ??
                        false;
                  },
                  onDismissed: (direction) {
                    // 執行刪除
                    notifier.deleteChannel(channel);
                    _showSnackbar(context, '已刪除頻道: ${channel.name}');
                  },

                  // 列表項 (ReorderableListView 要求每個 item 必須有 key)
                  child: ListTile(
                    key: ValueKey(channel.id), // ReorderableListView 要求 Key
                    tileColor: Colors.black, // 深色背景
                    // 拖拽圖示
                    leading: Icon(Icons.drag_handle, color: textColor),

                    title: Text(
                      channel.name,
                      style: TextStyle(color: textColor, fontSize: 18), // 放大標題
                    ),
                    subtitle: Text(
                      'ID: ${channel.videoId}',
                      // 副標題顏色稍微更暗一點，增加層次感
                      style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 14,
                      ), // 放大副標題
                    ),

                    // 隱藏/顯示切換按鈕
                    trailing: IconButton(
                      icon: Icon(
                        // 根據 isHidden 狀態顯示不同圖示
                        channel.isHidden
                            ? Icons.visibility_off
                            : Icons.visibility,
                        // 保持隱藏圖示為灰色，顯示圖示為綠色
                        color: channel.isHidden ? Colors.grey : Colors.green,
                      ),
                      onPressed: () {
                        // 切換狀態並通知資料庫和 Riverpod
                        notifier.toggleHidden(channel);
                        _showSnackbar(
                          context,
                          channel.isHidden
                              ? '已顯示 ${channel.name}'
                              : '已隱藏 ${channel.name}',
                        );
                      },
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
