# RSB-RETRY-001: 再実行の方針（試行の上限・封印・重なる case の一致）

- 作成: 2026-10-08（ユーザー指示「再実行の方針（§6）に進んで」）
- 設計の出典: `specs/packets/RSB-PLAN-002.md` §6、§9、§10（RETRY-MISMATCH、THIRD-ATTEMPT）
- 前提: RSB-BIND-001（解析計画 schema v2）。試行の管理は v2 の解析計画の run にだけ適用し、v1 の経路は変えない。
- 登録済み profile では run しない。scratch 登録だけで試験する。

## 1. 目的・解く問題

run が途中で止まったとき、黙ってやり直して都合のよい結果を選べるなら、事前登録の意味が薄れる。RSB-PLAN-002 §6 は、
試行を2回までに限り、1回目の出力を消さずに封じ、2回目が1回目と重なる case で完全一致しなければ run を撤回すると定めた。
測定は決定的なので、一致しないのは実装か環境の誤りである。

## 2. 設計

### 2.1 試行番号はエンジンが決める

`out_dir` の親ディレクトリ（runs root）にある run のうち、同じ `registration_id` の run 開始レコードを持つものを数える。
呼び出し側は試行番号を渡さない。

| 既存の試行 | 扱い |
|---|---|
| 0 | 1回目 |
| 1（完了 manifest が無いか、`complete` でない） | 2回目。1回目を封じてから始める |
| 1（`complete`） | 拒否（`retry_condition` を満たさない） |
| 2 以上 | 拒否（`max_attempts = 2`、登録は使い切り） |

`run_id` は `-attempt-<k>` で終わらなければならない（RSB-PLAN-002 §6「試行番号は run_id に含め」）。拒否は出力を作る前に行う。

### 2.2 封印

2回目は、測る前に1回目の出力ディレクトリの全ファイルの SHA-256 の一覧を `previous-attempt-seal.toml` として書き、
その SHA-256 を run 開始レコードに記録する。封印は中身を解釈しない（バイト列のハッシュを取るだけ）。

### 2.3 重なる case の一致と撤回

2回目の全 case を測り終えた後、

1. 1回目の出力をもう一度ハッシュして封印と一致することを確かめる。違えば `previous_attempt_changed`。
2. 1回目にある case 記録と判定結果のファイルごとに、2回目の同じパスのファイルとバイト単位で一致することを確かめる。
   違えば `retry_overlap_mismatch`。

どちらかがあれば、完了 manifest の `status` を `retracted` とする（解析しない）。

### 2.4 記録の形式

- run 開始レコード: v2 の解析計画の run は `record_schema_version = 3` とし、`attempt`（1 か 2）、
  `previous_attempt_run_id`、`previous_attempt_seal_sha256` を持つ。1回目は後の2つが空。v1 の run は version 2 のまま。
- 完了 manifest: `status` に `retracted` を加え、不一致の符号に `retry_overlap_mismatch` と `previous_attempt_changed` を加える。

## 3. 守れないこと

runs root を変えれば、試行の数え直しは防げない。守るのは「サポートされる run 経路で、同じ runs root の中では
試行が2回を超えず、2回目が1回目と照合される」ことまで（RSB-001 §2 と同じく、任意の Julia コードに対する安全境界ではない）。

## 4. ゲート

ReactivationMeasurement の試験で、scratch の v2 登録について:

1. 1回目が途中で止まり、2回目が完了し、重なる case が一致する → `complete`、run 開始レコードに試行番号と封印が残る。
2. 3回目 → 拒否（THIRD-ATTEMPT）。
3. 1回目が完了済みなのに2回目 → 拒否。
4. 1回目の重なる case 記録を1バイト変えてから2回目 → `retracted`（RETRY-MISMATCH）。
5. `run_id` の試行番号が違う → 拒否。
6. 封印と照合の補助関数: 1回目のファイルを封印後に変えると `previous_attempt_changed` を返す。

既存の試験（登録機構、エンジン、RSB-BIND-001、判定プラグイン）がすべて通ること。

## 5. 意味変更の有無

なし。判定の意味と解析計画の読み方は変えない。解析計画 v2 草案に、RSB-PLAN-002 §10 の手続きの反証行を書き足す。

## 6. 禁止変更

登録済みファイルを書き換えない。登録済み profile で run しない。`phenomenal_claim` を動かさない。

## 7. 状態（2026-10-08）

実装とゲートの実行を終えた（`logs/gates/RSB-RETRY-001/README.md`）。変更したファイル:
`tools/SubstrateRegistry/src/{schema.jl, records.jl}`、`tools/ReactivationMeasurement/src/{run.jl, ReactivationMeasurement.jl}`、
試験 `tools/ReactivationMeasurement/test/binding_v2.jl`、`tools/ReactivationERIEC/test/runtests.jl`（UNMASKED）、
`test/test_analysis_plan_expectations.jl`、草案 `specs/drafts/reactivation-analysis-plan-v2.toml`。
