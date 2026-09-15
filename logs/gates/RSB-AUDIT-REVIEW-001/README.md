# RSB-AUDIT-REVIEW-001 実行証拠（2026-09-13）

対象: HEAD 12d7be9 に対する未コミットのレビュー修正。
範囲・契約: specs/packets/RSB-AUDIT-REVIEW-001.md。

## 修正前の回帰テスト（期待した失敗、成功ログとは分離）

- G3-records-before.log: FAIL。21 pass / 3 error。
  `type NamedTuple has no field context_shift_count` / `context_shifts`。
  文脈の差し替え自体は受理され、必要な変更診断が無かった。
- G3-overlay-before.log: FAIL。20 pass / 3 error。
  `KeyError: key "constraint_check_complete" not found` / `unknown_conclusions`。
  未指定の結論を持つ適用制約について、必要な未知診断が無かった。

## 修正後の対象テスト（成功）

- G3-plan-after.log: PASS、6/6。登録網羅性と漏れ・重複・存在しないファイルの拒否。
- G3-records-after.log: PASS、履歴88/88、独立な小有限台述語計算12289/12289、既存モデル32/32。
  文脈5項目の個別変更と復帰、TOML再読込からの診断再計算、CLI、4096通りの符号化を検査。
- G3-circuits-after.log: PASS、8241/8241、16/16、33/33。
  共通trace/loss/判定の改変拒否、独立Boolean式との更新比較、探索再測定、既存5証人。
- G3-overlay-after.log: PASS、46/46。未知結論と既知矛盾の4組合せ、前提不明時の非適用、CLI。
- G3-closure-after.log: PASS、38/38。未登録だった既存suiteの単体実行。

## 全体テスト

G3-full.log: PASS、終了コード0、`Testing ERIEC tests passed`。
修正した計画表で全73ファイル（並列69・逐次4）のPkg.test()が通過。
登録漏れだったClosureAudit 38/38、登録網羅性6/6、Lean–Julia contract 1317/1317も確認。
逐次グループの既存CLI検査を含む実行に約13分を要した。

## ゲートの範囲

formal/、src/、ledger、catalog、Project/Manifestは変更しない。
今回のG1/G4再実行や新しい理論証明はない。既存G1/G2/G4 baselineは
logs/gates/RSB-AUDIT-001/README.md と同ディレクトリの実ログを参照。
全体Pkg.test()には既存Lean–Julia接続テストも含む。台帳statusの更新はない。
