# モデル評価成果物と反例 claim の境界

## 二種類の成果物

- **反例 claim** は `∃ model, assumptions ∧ ¬P model` という数学的言明である。固定した
  Lean statement と `sorry` / 新規公理のない証明を持ち、`specs/claim-ledger-v2.toml` の
  `claim_kind="counterexample"` として別途 G0–G4 を通す。
- **モデル評価成果物**は「この有限モデル表現を、この台帳束縛のcheckerへ入力した」という
  Julia実行記録である。Lean証明でもcertified claimでもない。claim台帳には自動登録せず、
  `logs/model-evaluations/<evaluation_id>/` にcreate-onlyで保存する。

この分離は、実行結果を数学的反例として誤昇格させないための境界である。いずれの成果物でも
`phenomenal_claim` は `not_certified` から変更しない。

## 三値 outcome

- `pass`: checkerが正常終了して対象述語を通した。1状態モデルがM4を通った場合もここに記録する。
  これは「条件がそのモデルを排除しない」という観測であり、反例claimではない。
- `reject`: checkerが正常終了して対象述語を落とした。一つ以上の`failed_predicates`を必須とする。
  `claim_relation="counterexample_candidate"` を付けても候補にすぎない。
- `error`: 入力のschema検証、変換、checker実行のいずれかが判定を完了しなかった。
  `failed_predicates`を持たせず、例外内容をJSON-safeな`error_message`と実行ログへ保存する。

`reject` と `error` は交換可能ではない。入力不良や実装例外を反例として数えない。

## 保存単位（schema version 2）

一回の評価は次を同一ディレクトリにsnapshotする。

```text
logs/model-evaluations/<evaluation_id>/
├── source-model.json   # 実際に読んだ入力bytes
├── model.json          # schema検証後のcanonical bytes（入力不良時はraw bytes）
├── checker-source.jl   # 台帳が指すcheckerソース
├── adapter-source.jl   # model decode・canonicalize・checker入力変換のソース
├── registry.json       # VP・semantic manifest・certificate catalogの束縛
├── checker.log         # stdout/stderrまたはerror
├── evaluation.json     # outcomeと全hash
└── seal.sha256         # evaluation.jsonのSHA-256
```

`evaluation.json` はsource/canonical model、checker/adapter source、registry、log、ManifestのSHA-256、
checker relation、Lean宣言、git commit/dirty、Julia version、seed、数値仮定を保持する。
実装APIは既存`evaluation_id`を拒否し、固定名上書きをしない。これはアプリケーション上の
append-only規約であり、WORM媒体や署名を意味しない。後からファイルを直接変更した場合はauditが検出する。

auditではsnapshotのディレクトリ脱出、symlink脱出、hash/seal不一致、fingerprint不一致、
registry内の識別子不一致を失敗にする。現在の台帳が過去snapshotから変化した場合は、過去の実行を
失効させずdrift warningとして報告する。`list`は壊れた項目も隠さず返し、同じcanonical fingerprintを
持つ複数実行をaggregate auditの重複一覧へ載せる。

## M4有限モデルadapter

`body.no_terminal_setpoint` は次の固定schemaだけを受け取る。
このadapterが判定するのは登録済みの終対象禁止述語`ERIEC.Body.NoTerminalSetPoint`であり、
M4を構成する他の条件まで一回の評価で証明したとは扱わない。

```json
{
  "kind": "set_point_diagram_model",
  "schema_version": 1,
  "contract_id": "body.no_terminal_setpoint",
  "carrier_complete": true,
  "relation_encoding": "closed_world_edge_list",
  "objects": ["state-a"],
  "reaches": [],
  "claim_status": "not_a_claim",
  "phenomenal_claim": "not_certified"
}
```

- `objects`は非空・一意なASCII識別子の完全carrierである。
- `reaches`は閉世界の有向辺一覧で、端点は必ず`objects`に含め、重複を許さない。
- 未知field、欠落field、carrier外端点は`reject`ではなく`error`になる。
- objectsとedgesをsortしたcanonical JSON bytesからfingerprintを計算する。field順や列挙順の差で
  別モデルにしない。
- 実行checkerは台帳の`VP-BDY-001 / body.no_terminal_setpoint /
  ERIEC.Body.NoTerminalSetPoint / check_m4_no_terminal_setpoint`に固定する。任意関数をchecker名へ
  偽装して渡す公開入口は持たない。auditはcanonical modelをadapterで再decodeしてchecker outcomeと
  failed predicateを再計算するため、内部保存primitiveでmodel bytesと実行値を分離しても失敗する。

一状態・辺なしはM4を`pass`し、一状態・自己辺ありは終対象を持つため`reject`する。

## 反例claim候補の境界

`counterexample_candidate`を指定できるのは、semantic manifestでreview済みの
`exact_finite_decision` checkerが`reject`した場合だけである。draft packet生成にはさらに
成果物audit成功を要求する。packetは次を固定する。

- source evaluationとwitnessのhash
- VP / contract / checker / Lean宣言 / failed predicate
- semantic scope、assumptions、guarantee
- `promotion_status="blocked"`、`automatic_promotion=false`
- 未確定の`target_claim_id`と、Lean statement固定・起票・証明という残作業

packet生成は`logs/counterexample-candidates/<evaluation_id>/`へcreate-onlyで保存し、
`claim-ledger-v2.toml`を変更しない。数学的反例への昇格は、packetとは別の明示的なclaim起票と
Lean証明によってのみ行う。

## CLI

専用入口は`bin/eriec-model-evaluation.jl`である。

```bash
julia --project=. bin/eriec-model-evaluation.jl run --model examples/model-evaluations/m4-one-state-pass.json --evaluation-id run-001
julia --project=. bin/eriec-model-evaluation.jl list --outcome reject
julia --project=. bin/eriec-model-evaluation.jl audit --evaluation-id run-001
julia --project=. bin/eriec-model-evaluation.jl draft --evaluation-id run-001
```

`run`のpass/rejectはexit 0、保存済みerrorはexit 1、引数エラーはexit 2。machine-readable JSONを
標準出力または標準エラーへ出す。入力モデルは`--root`内の実体ファイルに限定し、symlinkによる
root外参照を拒否する。

## Category pipelineの履歴

Category pipelineの各gate logは実行ごとの一意名で保存する。impact reportも
`logs/category-pipeline/reports/`へ一意名で履歴保存し、`specs/category-impact-report.md`は
最新結果への可読なcopyとしてだけ更新する。過去のpass/fail reportを固定名更新で失わない。
