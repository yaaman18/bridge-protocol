#!/usr/bin/env bash
# watcher-start.sh — SessionStart フックから呼ばれる specs watcher 起動スクリプト

PID_FILE="$HOME/.agents/specs-watcher-erie-c.pid"
LOG_FILE="$HOME/.agents/specs-watcher-erie-c.log"
WATCHER="$(cd "$(dirname "$0")" && pwd)/watch-specs.sh"

# 既存プロセスがいれば停止
if [[ -f "$PID_FILE" ]]; then
    OLD_PID=$(cat "$PID_FILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        kill "$OLD_PID" 2>/dev/null
    fi
    rm -f "$PID_FILE"
fi

# バックグラウンドでデーモン起動
nohup bash "$WATCHER" >> "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"
echo "[specs-watcher] 起動 PID=$(cat $PID_FILE)"
