// lib/services/youtube_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser; // 雖然我們不用完整的 html/parser，但知道這個套件存在

class YouTubeService {
  // ----------------------------------------------------
  // 核心功能：從 YouTube 連結解析頻道資訊
  // ----------------------------------------------------
  /// 嘗試從給定的 YouTube URL 中提取頻道名稱和直播 ID。
  /// 支援以下格式: 影片連結 / 頻道連結 / 直播連結。
  ///
  /// 回傳一個 Map: {'name': '頻道名稱', 'videoId': '直播ID'}
  Future<Map<String, String?>> getChannelInfoFromUrl(String url) async {
    // 預設失敗回傳
    final defaultResult = {'name': null, 'videoId': null};

    // 1. 檢查 URL 有效性
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return defaultResult;
    }

    try {
      // 2. 發送 HTTP 請求獲取頁面內容
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return defaultResult;
      }

      final body = response.body;

      // 3. 提取頻道名稱 (使用正則表達式尋找 <title> 標籤內容)
      // 尋找 <title>標籤，並忽略中間可能的換行符號
      final titleMatch = RegExp(
        r'<title>(.*?)</title>',
        dotAll: true,
      ).firstMatch(body);
      String? channelName;
      if (titleMatch != null && titleMatch.group(1) != null) {
        // 移除常見的 YouTube 標題後綴，例如: " - YouTube"
        channelName = titleMatch.group(1)!.trim();
        channelName = channelName.replaceAll(RegExp(r'\s*-\s*YouTube$'), '');
        channelName = channelName.replaceAll(RegExp(r'\s*\|\s*YouTube$'), '');
      }

      // 4. 提取直播 ID (使用正則表達式尋找 og:video:url 或標準影片 ID)
      String? videoId;

      // a) 嘗試從 URL 參數中提取 ID (適用於 ?v=...)
      videoId = _extractVideoIdFromQuery(uri);

      if (videoId == null) {
        // b) 嘗試從網頁內容中提取 ID (適用於直播頁面或短連結，尋找 "videoId":"...")
        final idMatch = RegExp(r'"videoId"\s*:\s*"(.*?)"').firstMatch(body);
        if (idMatch != null && idMatch.group(1) != null) {
          videoId = idMatch.group(1)!.trim();
        }
      }

      // c) 如果 videoId 仍然為空，可能是頻道連結，我們需要尋找直播流
      if (videoId == null && _isChannelUrl(uri)) {
        // ⚠️ 注意：這裡省略了從頻道頁面找到當前直播 ID 的複雜邏輯
        // 這是網頁解析的難點，通常需要更複雜的解析或使用 API。
        // 我們先要求用戶直接提供影片連結。
        // 這裡可以加入一個提示，引導用戶使用直播影片的 URL。
      }

      // 如果有找到名稱和 ID，則回傳
      return {'name': channelName, 'videoId': videoId};
    } catch (e) {
      // 發生網絡錯誤或解析錯誤
      print('YouTubeService 解析錯誤: $e');
      return defaultResult;
    }
  }

  // 輔助函數：從 URI 查詢參數中提取影片 ID (如: watch?v=)
  String? _extractVideoIdFromQuery(Uri uri) {
    if (uri.host.contains('youtube.com') &&
        uri.queryParameters.containsKey('v')) {
      return uri.queryParameters['v'];
    }
    // 處理短連結 youtu.be/xxxx
    if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.first;
    }
    return null;
  }

  // 輔助函數：判斷是否為頻道 URL
  bool _isChannelUrl(Uri uri) {
    // 檢查路徑是否包含 /channel/ 或 /@username 或 /user/
    return uri.pathSegments.isNotEmpty &&
        (uri.pathSegments.first.contains('channel') ||
            uri.pathSegments.first.startsWith('@') ||
            uri.pathSegments.first.contains('user'));
  }
}
