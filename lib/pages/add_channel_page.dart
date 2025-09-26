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

  void _saveChannel() async {
    // 1. 驗證表單
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // ============== 修正點：在這裡定義所有區域變數 ==============
    final name = _nameController.text.trim();
    final rawInput = _urlController.text.trim();

    // 2. 解析 YouTube ID
    String? videoId = YoutubePlayer.convertUrlToId(rawInput) ?? rawInput;

    if (videoId == null || videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('無效的 YouTube ID 或網址'),
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
                  hintText: '請貼上如 "https://www.youtube.com/watch?v=..." 的網址',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.white70),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入有效的 YouTube 網址或 ID';
                  }
                  // 簡單檢查是否能解析出 ID
                  String? videoId =
                      YoutubePlayer.convertUrlToId(value.trim()) ??
                      value.trim();
                  if (videoId.isEmpty) {
                    return '無法從輸入解析出有效的 YouTube ID';
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
