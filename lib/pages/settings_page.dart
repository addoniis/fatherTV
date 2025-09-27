import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ...
import 'package:news_stream_app/pages/faq_page.dart'; // 記得新增這行
// ...
// 【確保導入 AddChannelPage】
import 'package:news_stream_app/pages/add_channel_page.dart';
// 【修正 1】: 導入 AboutPage (確保您已在 /lib/pages/about_page.dart 建立此檔案)
import 'package:news_stream_app/pages/about_page.dart';

import '../providers/channel_provider.dart';
// 【修正 2】: 導入 backupServiceProvider 所在的檔案
import '../services/backup_service.dart';
import 'channel_management_page.dart';

// 將 StatelessWidget 替換為 ConsumerStatefulWidget
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // 【進入頁面時，強制鎖定為直立 (Portrait)】
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // 【修正】: 離開頁面時，恢復為 App 的預設橫向
  @override
  void dispose() {
    // 離開設定頁面時，鎖定為橫向 (與 main.dart 設定的主頁方向一致)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  // 顯示操作結果的訊息提示 (保持不變)
  void _showSnackbar(
    BuildContext context,
    String message, {
    bool success = true,
  }) {
    // 【安全檢查】：確保 context 仍然掛載 (雖然在同步方法中不常見，但保持習慣)
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 16)),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ------------------------------------------------------------------
  // 【匯入頻道 (覆蓋) 確認對話框】 (保持不變)
  // ------------------------------------------------------------------
  Future<void> _showImportConfirmationDialog(
    BuildContext context,
    BackupService backupService,
    ChannelNotifier notifier,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('⚠️ 確認覆蓋匯入？'),
              content: const SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                      '匯入新頻道將會覆蓋您現有的所有頻道清單。',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      '確定要繼續嗎？',
                      style: TextStyle(color: Colors.red, fontSize: 18),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('取消', style: TextStyle(fontSize: 20)),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false); // 回傳 false
                  },
                ),
                TextButton(
                  child: const Text(
                    '確認覆蓋',
                    style: TextStyle(color: Colors.red, fontSize: 20),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true); // 回傳 true
                  },
                ),
              ],
            );
          },
        ) ??
        false;

    // 【安全檢查 1】: 如果 Widget 已被銷毀或用戶取消，則退出
    if (!mounted || !confirmed) return;

    // 執行匯入操作
    final importedChannels = await backupService.importChannels();

    // 【安全檢查 2】: 再次檢查 Widget 是否仍然掛載
    if (!mounted) return;

    if (importedChannels != null && importedChannels.isNotEmpty) {
      await notifier.setChannels(importedChannels);
      _showSnackbar(context, '頻道列表已成功匯入！');
    } else if (importedChannels != null && importedChannels.isEmpty) {
      _showSnackbar(context, '匯入檔案中沒有有效的頻道資料。', success: false);
    } else {
      _showSnackbar(context, '匯入頻道失敗或操作已取消。', success: false);
    }
  }

  // ------------------------------------------------------------------
  // 【重置頻道 確認對話框】 (保持不變)
  // ------------------------------------------------------------------
  Future<void> _showResetConfirmationDialog(
    BuildContext context,
    ChannelNotifier notifier,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('確認重置？'),
              content: const SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                      '確定要清除所有自訂頻道，並恢復為初始預設列表嗎？',
                      style: TextStyle(fontSize: 18),
                    ),
                    Text(
                      '此操作無法復原。',
                      style: TextStyle(color: Colors.red, fontSize: 18),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('取消', style: TextStyle(fontSize: 20)),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                ),
                TextButton(
                  child: const Text(
                    '重置',
                    style: TextStyle(color: Colors.red, fontSize: 20),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                ),
              ],
            );
          },
        ) ??
        false;

    // 【安全檢查 1】: 如果 Widget 已被銷毀或用戶取消，則退出
    if (!mounted || !confirmed) return;

    await notifier.resetChannels();

    // 【安全檢查 2】: 再次檢查 Widget 是否仍然掛載
    if (!mounted) return;

    _showSnackbar(context, '頻道列表已成功恢復為預設狀態！');
  }

  // ------------------------------------------------------------------
  // 【批量隱藏頻道 確認對話框】 (此方法已不再使用，但為了保持程式碼整潔，我們將它刪除)
  // ------------------------------------------------------------------
  /*
  Future<void> _showHideAllConfirmationDialog(...) async {
    // ... 移除
  }
  */

  // 將 build 方法移入 State 類別
  @override
  Widget build(BuildContext context) {
    // 取得 Service (使用 ref.read/watch 保持不變)
    final backupService = ref.read(backupServiceProvider);
    final channelNotifier = ref.read(channelListProvider.notifier);
    final allChannels = ref.watch(channelListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '設定',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: <Widget>[
          // ----------------------------------------------------
          // 頻道新增與管理
          // ----------------------------------------------------
          // 1. 獨立的「新增頻道」入口
          _buildSettingsTile(
            context,
            icon: Icons.add_circle_outline, // 使用 + 號圖標
            title: '新增頻道',
            subtitle: '透過 YouTube 網址或 ID 建立新頻道',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddChannelPage()),
              );
            },
          ),

          // 2. 頻道管理與排序 (現在包含批量顯示/隱藏功能)
          _buildSettingsTile(
            context,
            icon: Icons.list,
            title: '頻道管理',
            subtitle: '刪減、排序及切換頻道隱藏/顯示狀態 (包含批量操作)',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChannelManagementPage(),
                ),
              );
            },
          ),

          const Divider(), // 頻道管理與備份/還原之間的分隔線
          // ----------------------------------------------------
          // 資料備份與還原
          // ----------------------------------------------------

          // 3. 匯入頻道 (覆蓋) (保持不變)
          _buildSettingsTile(
            context,
            icon: Icons.upload_file,
            title: '匯入頻道 (覆蓋)',
            subtitle: '從 JSON 檔案導入頻道列表並覆蓋當前列表',
            onTap: () => _showImportConfirmationDialog(
              context,
              backupService,
              channelNotifier,
            ),
          ),

          // 4. 匯入新增頻道 (合併) (保持不變)
          _buildSettingsTile(
            context,
            icon: Icons.playlist_add, // 使用新增播放清單的圖標
            title: '匯入新增頻道 (合併)',
            subtitle: '從 JSON 檔案導入新頻道，並保留現有頻道',
            onTap: () async {
              final importedChannels = await backupService.importChannels();

              // 【安全檢查】: 在非同步操作（檔案讀取）之後，檢查 Widget 是否仍然掛載
              if (!mounted) return;

              if (importedChannels != null && importedChannels.isNotEmpty) {
                // 呼叫 ChannelNotifier 的合併方法
                final addedCount = await channelNotifier.mergeChannels(
                  importedChannels,
                );

                // 【安全檢查】: 在非同步操作（Notifier 寫入）之後，再次檢查 Widget 是否仍然掛載
                if (!mounted) return;

                if (addedCount > 0) {
                  _showSnackbar(context, '成功新增 $addedCount 個頻道！');
                } else {
                  _showSnackbar(context, '檔案中沒有新頻道可新增。', success: false);
                }
              } else if (importedChannels != null && importedChannels.isEmpty) {
                _showSnackbar(context, '匯入檔案中沒有有效的頻道資料。', success: false);
              } else {
                _showSnackbar(context, '匯入頻道失敗或操作已取消。', success: false);
              }
            },
          ),

          // 5. 匯出頻道 (保持不變)
          _buildSettingsTile(
            context,
            icon: Icons.download_for_offline,
            title: '匯出頻道',
            subtitle: '備份當前頻道列表至 JSON 檔案',
            onTap: () async {
              if (allChannels.isEmpty) {
                _showSnackbar(context, '當前頻道列表為空，無法匯出。', success: false);
                return;
              }
              final filePath = await backupService.exportChannels(allChannels);

              // 【安全檢查】: 在非同步操作（檔案寫入）之後，檢查 Widget 是否仍然掛載
              if (!mounted) return;

              if (filePath != null) {
                _showSnackbar(context, '頻道列表已成功備份！檔案路徑：$filePath');
              } else {
                _showSnackbar(context, '匯出頻道失敗或操作已取消。', success: false);
              }
            },
          ),

          const Divider(),

          // 6. 重置頻道 (保持不變)
          _buildSettingsTile(
            context,
            icon: Icons.restore,
            title: '重置頻道列表',
            subtitle: '將所有頻道恢復到應用程式預設清單',
            onTap: () => _showResetConfirmationDialog(context, channelNotifier),
          ),

          const Divider(),

          // 7. 關於 【已啟用導航】
          _buildSettingsTile(
            context,
            icon: Icons.info_outline,
            title: '關於',
            onTap: () {
              // 導航到 AboutPage
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
          // 8.❗ 新增：常見問題 (FAQ) ❗
          _buildSettingsTile(
            context,
            icon: Icons.help_outline,
            title: '常見問題 (FAQ)',
            onTap: () {
              // 導航到 FAQPage
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FAQPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  // 輔助方法：創建一個放大字體的設定項目 (保持不變)
  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white, size: 30), // 放大圖標
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20, // 放大標題字體
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ), // 放大副標題字體
            )
          : null,
      // 箭頭圖標使用您原來的 Icons.arrow_forward_ios
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: Colors.white70,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}
