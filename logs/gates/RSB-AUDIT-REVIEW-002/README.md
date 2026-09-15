# RSB-AUDIT-REVIEW-002 検証結果

2026-09-13。ユーザー依頼によるLOW-A/B修正。Claude Codeへの送信なし。
変更範囲・契約: specs/packets/RSB-AUDIT-REVIEW-002.md。
before/は今回の開始時点の4ファイルを保存したもので、先行REVIEW-001の変更を含む。

## 修正前（期待した失敗）

- G3-overlay-before.log: FAIL、58 pass / 10 error。
  `KeyError: key "incomplete_check_count" not found`。実report、合成report、CLIで集計が欠落。
- G3-model-before.log: FAIL。既存履歴88/88の後、参照テスト12289 pass / 1 fail。
  `boundary_differs_from_proper_support > 0` に対し `Evaluated: 0 > 0`。
  完全グラフだけの被覆ではneighborsを無視した判定と区別できないことを確認。

## 修正後（成功）

- G3-overlay-after.log: PASS、72/72。
  実reportとCLIの0件、合成reportの1件/2件、未知結論2個を持つ1行は1件とする集計、
  witness有無×既知矛盾有無の4通りの併存を確認。
- G3-model-after.log: PASS。履歴88/88、独立参照24579/24579、既存証人32/32。
  完全グラフと鎖e→m→cの各4096通り、合計8192通りを同一の直接量化式で比較。
  境界とκの非空真部分集合性が異なるケースが鎖で存在することを確認。

## 変異検査（誤実装を検出した期待失敗）

- G3-boundary-mutation.log: FAIL、15360 pass / 1 fail、終了コード1。
  `check_dc_pattern`の境界生成だけを隔離コピーで置換。
  neighborsを使わず、κ=Cなら空、それ以外はκを境界にする誤実装を入れた。
  実際の参照テストを抽出し、failfastで最初の不一致に停止。
  `result.valid && result.actual == reference` が鎖のケースで失敗した。
  完全グラフの全4096ケースは通過し、追加したグラフによる検出能力を確認できた。
- prepare-boundary-mutation.py / boundary-mutation-test.jl / mutation/に再現コードと隔離コピーを保存。
  本体のWitnesses.jlや正式APIは変更していない。

## 検証範囲

git diff --checkは成功。formal/src/ledger/Project/Manifestへの差分なし。
今回、全体Pkg.test/G1/G4は再実行していない。実行計画・正式API・接続は無変更で、
対象2ファイルの検証を実施した。先行REVIEW-001の全体73ファイル成功は過去の証拠として保持。
ledger statusの更新・commit/push・agentへの送信は行っていない。
