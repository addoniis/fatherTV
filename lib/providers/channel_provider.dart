// lib/providers/channel_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/channel.dart';
import '../services/database_service.dart';
import '../data/channels_data.dart';

// 狀態類別：管理頻道的 CRUD 邏輯
class ChannelNotifier extends StateNotifier<List<NewsChannel>> {
  // 假設 DatabaseService 已經存在並可以執行批量更新
  final DatabaseService _databaseService = DatabaseService();

  ChannelNotifier() : super([]);

  // ----------------------------------------------------
  // Helper 函數：在內部使用排序邏輯
  // ----------------------------------------------------
  void _sortChannels() {
    state.sort(
      (a, b) => (a.channelOrder ?? 999).compareTo(b.channelOrder ?? 999),
    );
  }

  // ----------------------------------------------------
  // 【新增功能】：手勢切換頻道邏輯 (PlayerPage 呼叫)
  // ----------------------------------------------------
  NewsChannel? selectRelativeChannel(NewsChannel currentChannel, int offset) {
    final allChannels = state;

    // 1. 過濾出所有可見的頻道 (非隱藏)
    final visibleChannels = allChannels.where((c) => !c.isHidden).toList();

    if (visibleChannels.isEmpty) {
      return null; // 如果沒有可見頻道，則返回 null
    }

    // 2. 找到當前頻道在可見列表中的索引
    int currentIndex = visibleChannels.indexWhere(
      (c) => c.id == currentChannel.id,
    );

    if (currentIndex == -1) {
      // 如果當前頻道不在可見列表中，預設從第一個開始
      currentIndex = 0;
    }

    // 3. 計算新的索引，並處理循環 (Wrap-around)
    int newIndex = currentIndex + offset;
    final totalCount = visibleChannels.length;

    // 確保索引在 0 到 totalCount-1 之間循環
    if (newIndex >= totalCount) {
      newIndex = 0; // 循環到第一個
    } else if (newIndex < 0) {
      newIndex = totalCount - 1; // 循環到最後一個
    }

    // 4. 返回新的頻道物件
    return visibleChannels[newIndex];
  }

  // ----------------------------------------------------
  // 批量管理功能 (已實現)
  // ----------------------------------------------------

  // U - 批量隱藏所有頻道
  Future<void> hideAllChannels() async {
    // 1. 批量更新資料庫 (需要 DatabaseService 支援此方法)
    // 假設 DatabaseService 有一個方法來更新所有頻道的 isHidden 狀態
    await _databaseService.updateAllChannelsVisibility(isHidden: true);

    // 2. 更新 Riverpod 狀態
    state = [for (final channel in state) channel.copyWith(isHidden: true)];
  }

  // U - 批量顯示所有頻道
  Future<void> showAllChannels() async {
    // 1. 批量更新資料庫
    await _databaseService.updateAllChannelsVisibility(isHidden: false);

    // 2. 更新 Riverpod 狀態
    state = [for (final channel in state) channel.copyWith(isHidden: false)];
  }

  // ----------------------------------------------------
  // CRUD 邏輯 (修正 delete/remove 方法名稱)
  // ----------------------------------------------------

  // 初始化：從資料庫加載頻道
  Future<void> loadChannels() async {
    List<NewsChannel> channels = await _databaseService
        .getAllChannelsForManagement();

    // 如果資料庫中沒有任何頻道，則插入預設列表
    if (channels.isEmpty) {
      await _insertDefaultChannels();
      channels = await _databaseService.getAllChannelsForManagement();
    }

    // 呼叫內部排序
    state = channels;
    _sortChannels();
  }

  // 輔助函數：將靜態預設頻道插入資料庫
  Future<void> _insertDefaultChannels() async {
    // defaultChannels 來自 channels_data.dart
    for (int i = 0; i < defaultChannels.length; i++) {
      // 插入時，設定 channelOrder
      await _databaseService.insertChannel(
        defaultChannels[i].copyWith(channelOrder: i),
      );
    }
  }

  // ❗ U - 刪除頻道 (原 deleteChannel，改為 removeChannel 以匹配 UI) ❗
  Future<void> removeChannel(NewsChannel channel) async {
    if (channel.id == null) return;
    await _databaseService.deleteChannel(channel.id!);

    // 更新狀態 (從列表中移除)
    state = state.where((c) => c.id != channel.id).toList();
  }

  // U - 切換隱藏/顯示狀態
  Future<void> toggleHidden(NewsChannel channel) async {
    final updatedChannel = channel.copyWith(isHidden: !channel.isHidden);
    await _databaseService.updateChannel(updatedChannel);

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

    // ReorderableListView 的標準處理邏輯:
    // 當從上往下拖曳時，newIndex 會是目標位置的下一個索引，需要 -1。
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

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
    await _databaseService.updateChannelOrder(channelsToUpdate);
  }

  // C - 新增頻道
  Future<void> addChannel(NewsChannel newChannel) async {
    // 1. 設定新頻道的 order (放在列表末尾)
    final channelOrder = state.length;
    final channelToInsert = newChannel.copyWith(channelOrder: channelOrder);

    // 2. 將新頻道寫入資料庫
    await _databaseService.insertChannel(channelToInsert);

    // 3. 重新載入所有頻道，以確保 UI 和數據庫同步
    await loadChannels();
  }

  // U - 實現更新頻道功能
  Future<void> updateChannel(NewsChannel updatedChannel) async {
    // 1. 更新資料庫
    await _databaseService.updateChannel(updatedChannel);

    // 2. 更新 Riverpod 狀態
    state = [
      for (final channel in state)
        if (channel.id == updatedChannel.id) updatedChannel else channel,
    ];

    // (可選) 重新排序，確保順序正確
    _sortChannels();
  }

  // 合併新增頻道列表
  Future<int> mergeChannels(List<NewsChannel> newChannels) async {
    if (newChannels.isEmpty) {
      return 0;
    }

    final addedCount = await _databaseService.insertNewChannels(newChannels);

    // 重新載入狀態，通知所有監聽者更新 UI
    await loadChannels();

    return addedCount;
  }

  // 將頻道列表重置為預設狀態
  Future<void> resetChannels() async {
    // 1. 清空所有現有頻道
    await _databaseService.deleteAllChannels();

    // 2. 插入預設的頻道列表
    await _insertDefaultChannels();

    // 3. 重新載入狀態，通知所有監聽者更新 UI
    await loadChannels();
  }

  // 用於 JSON 備份/匯入 - setChannels 方法
  Future<void> setChannels(List<NewsChannel> newChannels) async {
    // 1. 清空舊資料庫 (確保匯入是乾淨的覆蓋)
    await _databaseService.deleteAllChannels();

    // 2. 批量插入新的頻道
    int order = 0;
    for (final channel in newChannels) {
      // 使用匯入時提供的 channelOrder，如果沒有則使用遞增的 order
      final finalOrder = channel.channelOrder ?? order;
      await _databaseService.insertChannel(
        channel.copyWith(channelOrder: finalOrder),
      );
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

// -----------------------------------------------------------------
// 針對「顯示/隱藏所有頻道」功能的新增與修改
// -----------------------------------------------------------------

// 1. 新增 StateProvider：追蹤是否強制顯示所有頻道 (包含隱藏的)
final showAllChannelsProvider = StateProvider<bool>((ref) => false);

// 2. 修改 visibleChannelListProvider 的邏輯
final visibleChannelListProvider = Provider<List<NewsChannel>>((ref) {
  final allChannels = ref.watch(channelListProvider);
  final showAll = ref.watch(showAllChannelsProvider); // 監聽新的狀態

  if (showAll) {
    // 如果 showAll 為 true，則回傳所有頻道 (無論 isHidden 狀態)
    return allChannels;
  } else {
    // 否則，只回傳 isHidden = false 的頻道
    return allChannels.where((c) => !c.isHidden).toList();
  }
});
