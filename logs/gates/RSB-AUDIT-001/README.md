# RSB-AUDIT-001 実行証拠（2026-09-10）

監査ツールの第一実装単位。新規Lean証明、certified API、台帳statusの追加・変更はない。
対象の手法と使用方法は `specs/drafts/reactivation-substrate-v1-design.md` §12、
変更範囲は `specs/packets/RSB-AUDIT-001.md` を参照する。

## 成功した個別検査

- G1: `G1-20260910.log`、既存Lean全体ビルド、2813 jobs。
- G2: `G2-20260910.log`、既存Lean–Julia対応、1317/1317。
- 対象G3: `G3-target-retry-20260910.log`、履歴43件・モデル31件、合計74/74。
- 全体G3: `G3-full-20260910.log`、新規suiteを含む `Pkg.test()` が終了コード0で通過。
- G4 baseline: `G4-baseline-retry-20260910.log`、既存dc.systemのcatalog/scope/依存辺8/8。
  再実行用の `check-existing-anchor.jl` は依存関係の診断だけを行い、モデルのcertificateを発行しない。
- CLI例: `model-witnesses-20260910.toml` に全6例の関係表、測定例の全64介入traceを保存。
- 履歴例: `make-history-example.jl` で生成し、`history-example-check.log` にCLI検証結果を保存。
  同じディレクトリのreceiptは説明用であり、真正な外部保管の実演ではない。

## モデルの判定範囲

列順はhSelf / hSMC / hAct / hBound。

| 由来 | 例 | 真偽値 |
|---|---|---|
| 抽象関係 | 全条件 | T T T T |
| 抽象関係 | hSelfのみ不成立 | F T T T |
| 抽象関係 | hSMCのみ不成立 | T F T T |
| 抽象関係 | hActのみ不成立 | T T F T |
| 抽象関係 | hBoundのみ不成立 | T T T F |
| 6ユニットの発信停止測定 | 全条件・有効な外向き境界 | T T T T |

背景条件は有限台内閉性と正確なグラフ境界。非退化条件は空でないproper Kと空でないε。
測定例はe→c→m→eの活動維持とa↔bの交互活動を持ち、d=m AND aへ実効的な境界辺がある。
K={e,c,m}、ε={e}、Act=境界={m}。測定方式は改訂2のP=H=6、L=R=4を使う。
これは8ユニット候補の登録前評価ではない。

抽象モデルの分離結果を、同じ測定方式で各条件を独立に落とせるという結果へ拡張しない。
M2随伴、M1〜M4全体、内在的分解の一般的一意性、現象性の有無はこの検査の結論ではない。
全出力でphenomenal_claim=not_certified、execution_certified=falseを維持する。

## 失敗した初回検査（保持）

- `G3-target-20260910.log`: 42成功・1失敗。分類名の期待がundeterminedだったが、
  出力は残余状態に合わせたunderdetermined。テストの期待を修正し、上記再実行で通過。
- `G4-baseline-20260910.log`: 5成功・1失敗・1エラー。補助スクリプトでSymbolとStringを
  比較し、依存グラフ入力にtrustを渡していなかった。既存APIに合わせて修正し、上記再実行で通過。
- 履歴例生成スクリプトの初回はincludeの親ディレクトリ数を一つ誤り、ファイル不在で停止。
  パス修正後の成功ログは `history-example-generation.log`。

セキュリティ確認: TOMLをデータとして読み、未知項目を拒否。証拠参照からコード実行・通信を起動しない。
digest鎖は内容の整合性検査であり署名ではない。外部receiptなしでは正しいprefixへの切詰めを検出できない。
残余0件はrequires_reviewのままで、経験不存在や説明成功を出力しない。
