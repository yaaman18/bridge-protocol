#!/usr/bin/env bash
# watcher-stop.sh — SessionEnd フックから呼ばれる specs watcher 停止スクリプト

PID_FILE="$HOME/.agents/specs-watcher-erie-c.pid"

if [[ -f "$PID_FILE" ]]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null
        echo "[specs-watcher] 停止 PID=$PID"
    fi
    rm -f "$PID_FILE"
else
    echo "[specs-watcher] PID ファイルなし、スキップ"
fi
