import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 引入 YouTube Player 庫，用於解析 ID
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
// 使用別名 (as models) 引入 NewsChannel 類別
import 'package:news_stream_app/models/channel.dart' as models;
import 'package:news_stream_app/providers/channel_provider.dart';

class AddChannelPage extends ConsumerStatefulWidget {
  // 關鍵新增點：接收一個可選的 NewsChannel 物件
  final models.NewsChannel? channelToEdit;

  const AddChannelPage({super.key, this.channelToEdit}); // 加入到建構式

  @override
  ConsumerState<AddChannelPage> createState() => _AddChannelPageState();
}

class _AddChannelPageState extends ConsumerState<AddChannelPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // 關鍵新增點：如果是編輯模式，初始化 Controller 的值
    if (widget.channelToEdit != null) {
      _nameController.text = widget.channelToEdit!.name;
      // 編輯時顯示 ID，而不是完整的 URL
      _urlController.text = widget.channelToEdit!.videoId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  // =======================================================
  // ❗ 修正：新增增強的 URL 解析方法 ❗
  // =======================================================
  String? _parseYoutubeId(String rawInput) {
    rawInput = rawInput.trim();

    // 1. 優先使用 youtube_player_flutter 的方法 (處理 watch?v= 和 youtu.be/ 短連結)
    String? id = YoutubePlayer.convertUrlToId(rawInput);
    if (id != null && id.isNotEmpty) {
      return id;
    }

    // 2. 處理 /live/ID 或 /embed/ID 格式
    final uri = Uri.tryParse(rawInput);

    // 確保是有效的 YouTube URI
    if (uri != null &&
        (uri.host.contains('youtube.com') || uri.host.contains('youtu.be'))) {
      final pathSegments = uri.pathSegments;

      // 檢查路徑段，處理 /live/ID 或 /embed/ID 格式
      if (pathSegments.length >= 1) {
        // 檢查第一個路徑段是否是 'live' 或 'embed'
        if (pathSegments[0] == 'live' || pathSegments[0] == 'embed') {
          // ID 應該是第二個路徑段
          if (pathSegments.length >= 2) {
            // 返回 ID 並排除後面的查詢參數 (如 ?si=...)
            return pathSegments[1].split('?').first;
          }
        }
      }
    }

    // 3. 如果以上解析都失敗，假設輸入就是一個裸 ID (例如手動輸入的 ID)
    // 進行簡單的 ID 格式檢查 (YouTube ID 約 11 字元)
    if (rawInput.length >= 5 &&
        rawInput.length <= 15 &&
        !rawInput.contains(' ')) {
      return rawInput;
    }

    return null;
  }
  // =======================================================

  void _saveChannel() async {
    // 1. 驗證表單
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ============== 修正點：在這裡使用新的解析方法 ==============
    final name = _nameController.text.trim();
    final rawInput = _urlController.text.trim();

    // 2. 解析 YouTube ID (使用增強的解析邏輯)
    String? videoId = _parseYoutubeId(rawInput);

    if (videoId == null || videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('無效的 YouTube ID、網址或格式不支援'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 3. 取得 Channel Notifier
    final notifier = ref.read(channelListProvider.notifier);
    final allChannels = notifier.state;
    // =======================================================

    // 4. 判斷模式：編輯或新增
    if (widget.channelToEdit != null) {
      // ------------------- 編輯模式 -------------------

      // 檢查 ID 是否重複 (如果 ID 改變且與現有頻道重複)
      final existingChannelId = widget.channelToEdit!.id;
      final isDuplicate = allChannels.any(
        (c) => c.videoId == videoId && c.id != existingChannelId,
      );
      // ... (後續編輯邏輯保持不變)

      if (isDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('此頻道 ID 已經被其他頻道使用。'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 執行更新邏輯
      final updatedChannel = widget.channelToEdit!.copyWith(
        name: name,
        videoId: videoId,
        // order 和 isHidden 保持不變
      );

      await notifier.updateChannel(updatedChannel);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('頻道 "$name" 更新成功！')));
    } else {
      // ------------------- 新增模式 -------------------

      // 檢查 ID 是否重複
      final isDuplicate = allChannels.any((c) => c.videoId == videoId);
      // ... (後續新增邏輯保持不變)

      if (isDuplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('此頻道 ID 已經存在於列表中。'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 建立並儲存新頻道
      final newChannel = models.NewsChannel(
        id: null,
        name: name,
        videoId: videoId,
        isHidden: false,
        channelOrder: 0,
      );

      await notifier.addChannel(newChannel);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('頻道 "$name" 新增成功！')));
    }

    // 儲存完成後返回上一頁
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 根據模式修改標題
    final pageTitle = widget.channelToEdit != null ? '編輯頻道' : '新增頻道';

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle), // 使用變數
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveChannel,
            tooltip: '儲存頻道',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: '頻道名稱',
                  hintText: '例如：TVBS 新聞',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入頻道名稱';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'YouTube 直播網址或頻道 ID',
                  // 提示更全面
                  hintText: '貼上網址 (watch?v=, live/, youtu.be/) 或影片/頻道 ID',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入有效的 YouTube 網址或 ID';
                  }
                  // ❗ 修正：使用增強的解析方法來驗證 ❗
                  String? videoId = _parseYoutubeId(value.trim());

                  if (videoId == null || videoId.isEmpty) {
                    return '無法從輸入解析出有效的 YouTube ID。請檢查格式。';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              // 獨立的儲存按鈕
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saveChannel,
                  icon: const Icon(Icons.save),
                  label: const Text('儲存頻道'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
