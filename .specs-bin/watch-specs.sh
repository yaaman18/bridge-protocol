#!/usr/bin/env bash
# watch-specs.sh — specs/ の .md/.lean 変更を検知して codex に agmsg 通知

set -euo pipefail

WATCH_DIR="/Users/yamaguchimitsuyuki/erie-c/specs"
TEAM="erie"
FROM="claude"
TO="codex"
SEND="$HOME/.agents/skills/agmsg/scripts/send.sh"
LATENCY=2

echo "[specs-watcher] 起動: $WATCH_DIR を監視中 (latency=${LATENCY}s)"

# fswatch で変更を流し、grep で .md/.lean のみに絞る
fswatch \
    --latency "$LATENCY" \
    --event Created \
    --event Updated \
    --event Renamed \
    --recursive \
    "$WATCH_DIR" \
| grep --line-buffered -E '\.(md|lean)$' \
| while IFS= read -r filepath; do
    rel="${filepath#$WATCH_DIR/}"

    # 実在するファイルのみ通知（削除・リネーム先不在を除外）
    [[ -f "$filepath" ]] || continue

    msg="[spec更新] specs/${rel} が更新されました。内容を読んで実装を進めてください。"
    echo "[specs-watcher] → codex: $rel"
    "$SEND" "$TEAM" "$FROM" "$TO" "$msg"
done
