// lib/pages/add_channel_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 引入 services 處理 InputFormatter
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:news_stream_app/models/channel.dart' as models;
import 'package:news_stream_app/providers/channel_provider.dart';
import '../services/youtube_service.dart';

// =======================================================
// 1. 自定義的字寬格式化器 (VisualWidthLimiter)
// =======================================================

// ❗ 關鍵修正 1: 設定最大允許的字寬為 16 單位 (8 個中文字) ❗
const int maxVisualWidth = 16;

class VisualWidthLimiter extends TextInputFormatter {
  // 檢查字元是否為寬字元（例如中文、全形符號等）
  bool _isWide(String char) {
    // CJK 統一漢字範圍大致從 4E00 到 9FFF
    final codeUnit = char.codeUnitAt(0);
    return codeUnit >= 0x4e00 && codeUnit <= 0x9fff;
  }

  // 計算輸入字串的視覺字寬
  int _calculateVisualWidth(String text) {
    int width = 0;
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      // 如果是中文字（寬字元），則視為 2 單位寬度
      width += _isWide(char) ? 2 : 1;
    }
    return width;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final newWidth = _calculateVisualWidth(newValue.text);

    // 如果字寬不超過限制，則允許輸入
    if (newWidth <= maxVisualWidth) {
      return newValue;
    }

    // 如果超過限制，則需要從頭計算並截斷
    int currentWidth = 0;
    int truncateIndex = 0;

    for (int i = 0; i < newValue.text.length; i++) {
      final char = newValue.text[i];
      currentWidth += _isWide(char) ? 2 : 1;

      if (currentWidth > maxVisualWidth) {
        // 找到了超過限制的點，截斷點就在這個字元之前
        truncateIndex = i;
        break;
      }
    }

    final truncatedText = newValue.text.substring(0, truncateIndex);

    return TextEditingValue(
      text: truncatedText,
      selection: TextSelection.collapsed(offset: truncatedText.length),
    );
  }
}

// =======================================================
// 2. AddChannelPage 核心邏輯
// =======================================================

class AddChannelPage extends ConsumerStatefulWidget {
  final models.NewsChannel? channelToEdit;

  const AddChannelPage({super.key, this.channelToEdit});

  @override
  ConsumerState<AddChannelPage> createState() => _AddChannelPageState();
}

class _AddChannelPageState extends ConsumerState<AddChannelPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  bool _isParsing = false;

  final YouTubeService _youtubeService = YouTubeService();

  @override
  void initState() {
    super.initState();
    if (widget.channelToEdit != null) {
      _nameController.text = widget.channelToEdit!.name;
      _urlController.text = widget.channelToEdit!.videoId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  // 本地解析方法：解析各種 YouTube URL 或 ID
  String? _parseYoutubeId(String rawInput) {
    rawInput = rawInput.trim();
    String? id = YoutubePlayer.convertUrlToId(rawInput);
    if (id != null && id.isNotEmpty) {
      return id;
    }

    final uri = Uri.tryParse(rawInput);
    if (uri != null &&
        (uri.host.contains('youtube.com') || uri.host.contains('youtu.be'))) {
      final pathSegments = uri.pathSegments;
      if (pathSegments.length >= 1) {
        if (pathSegments[0] == 'live' || pathSegments[0] == 'embed') {
          if (pathSegments.length >= 2) {
            return pathSegments[1].split('?').first;
          }
        }
      }
    }

    if (rawInput.length >= 5 &&
        rawInput.length <= 15 &&
        !rawInput.contains(' ')) {
      return rawInput;
    }

    return null;
  }

  // 核心新增：解析頻道資訊並填充欄位
  Future<void> _parseChannelInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('請先輸入 YouTube 網址！'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isParsing = true;
    });

    try {
      final result = await _youtubeService.getChannelInfoFromUrl(url);

      if (result['name'] != null || result['videoId'] != null) {
        // 1. 填充頻道名稱 (保留完整名稱)
        if (result['name'] != null && result['name']!.isNotEmpty) {
          _nameController.text = result['name']!;
        }

        // 2. 填充影片 ID
        if (result['videoId'] != null && result['videoId']!.isNotEmpty) {
          _urlController.text = result['videoId']!;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('解析成功！已自動填充頻道名稱與影片 ID。'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('已解析頻道名稱，但找不到有效的直播 ID。請嘗試使用直播影片連結。'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('解析失敗。請確認網址是否有效，或手動輸入 ID。'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('網絡請求失敗或發生錯誤。'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isParsing = false;
      });
    }
  }

  void _saveChannel() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 額外檢查字寬：確保儲存時不超限
    if (VisualWidthLimiter()._calculateVisualWidth(
          _nameController.text.trim(),
        ) >
        maxVisualWidth) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('頻道名稱的字寬超過限制！請縮短名稱以符合排版建議 (最多 8 個中文字)。'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final rawInput = _urlController.text.trim();
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

    final notifier = ref.read(channelListProvider.notifier);
    final allChannels = notifier.state;

    // 儲存邏輯 (新增/編輯) 保持不變
    if (widget.channelToEdit != null) {
      // 編輯模式
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

      final updatedChannel = widget.channelToEdit!.copyWith(
        name: name,
        videoId: videoId,
      );
      await notifier.updateChannel(updatedChannel);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('頻道 "$name" 更新成功！')));
    } else {
      // 新增模式
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

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final pageTitle = widget.channelToEdit != null ? '編輯頻道' : '新增頻道';

    return Scaffold(
      appBar: AppBar(
        title: Text(pageTitle),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isParsing ? null : _saveChannel, // 解析中禁用
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
              // ----------------------------------------------------
              // 頻道名稱輸入框 (使用 VisualWidthLimiter)
              // ----------------------------------------------------
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),

                // 應用字寬格式化器 (限制總寬度為 16)
                inputFormatters: [VisualWidthLimiter()],

                decoration: const InputDecoration(
                  labelText: '頻道名稱',
                  hintText: '例如：TVBS 新聞',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(color: Colors.white70),
                  counterText: "", // 移除計數器
                  // ❗ 關鍵修正 2: 更新提示訊息 ❗
                  helperText: '建議頻道名稱控制在 8 個中文字或 16 個英文字母內，以確保主頁排版美觀。',
                  helperStyle: TextStyle(color: Colors.orange, fontSize: 14),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入頻道名稱';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // ----------------------------------------------------
              // YouTube 網址/ID 輸入框與解析按鈕
              // ----------------------------------------------------
              TextFormField(
                controller: _urlController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'YouTube 直播網址或頻道 ID',
                  hintText: '貼上直播網址，或手動輸入影片/頻道 ID',
                  border: const OutlineInputBorder(),
                  labelStyle: const TextStyle(color: Colors.white70),
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: _isParsing ? null : _parseChannelInfo,
                      icon: _isParsing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.search, size: 20),
                      label: Text(_isParsing ? '解析中...' : '解析網址'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                      ),
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '請輸入有效的 YouTube 網址或 ID';
                  }
                  String? videoId = _parseYoutubeId(value.trim());

                  if (videoId == null || videoId.isEmpty) {
                    return '無法從輸入解析出有效的 YouTube ID。請檢查格式。';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),
              // ----------------------------------------------------
              // 儲存按鈕
              // ----------------------------------------------------
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isParsing ? null : _saveChannel,
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
