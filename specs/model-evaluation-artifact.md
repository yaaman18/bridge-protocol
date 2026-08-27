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

## 三値 outcome と失敗段階

- `pass`: checkerが正常終了して対象述語を通した。1状態モデルがM4を通った場合もここに記録する。
  これは「条件がそのモデルを排除しない」という観測であり、反例claimではない。
- `reject`: checkerが正常終了して対象述語を落とした。一つ以上の`failed_predicates`を必須とする。
  `claim_relation="counterexample_candidate"` を付けても候補にすぎない。
- `error`: 入力のschema検証、adapter変換、checker実行、保存前再検証のいずれかが判定を
  完了しなかった。`failed_predicates`を持たせず、最初の失敗を`error_stage` / `error_message`へ、
  発生した失敗列を`error_diagnostics`へ保存する。stageは`input_schema | adapter | checker |
  postflight`のいずれかで、各diagnosticはstageとJSON-safeなmessageを持つ。不正UTF-8を含む
  例外表示はbyte escapeして、成果物JSON自体を不正UTF-8にしない。

`reject` と `error` は交換可能ではない。入力不良や実装例外を反例として数えない。

## 保存単位（schema version 3）

reader/auditは既存のschema version 2成果物も読める。v2は明示的な失敗段階とreview provenanceを
持たないため、in-memoryではerrorを`legacy_unknown`として正規化し、registry provenance不足を
warningにする。新規書込みとdraft生成はversion 3だけを用いる。

一回の評価は次を同一ディレクトリにsnapshotする。

```text
logs/model-evaluations/<evaluation_id>/
├── source-model.json   # 実際に読んだ入力bytes
├── model.json          # adapter decode後のcanonical bytes（入力schema不良時はraw bytes）
├── checker-source.jl   # 台帳が指すcheckerソース
├── adapter-source.jl   # model decode・canonicalize・checker入力変換のソース
├── registry.json       # VP・semantic manifest・certificate catalogの束縛
├── checker.log         # stdout/stderrまたはerror
├── evaluation.json     # outcomeと全hash
└── seal.sha256         # evaluation.jsonのSHA-256
```

`evaluation.json` はsource/canonical model、checker/adapter source、registry、log、ManifestのSHA-256、
checker relation、Lean宣言、git commit/dirty、Julia version、seed、数値仮定、および上記の失敗段階を
保持する。`source-model.json`は実際に読んだraw bytesであり、登録adapterのdecodeが成功した場合だけ
`model.json`をcanonical bytesへ置き換える。両方のhashを別々に束縛し、canonical fingerprintを
raw fingerprintと混同しない。
実装APIは既存`evaluation_id`を拒否し、固定名上書きをしない。これはアプリケーション上の
append-only規約であり、WORM媒体や署名を意味しない。後からファイルを直接変更した場合はauditが検出する。

registry snapshotは台帳とsemantic manifestをそれぞれ一度だけ読んだbytesからparseとhashを行い、
certificate catalogのsource hashに加えて、対象Lean declarationを含むsource集合のdigestを保持する。
またsemantic manifestの`review_status="reviewed"`、非空の`reviewer`、`basis_log`を保存する。
これら四つのsource digest（ledger、semantic manifest、catalog、Lean source集合）と
`registry_git_commit`から`registry_generation_sha256`も作り、snapshot内の組合せを一つのgenerationとして
束縛する。各registry sourceはそのcommitのGit blobと一致する場合だけ評価へ使い、段階的なworktree更新を
別世代の組合せとして保存しない。
実行後のpostflightではchecker/adapter sourceとregistry bindingを再計算し、実行中の変更を`error`として
保存する。これにより、別世代のregistry値とdigestを一つのsnapshotへ混ぜない。

auditの結果は、snapshotの構造・seal・hash・束縛を検査する`ok`と、現在ロードされている
adapter/checkerで意味を再計算する`semantic_replay`を分ける。`semantic_replay`は`passed | failed |
skipped | not_attempted`である。ロード済みsourceがsnapshotからdriftした場合はreplayを`skipped`にし、
warningを返すが、hashで閉じた過去成果物そのものを失効させない。aggregate auditは各状態のcountと
`semantic_replay_complete` / `semantic_replay_ok`を別に返す。再計算の不一致や例外は構造`errors`ではなく
`replay_errors`へ保存するため、byte-integrityの`ok`と意味再生の成否を混同しない。

inventoryの`list` / aggregate auditは、正常なevaluationだけでなく、parse不能なdirectory、
`.pending-*`、store直下のforeignな非directoryも隠さず返す。filter指定時も壊れた項目を除外せず、
`entry_kind`と`filter_match`で正常な評価との違いを示す。同じcanonical fingerprintを持つ複数実行は
aggregate auditの重複一覧へ載せる。

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
- 実行adapterは登録済み`adapter_id`からsource、decode、checker入力変換をdispatchする。呼出側から
  任意の`prepare_model`やadapter sourceを注入できない。auditは`source-model.json`を同じ登録adapterで
  再decodeし、得られたcanonical bytesが`model.json`と一致することを検査する。
- adapter呼出しはロード時に固定したgeneric methodを`invoke`し、checkerは選択methodがロード時の
  登録methodと同一であることを検査する。さらにM4有限表現から独立に再計算したexact decisionと
  checker結果を照合し、同一Julia processで追加されたspecific methodによる判定差替えを拒否する。
- 実行checkerは台帳の`VP-BDY-001 / body.no_terminal_setpoint /
  ERIEC.Body.NoTerminalSetPoint / check_m4_no_terminal_setpoint`に固定する。任意関数をchecker名へ
  偽装して渡す公開入口は持たない。auditは登録adapterで復元したchecker入力からoutcomeと
  failed predicateを再計算するため、raw入力・canonical snapshot・実行値を分離しても失敗する。

一状態・辺なしはM4を`pass`し、一状態・自己辺ありは終対象を持つため`reject`する。

## 反例claim候補の境界

`counterexample_candidate`を指定できるのは、semantic manifestでreview済みの
`exact_finite_decision` checkerが`reject`した場合だけである。draft packet生成にはさらに
成果物audit成功、`semantic_replay=passed`、drift warningなしを要求する。packetは次を固定する。

- source evaluationとwitnessのhash
- VP / contract / checker / Lean宣言 / failed predicate
- registry snapshotのdigest、semantic scope、assumptions、guarantee、reviewer、basis log
- `promotion_status="blocked"`、`automatic_promotion=false`
- 未確定の`target_claim_id`と、Lean statement固定・起票・証明という残作業

packet生成は`logs/counterexample-candidates/<evaluation_id>/`へ`packet.json`と`seal.sha256`を
create-onlyで保存する。生成直前にもsource evaluationを再auditし、evaluation bytesとregistry bytesが
最初のaudit後から変わっていないことを再検証してからatomic renameする。これによりauditとpacket公開の
間のTOCTOUで別世代の値を固定しない。

draftにはstrict parser/read APIと、単体・一覧auditがある。draft auditはpacket seal、source evaluation
hash、witness/model fingerprint、registry digestとsemantic/review metadataを元成果物へ照合する。
draft inventoryも`.pending-*`、foreign entry、parse不能packetを隠さない。packet生成・read/audit/listは
`claim-ledger-v2.toml`を変更しない。数学的反例への昇格は、packetとは別の明示的なclaim起票と
Lean証明によってのみ行う。

## CLI

専用入口は`bin/eriec-model-evaluation.jl`である。

```bash
julia --project=. bin/eriec-model-evaluation.jl run --model examples/model-evaluations/m4-one-state-pass.json --evaluation-id run-001
julia --project=. bin/eriec-model-evaluation.jl list --outcome reject
julia --project=. bin/eriec-model-evaluation.jl audit --evaluation-id run-001
julia --project=. bin/eriec-model-evaluation.jl draft --evaluation-id run-001
julia --project=. bin/eriec-model-evaluation.jl draft-list
julia --project=. bin/eriec-model-evaluation.jl draft-audit --evaluation-id run-001
```

`run`のpass/rejectはexit 0、保存済みerrorはexit 1、引数エラーはexit 2。machine-readable JSONを
標準出力または標準エラーへ出す。`audit` / `draft-audit`は単体指定を省略するとstore全体を検査する。
入力モデルは`--root`内の実体ファイルに限定し、rootを`realpath`で正規化してsymlinkによるroot外参照や
成果物pathのroot外表示を拒否する。

## Category pipelineの履歴

Category pipelineの各gate logと`logs/category-pipeline/reports/`の履歴reportは、`mktemp`でpathを
先に予約してから書く。baselineの一時ファイルも実行ごとの一意名にし、固定`.tmp`同士を衝突させない。
`specs/category-impact-report.md`は最新結果への可読なcopyとしてだけ更新し、過去のpass/fail reportを
固定名更新で失わない。

quiet gate scriptは、log pathを明示した場合に既存pathをnoclobberで拒否し、既定pathは`mktemp`で
一意に予約する。Category/quietの履歴logはいずれも同時実行や同秒実行で既存証拠を上書きしない。
