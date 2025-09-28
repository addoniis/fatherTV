// lib/services/youtube_player_service.dart

import 'dart:async';
import 'package:flutter/material.dart';
// 導入 youtube_player_flutter，使用 'as yt' 進行別名處理
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as yt;

// 引入抽象接口
import 'player_service_interface.dart';

class YouTubePlayerService implements PlayerServiceInterface {
  // 使用 yt.YoutubePlayerController 避免名稱衝突
  late yt.YoutubePlayerController _controller;
  final String _videoId;

  // 用於廣播狀態變化的 StreamController
  final _stateController = StreamController<PlayerState>.broadcast();

  // 構造函數：初始化 YouTube Controller
  YouTubePlayerService(this._videoId) {
    _controller = yt.YoutubePlayerController(
      initialVideoId: _videoId,
      flags: const yt.YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        showLiveFullscreenButton: false,
        loop: false,
        forceHD: true,
      ),
    )..addListener(_youtubeListener); // 監聽 YouTube Controller 的狀態
  }

  // 將 youtube_player_flutter 的狀態映射到我們定義的 PlayerState
  void _youtubeListener() {
    // 只有當播放器準備就緒時才讀取狀態，避免初始化時的錯誤狀態
    if (!_controller.value.isReady) return;

    // 引用 youtube_player_flutter 的狀態
    final state = _controller.value.playerState;
    PlayerState mappedState;

    switch (state) {
      // ready 狀態使用 unStarted 或 cued
      case yt.PlayerState.unStarted:
      case yt.PlayerState.cued:
        mappedState = PlayerState.ready;
        break;
      case yt.PlayerState.playing:
        mappedState = PlayerState.playing;
        break;
      case yt.PlayerState.paused:
        mappedState = PlayerState.paused;
        break;
      case yt.PlayerState.ended:
        mappedState = PlayerState.ended;
        break;
      case yt.PlayerState.buffering:
        mappedState = PlayerState.buffering;
        break;
      // 錯誤狀態使用 yt.PlayerState.unknown，並映射到我們自定義的 PlayerState.error
      case yt.PlayerState.unknown:
        mappedState = PlayerState.error;
        break;
      // ❗ 關鍵修正: 移除不存在的 yt.PlayerState.error ❗
      default:
        // 忽略其他不確定的狀態
        return;
    }
    _stateController.add(mappedState);
  }

  @override
  Widget buildPlayerWidget(String videoId) {
    // 實作接口要求的回傳 Widget
    return yt.YoutubePlayer(
      // 使用 yt.YoutubePlayer
      controller: _controller,
      showVideoProgressIndicator: true,
      progressIndicatorColor: Colors.redAccent,
    );
  }

  // 實作所有控制方法
  @override
  void play() => _controller.play();

  @override
  void pause() => _controller.pause();

  @override
  void seekTo(Duration position) => _controller.seekTo(position);

  @override
  void mute() => _controller.mute();

  @override
  void unMute() => _controller.unMute();

  // 實作狀態流
  @override
  Stream<PlayerState> get onPlayerStateChange => _stateController.stream;

  // 清理資源
  @override
  void dispose() {
    _controller.dispose();
    _stateController.close();
  }
}
