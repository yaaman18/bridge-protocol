# RSB-BIND-001: 判定基準の束縛と解析計画 schema v2

- 作成: 2026-10-08（ユーザー指示「さらに作業を続けて」、RSB-PLAN-002 §2(2)）
- 設計の出典: `specs/packets/RSB-PLAN-002.md` §3（判定基準の実装を束縛）、§4.2（結果の欄の完全一致）、§8（schema v2）、§9
- 範囲外（次の作業単位）: §6 再実行の方針（試行番号、1回目の封印、重なる case の一致検査）、§3.5 の `src/` tree OID の記録
- 登録済み profile では run しない。登録・再登録もしない。scratch 登録だけで試験する。

## 1. 目的・解く問題

現行の `start_run` は、判定基準を**名前だけ**で照合する（`recorded_criteria` と `criterion_id` の一致）。
同じ名前の代役や、別の場所にある同名パッケージを渡しても run が始まる。RSB-PLAN-002 §3 は、判定基準を
定義するパッケージのディレクトリの git tree OID を解析計画に書き、登録時と run 開始時にそれを検査することで、
「サポートされる run 経路で、登録したパッケージのコードが使われたこと」を保証する設計を定めた。本作業はそれを実装する。

## 2. 確認済みの証拠

- 解析計画の schema は v1 のみで、未知のキーを拒否する厳密な schema（`tools/SubstrateRegistry/src/schema.jl`）。
  任意キーの仕組みはない。v2 草案（`specs/drafts/reactivation-analysis-plan-v2.toml`）は v1 schema を通らない。
- 検証器は profile と解析計画の blob を `profile_commit` から `registration_commit` までの全 commit で照合している
  （`verify.jl` (iv)）。tree OID の照合はない。
- `start_run` は解析計画を runner checkout から読み直し、`check_criteria_binding` で名前だけを照合する（`run.jl`）。

## 3. 設計

### 3.1 schema v2（`rsb-analysis-schema-v2`）

v1 は残す（取り下げ済みの rsb-002 の登録が検証できるように）。v2 は草案の全セクションを厳密に定義する。

- 任意キーの仕組み `OptionalSpec` を追加する。使うのは反証行の `expected_components` だけ。
- 新しい型 `:scalar_table`（値が真偽値か文字列の、空でない表）を `expected_components` に使う。
- `[[criterion_binding]]`: `criterion_id`, `criterion_version`, `package_name`, `package_path`（安全な相対パス）,
  `package_tree_oid`（40 桁）, `value_keys`, `diagnostic_keys`。1 行以上。
- 意味の検査: `criterion_binding` の `criterion_id` は一意で、その集合は `recorded_criteria` と一致する。

登録表と run 開始レコードの `analysis_schema_validation_version` に v2 を許す。

### 3.2 登録時の検査（RSB-PLAN-002 §3.2）

v2 の登録について、各 `criterion_binding` の `package_path` が

1. `profile_commit` で tree であり、その tree OID が `package_tree_oid` と一致する（`BINDING_TREE_MISMATCH`）。
2. `profile_commit` から `registration_commit` までの ancestry path 上の全 commit で、同じ tree OID を保つ（`BINDING_TREE_CHANGED`）。

### 3.3 run 開始時の検査（RSB-PLAN-002 §3.3、§4.2）

v2 の解析計画について、何かを測る前に次を検査し、一つでも外れれば出力を作らずに拒否する。

1. runner checkout の `HEAD:<package_path>` の tree OID が登録値と一致する。
2. 判定基準オブジェクトの定義元パッケージ名（`Base.moduleroot(parentmodule(typeof(c)))`）が `package_name` と一致する。
3. そのパッケージの `pkgdir` が、runner checkout の `package_path` と同じディレクトリである。
4. `criterion_version` が登録値と一致する。

各 case の判定結果について、`values` のキー集合が `value_keys` と、`diagnostics` のキー集合が `diagnostic_keys` と
完全一致しなければ、その case を記録せず run を失敗させる。

v1 の解析計画は現行どおり名前だけで照合する（v1 の本番登録はもう無い。RSB-PLAN-002 §9）。

## 4. 仮説・未検証部分

- `pkgdir` の比較は、パッケージが `Pkg` の path 依存として読み込まれた場合に、そのディレクトリを返すことを前提にする。
  試験で、runner checkout の外にある同名パッケージを読み込ませて拒否されることを確かめる。

## 5. 守れないこと（RSB-PLAN-002 §3.4 をそのまま引き継ぐ）

実行中に `evaluate` のメソッドを別モジュールから再定義されることは防げない。守るのは、サポートされる run 経路で
登録したパッケージのコードが使われたことまで。

## 6. ゲート

1. SubstrateRegistry の試験: schema v2 の受理・拒否（未知キー、`expected_components` の型、binding と
   recorded_criteria の不一致）、登録時の tree OID の一致・不一致・途中変更。
2. ReactivationMeasurement の試験: v2 の scratch 登録で、本物の判定基準を模した試験用パッケージを使い、
   反証行 STAND-IN・TREE-DRIFT・FOREIGN-LOAD・RESULT-KEYS（RSB-PLAN-002 §10）がそれぞれ拒否されること、
   正しい組み合わせでは run が完了すること。v1 の既存試験がすべて通ること。
3. 既存の試験（エンジン 70,537 件、プラグイン、リポジトリ側の関連試験）が通ること。

## 7. 意味変更の有無

なし。判定の意味、解析計画の読み方、登録済みファイルは変えない。検証器と run 経路に検査を足すだけ。

## 8. 禁止変更

登録済みの profile・解析計画 v1・登録表を書き換えない。登録済み profile で run しない。`phenomenal_claim` を動かさない。
`formal/`・`src/`・`specs/ledger.toml` を変更しない。

## 9. 状態（2026-10-08）

実装とゲートの実行を終えた（`logs/gates/RSB-BIND-001/README.md`）。変更したファイル:
`tools/SubstrateRegistry/src/{schema.jl, verify.jl, records.jl, git.jl, SubstrateRegistry.jl}`、
`tools/ReactivationMeasurement/src/{criteria.jl, run.jl, ReactivationMeasurement.jl}`、
試験 `tools/ReactivationMeasurement/test/binding_v2.jl`（`runtests.jl` から読み込む）。
