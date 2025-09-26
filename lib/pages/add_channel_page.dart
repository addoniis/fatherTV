// lib/pages/add_channel_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// 假設需要 YoutubePlayer 庫來轉換網址
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
// 使用別名 (as models) 引入 NewsChannel 類別
import 'package:news_stream_app/models/channel.dart' as models;
// 引入 Channel Provider
import 'package:news_stream_app/providers/channel_provider.dart';

class AddChannelPage extends ConsumerStatefulWidget {
  const AddChannelPage({super.key});

  @override
  ConsumerState<AddChannelPage> createState() => _AddChannelPageState();
}

class _AddChannelPageState extends ConsumerState<AddChannelPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _saveChannel() async {
    // 改為 async 以等待 notifier.addChannel
    // 1. 驗證表單
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final rawInput = _urlController.text.trim();

    // 2. 解析 YouTube ID
    String? videoId = YoutubePlayer.convertUrlToId(rawInput) ?? rawInput;

    if (videoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('無效的 YouTube ID 或網址'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final notifier = ref.read(channelListProvider.notifier);
    final allChannels = notifier.state;

    // 3. 檢查 ID 是否重複
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

    // 4. 建立並儲存新頻道
    // 【修正：將 models.Channel 改為 models.NewsChannel】
    final newChannel = models.NewsChannel(
      id: null, // ID 設為 null，由資料庫自動生成
      name: name,
      videoId: videoId,
      isHidden: false, // 預設可見
      // order 將在 notifier 內部被重新計算，這裡可以暫時忽略
      channelOrder: 0,
    );

    try {
      // 5. 新增頻道
      await notifier.addChannel(newChannel);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('頻道 "${name}" 新增成功！')));
      Navigator.of(context).pop(); // 返回設定頁面
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('儲存頻道失敗: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新增頻道'),
        backgroundColor: Colors.indigo,
        actions: [
          // 放在 App Bar 上的儲存按鈕
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
                style: const TextStyle(color: Colors.white), // 確保在深色背景下文字是白色
                decoration: const InputDecoration(
                  labelText: '頻道名稱',
                  hintText: '例如：TVBS 新聞',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.white70), // Label 顏色
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
