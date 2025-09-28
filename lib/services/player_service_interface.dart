// lib/services/player_service_interface.dart

import 'package:flutter/material.dart';

// 定義播放器狀態
enum PlayerState { ready, playing, paused, ended, buffering, error }

// 抽象介面：定義所有播放器服務必須實現的功能
abstract class PlayerServiceInterface {
  // 取得播放器 Widget：這是唯一需要知道 Flutter Widget Tree 的地方
  Widget buildPlayerWidget(String videoId);

  // 播放控制
  void play();
  void pause();
  void seekTo(Duration position);
  void mute();
  void unMute();

  // 狀態流 (Stream)：用於 PlayerPage 監聽播放狀態
  Stream<PlayerState> get onPlayerStateChange;

  // 清理資源
  void dispose();
}
