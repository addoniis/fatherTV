// lib/providers/channel_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart';
import '../services/database_service.dart';
import '../data/channels_data.dart';

// 狀態類別：管理頻道的 CRUD 邏輯
class ChannelNotifier extends StateNotifier<List<NewsChannel>> {
  ChannelNotifier() : super([]);

  final dbService = DatabaseService();

  // 初始化：從資料庫加載頻道，如果資料庫為空，則載入靜態預設列表
  Future<void> loadChannels() async {
    List<NewsChannel> channels = await dbService.getAllChannelsForManagement();

    // 如果資料庫中沒有任何頻道，則插入預設列表
    if (channels.isEmpty) {
      await _insertDefaultChannels();
      channels = await dbService.getAllChannelsForManagement();
    }

    // 按照 order 排序
    channels.sort(
      (a, b) => (a.channelOrder ?? 999).compareTo(b.channelOrder ?? 999),
    );
    state = channels;
  }

  // 輔助函數：將靜態預設頻道插入資料庫
  Future<void> _insertDefaultChannels() async {
    // defaultChannels 來自 channels_data.dart
    for (int i = 0; i < defaultChannels.length; i++) {
      // 插入時，設定 channelOrder
      await dbService.insertChannel(defaultChannels[i]);
    }
  }

  // U - 刪除頻道
  Future<void> deleteChannel(NewsChannel channel) async {
    if (channel.id == null) return;
    await dbService.deleteChannel(channel.id!);
    // 更新狀態 (從列表中移除)
    state = state.where((c) => c.id != channel.id).toList();
  }

  // U - 切換隱藏/顯示狀態
  Future<void> toggleHidden(NewsChannel channel) async {
    final updatedChannel = channel.copyWith(isHidden: !channel.isHidden);
    await dbService.updateChannel(updatedChannel);

    // 更新狀態 (替換列表中的物件)
    state = [
      for (final c in state)
        if (c.id == channel.id) updatedChannel else c,
    ];
  }

  // U - 更新頻道排序
  Future<void> updateOrder(int oldIndex, int newIndex) async {
    // 1. 在記憶體中處理排序邏輯
    final List<NewsChannel> updatedList = List.from(state);
    final channelToMove = updatedList.removeAt(oldIndex);
    updatedList.insert(newIndex, channelToMove);

    // 2. 更新狀態 (這會觸發 UI 刷新)
    state = updatedList;

    // 3. 將新的排序寫回資料庫
    // 遍歷列表，將新的 index 作為 channelOrder 寫入
    final List<NewsChannel> channelsToUpdate = [];
    for (int i = 0; i < updatedList.length; i++) {
      // 只有當 order 發生變化時才寫入，這裡簡化為全部寫入
      channelsToUpdate.add(updatedList[i].copyWith(channelOrder: i));
    }
    await dbService.updateChannelOrder(channelsToUpdate);
  }

  // 【新增：實現 addChannel 方法，並修正型別為 NewsChannel】
  Future<void> addChannel(NewsChannel newChannel) async {
    // 1. 設定新頻道的 order (放在列表末尾)
    final channelOrder = state.length;
    // 由於 newChannel 可能沒有 ID，這裡先設定 order，ID 交給 dbService.insertChannel 處理
    final channelToInsert = newChannel.copyWith(channelOrder: channelOrder);

    // 2. 將新頻道寫入資料庫
    // 假設 dbService.insertChannel 會返回或確保新的 channel 有 ID
    await dbService.insertChannel(channelToInsert);

    // 3. 重新載入所有頻道，以確保 UI 和數據庫同步
    await loadChannels();
  }

  // ----------------------------------------------------
  // 【新增功能：合併新增頻道列表】
  // ----------------------------------------------------
  Future<int> mergeChannels(List<NewsChannel> newChannels) async {
    if (newChannels.isEmpty) {
      return 0;
    }

    final addedCount = await dbService.insertNewChannels(newChannels);

    // 重新載入狀態，通知所有監聽者更新 UI
    await loadChannels();

    return addedCount;
  }

  // ----------------------------------------------------
  // 【新增功能：將頻道列表重置為預設狀態】
  // ----------------------------------------------------
  Future<void> resetChannels() async {
    // 1. 清空所有現有頻道
    await dbService.deleteAllChannels();

    // 2. 插入預設的頻道列表
    await _insertDefaultChannels();

    // 3. 重新載入狀態，通知所有監聽者更新 UI
    await loadChannels();
  }

  // ----------------------------------------------------
  // 【新增功能：用於 JSON 備份/匯入 - setChannels 方法】
  // ----------------------------------------------------

  // R - 接收匯入的頻道列表，清空舊資料庫並設定為新的狀態
  Future<void> setChannels(List<NewsChannel> newChannels) async {
    // 1. 清空舊資料庫 (確保匯入是乾淨的覆蓋)
    await dbService.deleteAllChannels();

    // 2. 批量插入新的頻道
    int order = 0;
    for (final channel in newChannels) {
      // 使用匯入時提供的 channelOrder，如果沒有則使用遞增的 order
      final finalOrder = channel.channelOrder ?? order;
      await dbService.insertChannel(channel.copyWith(channelOrder: finalOrder));
      order = finalOrder;
    }

    // 3. 重新載入狀態，通知所有監聽者更新 UI
    await loadChannels();
  }
}

// 供主頁使用的 Provider (負責啟動 ChannelNotifier)
final channelListProvider =
    StateNotifierProvider<ChannelNotifier, List<NewsChannel>>((ref) {
      final notifier = ChannelNotifier();
      notifier.loadChannels(); // 啟動時載入數據
      return notifier;
    });

// 篩選出顯示的頻道列表 (用於主播放列表)
final visibleChannelListProvider = Provider<List<NewsChannel>>((ref) {
  final allChannels = ref.watch(channelListProvider);
  return allChannels.where((c) => !c.isHidden).toList();
});
