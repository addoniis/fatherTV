// lib/services/database_service.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/channel.dart'; // 確保您已正確導入 NewsChannel

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'news_stream.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE channels(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            videoId TEXT,
            channelOrder INTEGER,
            isHidden INTEGER DEFAULT 0  -- 0=顯示, 1=隱藏
          )
        ''');
      },
    );
  }

  // C - 插入頻道
  Future<void> insertChannel(NewsChannel channel) async {
    final db = await database;
    // 查找當前最大的 order
    final maxOrderResult = await db.rawQuery(
      'SELECT MAX(channelOrder) FROM channels',
    );
    // 插入時，如果 channelOrder 為空，則設定為最大值 + 1；如果非空 (例如從 JSON 匯入)，則使用現有值
    final maxOrder = maxOrderResult.first['MAX(channelOrder)'] as int? ?? 0;
    final finalOrder = channel.channelOrder ?? (maxOrder + 1);

    // 假設 NewsChannel 有 toSqliteMap 方法接受 order 參數
    await db.insert(
      'channels',
      channel.toSqliteMap(finalOrder),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // R - 獲取所有頻道 (用於管理頁面)
  Future<List<NewsChannel>> getAllChannelsForManagement() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'channels',
      orderBy: 'channelOrder ASC',
    );
    // 假設 NewsChannel 有 fromSqliteMap 靜態方法
    return List.generate(maps.length, (i) {
      return NewsChannel.fromSqliteMap(maps[i]);
    });
  }

  // U - 更新頻道 (用於 isHidden 和名稱/ID)
  Future<void> updateChannel(NewsChannel channel) async {
    final db = await database;
    // 假設 NewsChannel 有 toSqliteMap 方法
    await db.update(
      'channels',
      channel.toSqliteMap(channel.channelOrder),
      where: 'id = ?',
      whereArgs: [channel.id],
    );
  }

  // U - 更新頻道排序 (批量)
  Future<void> updateChannelOrder(List<NewsChannel> channels) async {
    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < channels.length; i++) {
      batch.update(
        'channels',
        {'channelOrder': i},
        where: 'id = ?',
        whereArgs: [channels[i].id],
      );
    }
    await batch.commit(noResult: true);
  }

  // -----------------------------------------------------------------
  // ❗ 修正錯誤：新增批量更新 isHidden 的方法 ❗
  // -----------------------------------------------------------------

  // U - 批量更新所有頻道的 isHidden 狀態 (用於設定頁面的一鍵隱藏/顯示)
  Future<void> updateAllChannelsVisibility({required bool isHidden}) async {
    final db = await database;
    // isHidden (bool) 在 SQLite 中以 1 (true) 或 0 (false) 儲存
    final int value = isHidden ? 1 : 0;

    // 執行 SQL UPDATE 語句，where: '1' 確保更新所有行
    await db.update(
      'channels',
      {'isHidden': value}, // 設定所有頻道的 isHidden 欄位為 value
      where: '1',
    );
  }

  // ------------------------------------
  // 【新增功能：清除所有頻道 (用於 JSON 匯入)】
  // ------------------------------------
  Future<void> deleteAllChannels() async {
    final db = await database;
    // 刪除 'channels' 表格中的所有行
    await db.delete('channels');
  }

  // ----------------------------------------------------
  // 【新增功能：插入新的頻道列表，並跳過重複項】
  // ----------------------------------------------------
  Future<int> insertNewChannels(List<NewsChannel> newChannels) async {
    final db = await database;
    int addedCount = 0;

    // 1. 取得現有所有頻道的 VideoID
    final existingVideoIds = (await db.query(
      'channels',
      columns: ['videoId'],
    )).map((map) => map['videoId'] as String).toSet();

    // 2. 查找當前最大的 order
    final maxOrderResult = await db.rawQuery(
      'SELECT MAX(channelOrder) FROM channels',
    );
    int currentMaxOrder =
        maxOrderResult.first['MAX(channelOrder)'] as int? ?? 0;

    final batch = db.batch();

    for (final channel in newChannels) {
      // 3. 檢查是否重複 (透過 videoId 檢查)
      if (!existingVideoIds.contains(channel.videoId)) {
        currentMaxOrder++; // 排序值遞增

        // 4. 新增到批次操作
        // 假設 NewsChannel 有 toSqliteMap 方法接受 order 參數
        batch.insert(
          'channels',
          channel.toSqliteMap(currentMaxOrder),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        addedCount++;
      }
    }

    await batch.commit(noResult: true);
    return addedCount;
  }

  // D - 刪除頻道
  Future<void> deleteChannel(int id) async {
    final db = await database;
    await db.delete('channels', where: 'id = ?', whereArgs: [id]);
  }
}
