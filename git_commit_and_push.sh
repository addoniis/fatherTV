#!/bin/bash

# 定義你的專案路徑 (請根據你 Mac Mini 上的實際路徑調整)
PROJECT_DIR="/Users/adonischang/Flutter/news_stream_app"

# --- 以下是腳本執行部分，通常不需要修改 ---

echo "正在進入專案目錄: $PROJECT_DIR"
cd "$PROJECT_DIR" || { echo "錯誤: 無法進入專案目錄 $PROJECT_DIR"; exit 1; }

# 檢查工作目錄狀態
echo "正在檢查 Git 工作目錄狀態..."
git status

# 檢查是否有未暫存或未提交的更改
if [[ -z "$(git status --porcelain)" ]]; then
  echo "沒有檢測到本地更改，無需提交。"
  exit 0
fi

# 提示用戶輸入提交訊息
read -p "請輸入提交訊息 (Commit Message): " COMMIT_MESSAGE

# 檢查提交訊息是否為空
if [ -z "$COMMIT_MESSAGE" ]; then
  echo "錯誤: 提交訊息不能為空。操作已取消。"
  exit 1
fi

# 暫存所有更改
echo "執行 git add ."
git add .

# 提交更改
echo "執行 git commit -m \"$COMMIT_MESSAGE\""
git commit -m "$COMMIT_MESSAGE"

# 檢查提交是否成功
if [ $? -ne 0 ]; then
  echo "錯誤: Git 提交失敗。請檢查上方的錯誤訊息。"
  exit 1
fi

# 推送到 GitHub
echo "執行 git push origin main"
git push origin main

# 檢查推送是否成功
if [ $? -ne 0 ]; then
  echo "錯誤: Git 推送失敗。請檢查上方的錯誤訊息。"
  exit 1
fi

echo "Git 操作成功完成！你的更改已提交並推送到 GitHub。"
