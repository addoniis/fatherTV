// lib/models/channel.dart

class NewsChannel {
  // 新增資料庫和排序所需的屬性
  final int? id; // 資料庫主鍵 (可為空)
  final String name;
  final String videoId;
  final int? channelOrder; // 頻道排序
  final bool isHidden; // 隱藏狀態

  const NewsChannel({
    this.id,
    required this.name,
    required this.videoId,
    this.channelOrder, // 允許為空，資料庫自動處理
    this.isHidden = false, // 預設為顯示
  });

  // 1. 實現 copyWith 方法 (用於 Riverpod 狀態更新)
  NewsChannel copyWith({
    int? id,
    String? name,
    String? videoId,
    int? channelOrder,
    bool? isHidden,
  }) {
    return NewsChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      videoId: videoId ?? this.videoId,
      channelOrder: channelOrder ?? this.channelOrder,
      isHidden: isHidden ?? this.isHidden,
    );
  }

  // 2. 轉為 SQLite Map (C/U 操作)
  Map<String, dynamic> toSqliteMap(int? order) {
    return {
      // id 不需要寫入，因為它是 AUTOINCREMENT
      'name': name,
      'videoId': videoId,
      'channelOrder': order ?? channelOrder,
      'isHidden': isHidden ? 1 : 0, // SQLite 不支援 bool，使用 1/0
    };
  }

  // 3. 從 SQLite Map 構建物件 (R 操作)
  factory NewsChannel.fromSqliteMap(Map<String, dynamic> map) {
    return NewsChannel(
      id: map['id'] as int?,
      name: map['name'] as String,
      videoId: map['videoId'] as String,
      channelOrder: map['channelOrder'] as int?,
      isHidden: (map['isHidden'] as int) == 1,
    );
  }

  // ----------------------------------------------------
  // 【新增功能：JSON 序列化與反序列化 (用於備份/匯入)】
  // ----------------------------------------------------

  // 4. 將 NewsChannel 物件轉換成 JSON Map (用於匯出)
  Map<String, dynamic> toJson() {
    return {
      // 匯出時不需要 id (資料庫主鍵)
      'name': name,
      'videoId': videoId,
      // channelOrder 和 isHidden 是備份時需要保留的狀態
      'channelOrder': channelOrder,
      'isHidden': isHidden,
    };
  }

  // 5. 從 JSON Map 建立 NewsChannel 物件 (用於匯入)
  factory NewsChannel.fromJson(Map<String, dynamic> json) {
    return NewsChannel(
      // 匯入的 JSON 通常沒有 id，讓資料庫在寫入時自動生成
      name: json['name'] as String,
      videoId: json['videoId'] as String,
      // 確保這些欄位可以安全地被解析
      channelOrder: json['channelOrder'] as int?,
      isHidden:
          json['isHidden'] as bool? ??
          false, // 容錯處理：如果舊備份沒有 isHidden，預設為顯示 (false)
    );
  }
}
