// lib/widgets/channel_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ❗ 關鍵新增：引入 CachedNetworkImage ❗
import 'package:cached_network_image/cached_network_image.dart';
import '../models/channel.dart'; // 引入 NewsChannel model
import '../pages/player_page.dart'; // 引入 PlayerPage
import '../providers/channel_provider.dart'; // 引入 Provider 狀態

class ChannelCard extends ConsumerWidget {
  final NewsChannel channel;

  // 由於 ChannelCard 需要監聽 isShowingAll 狀態來調整樣式，所以使用 ConsumerWidget
  const ChannelCard({super.key, required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 監聽切換按鈕的狀態 (判斷是否為「顯示全部」模式)
    final isShowingAll = ref.watch(showAllChannelsProvider);

    // 根據 videoId 構造縮圖 URL (保持不變)
    final thumbnailUrl =
        'https://img.youtube.com/vi/${channel.videoId}/hqdefault.jpg';

    // 檢查是否為被隱藏的頻道，且當前為「顯示全部」模式
    final isHiddenAndShowingAll = isShowingAll && channel.isHidden;

    return InkWell(
      onTap: () {
        // 點擊後導航到播放器頁面
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PlayerPage(channel: channel)),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. 頂部的縮圖區域 (佔滿剩餘垂直空間)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black, // 背景色，用於圖片載入失敗時
                borderRadius: BorderRadius.circular(25.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25.0),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // ❗ 關鍵修正：使用 CachedNetworkImage 替代 Image.network ❗
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover, // 確保圖片覆蓋整個卡片
                      // 載入佔位符：在圖片載入時顯示進度條
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      // 圖片載入失敗時，顯示一個預設圖示 (Error Widget)
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),

                    // 如果頻道是被隱藏的，顯示一個半透明圖層 (保持不變)
                    if (isHiddenAndShowingAll)
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

          // 2. 獨立的頻道名稱 (在 Expanded 圖片的下方) (保持不變)
          Padding(
            padding: const EdgeInsets.only(
              top: 0.0,
              left: 4.0,
              right: 4.0,
              bottom: 0.0,
            ),
            child: Text(
              channel.name,
              textAlign: TextAlign.center, // 讓名稱置中
              style: TextStyle(
                // 根據狀態改變文字顏色
                color: isHiddenAndShowingAll ? Colors.grey : Colors.white,
                fontSize: 20, // 頻道名稱文字的大小
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2, // 允許名稱換行
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
