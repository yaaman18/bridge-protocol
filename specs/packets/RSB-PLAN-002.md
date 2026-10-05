# RSB-PLAN-002 — 解析計画 v2 と一括再登録

2026-09-30。設計のみ。実装・登録・run はこの packet では行わない。
根拠: ユーザー決定 2026-09-28（提案1・2・3 と再実行方針を、解析計画の改訂と再登録の1回にまとめる）、
RSB-GEN-001 §12・§15、RSB-001、RSB-002。新規 certified VP ではない。**DC を評価しない。**

## 1. 目的

RSB-003 の本番 run の前に、解析計画を一度だけ改訂し一度だけ再登録する。束ねるのは次の4項目で、
どれも本番 run の前に必要であり、どれも解析計画の digest を変える。

| 項目 | 何が足りないか |
|---|---|
| 1. 判定基準の**実装**の束縛 | 現在は名前 `dc` / `dc2` しか縛っていない。同名の代役でも束縛の検査を通る |
| 2. 判定結果の**形式**の登録 | case 記録の形式は profile で凍結済みだが、判定結果の形式はどの登録物にも無い |
| 3. **冗長性による偽**の読み方 | DC は単独停止だけから関係を作るので、冗長に支えられた構造を偽と読みうる。その読み方が未定 |
| 4. **再実行**の方針 | run が落ちた・不完全だったときに再実行してよいかが、解析計画にも RSB-002 にも無い |
| 5. 解析計画 v1 の**論理の誤り2件**の訂正 | 2026-09-30 の Lean 点検で見つかった（§6b）。登録済みだが run 前なので実害は無い |

## 2. 順序の制約（この設計の前提）

項目1 は、DC と DC2 の実装の同一性（そのパッケージの git tree OID）を解析計画に書き込む。
**DC と DC2 の実装は RSB-003 でこれから作る。** したがって一括再登録は次の順でしか成立しない。

```
(1) RSB-GEN-001 をコミット（測定エンジンの汎用化。済）
(2) 本 packet の機構を実装する（解析計画 schema v2、検証器の追加検査、エンジン側の束縛）
    — scratch 上で試験できる。登録済み profile は使わない
(3) RSB-003 で DC・DC2 のプラグインを実装し、fixture と独立実装で検証し、凍結する
(4) 解析計画 v2 を書く（(3) の tree OID と結果の欄を埋める）
(5) 一括再登録: 新しい登録行、rsb-002 の取り下げ（results_seen_before_withdrawal = false）
(6) 固定 remote 上で VERIFIED を確認
(7) 本番 run
```

**(5) より前に登録済み profile で run してはならない**（RSB-002 R1 と同じ）。
(2) と (3) は並行してよいが、(4) は両方の完了後。

## 3. 項目1 — 判定基準の実装を束縛する

### 3.1 何を束縛するか

判定基準ごとに、それを定義する**パッケージのディレクトリの git tree OID** を解析計画に記録する。
tree OID はそのディレクトリ以下の全ファイルの内容で決まり、1 バイトでも変われば変わる。
登録機構はすでに git の tree を扱っているので、新しい依存は要らない。

```toml
[[criterion_binding]]
criterion_id = "dc"
criterion_version = "..."            # RSB-003 凍結時に確定
package_name = "ReactivationERIEC"   # 仮称。RSB-003 で確定
package_path = "tools/ReactivationERIEC"
package_tree_oid = "<40 桁>"
value_keys = [...]                   # 項目2
diagnostic_keys = [...]              # 項目2
```

### 3.2 登録時の検査（検証器に追加）

- `profile_commit` における `package_path` の tree OID が `package_tree_oid` と一致する。
- `profile_commit` から `registration_commit` まで、その tree が変わっていない。
  RSB-001 §7(5)(iv) の「2 path の bytes が不変」を、判定基準のパッケージにも広げる。

### 3.3 run 開始時の検査（`start_run` に追加）

1. runner の checkout で `HEAD:<package_path>` の tree OID が登録値と一致する。
2. 渡された判定基準オブジェクトの**定義元パッケージ**の名前が `package_name` と一致する
   （`Base.moduleroot(parentmodule(typeof(c)))`）。
3. そのパッケージが実際に読み込まれたファイルの場所（`pkgdir`）が、runner の checkout の
   `package_path` の中にある。別の場所の同名パッケージを読み込んでいないことを確かめる。
4. `criterion_version` が登録値と一致する。

これで**試験用の代役は拒否される**。代役は試験モジュールで定義されており、登録されたパッケージの
中に無いからである。

### 3.4 守れないこと（契約に明記する）

実行中に `evaluate` のメソッドを別モジュールから再定義されることは防げない。Julia に access control は
無い（RSB-001 §2）。守るのは「サポートされる run 経路で、登録したパッケージのコードが使われたこと」まで。

### 3.5 ERIEC 本体（`src/`）を縛るか

DC プラグインは `src/dc.jl` の `check_DC` に依存する。`src/` の tree を束縛すると、DC と無関係な
`src/` の変更でも登録が無効になり、運用上重すぎる。**推奨は、束縛はプラグインの tree に限り、
`src/` の tree OID は run 開始レコードに記録するだけにする**こと。事後監査はでき、登録は壊れない。

## 4. 項目2 — 判定結果の形式を登録する

### 4.1 どちらのファイルに置くか

RSB-001 §3 の境界は「profile = 何を出力するか、解析計画 = それをどう読むか」だった。
判定結果は出力ではあるが、その欄の集合は判定基準の定義と切り離せない。DC の値が
`hSelf`・`hSMC`・`hAct`・`hBound` であることは DC を選んだことから決まる。

**推奨は解析計画側に置く**こと。§3.1 の `criterion_binding` の中に `value_keys` と
`diagnostic_keys` を持たせ、判定基準と結果の形式を一か所で束縛する。profile 側に置くと
profile schema v3 と profile の再凍結が必要になり、基体の同一性と無関係な理由で基体の digest が動く。

この判断は §3 の境界の読み替えなので、**§3 に「判定基準に固有の結果の欄は解析計画側」と一文足す**。

### 4.2 検査

`criterion_result` が返す `values` のキー集合が `value_keys` と、`diagnostics` のキー集合が
`diagnostic_keys` と**完全一致**しなければ、その case の記録を拒否し run を失敗させる。
全 `values` は真偽値。判定結果の記録形式 `rsb-criterion-result-v1` を定め、解析計画に名前で書く。

### 4.3 DC の欄（確定できるもの）

```
value_keys      = ["dc", "hSelf", "hSMC", "hAct", "hBound"]
diagnostic_keys = ["act", "boundary", "kappa_nonempty", "epsilon_nonempty",
                   "mask_self", "mask_smc", "mask_act"]
```

`mask_*` は項目3 の冗長性の診断。DC2 の欄は RSB-003 で DC2 を実装した時点で確定する。

## 5. 項目3 — 冗長性による偽の読み方

### 5.1 何が起きるか

DC の入力 π・ρ・α・σ はすべて単独停止から作られる（RSB-GEN-001 §15）。ある構成素を二つの経路が
支えていれば、片方だけ止めても何も失われないので、その構成素は「どの運動にも支えられていない」と
読まれる。DC は偽になりうるが、**それは系が自己維持していないことを意味しない**。

### 5.2 診断（DC の判定基準が case 記録から計算する）

case 記録にはすでに全停止集合の `future_final` と `collective_only_loss` がある。そこから次を作る。

- `collective_only_change` — 最終状態が、どの単独停止でも変わらず、ある複数停止でのみ変わるユニット。
  `future_final` から計算できる（記録形式の変更は不要）。

条件ごとに、その条件を偽にしうる隠れ方を割り当てる。

| 条件 | 隠れる経路 | 診断 |
|---|---|---|
| `hSelf` | π（構成素の喪失）、ρ（運動の喪失） | `mask_self = (collective_only_loss ∩ κ) ∪ (collective_only_loss ∩ M)` |
| `hSMC` | α（入力の変化）、σ（出力の変化） | `mask_smc = collective_only_change ∩ (E ∪ M)` |
| `hAct` | ρ、σ | `mask_act = (collective_only_loss ∩ M) ∪ (collective_only_change ∩ M)` |
| `hBound` | 隠れない（構造から決まる） | なし |

### 5.3 事前登録する読み方

各 case を3つに分類する。

- **pass** — DC が真。
- **fail_redundancy_ambiguous** — DC が偽、`hBound` は真、かつ**偽になった条件すべてについて**
  対応する診断が空でない。「冗長性のせいかもしれない」偽。
- **fail** — それ以外の DC が偽の case。

この診断は「隠れているかもしれない」の**過大評価**であり、「隠れている」ことの証明ではない。

読み方の規則。

1. **主たる集計は DC の定義どおり**とし、ambiguous は fail に含める。DC の意味を事後に変えない。
2. 感度分析として、ambiguous を除いた集計も必ず並べて報告する。
3. DISCRIMINATION（全件通過または0件通過で基体を棄却）は主たる集計で判定する。
4. **DC が偽の case のうち ambiguous の割合が閾値 X 以上**なら、「この基体では単独停止に基づく DC の
   読みは情報を持たない」と報告し、DC の賛否いずれの証拠にもしない。X は §11 のユーザー確認事項。

## 6. 項目4 — 再実行の方針

- **試行は最大2回。** 2回目は1回目の完了 manifest が `complete` でないときに限る。
- **1回目の出力は削除しない。** 途中までの case 記録と判定結果は、その SHA-256 の一覧を記録して封じ、
  2回目が完了するまで開かない。
- **2回目は1回目と重なる case について完全一致しなければならない。** 測定は決定的なので、
  一致しなければ実装か環境の誤りとして run を撤回する。これは再実行を整合性の検査に変える。
- 2回目も `complete` でなければ、その登録は**使い切り**とし、解析しない。
- 試行番号は `run_id` に含め、run 開始レコードに記録する。

## 6b. 項目5 — 解析計画 v1 の論理の誤りの訂正（2026-09-30 の Lean 点検による）

### 誤り1: 「DC2 ならば DC」の撤回条件が、証明された含意と別の DC を使っている

v1 の撤回条件は「DC2 が真で DC が偽の case があれば、DC2 の記録すべてを実装誤りとして撤回する
（DC2 implies DC）」である。しかし `DC2.toDC`（`formal-experiments/M1Refinement.lean`）が証明するのは、
**境界を `beta`（蝶番の行為が産出する κ 内の構成素）とした DC** への含意である。

一方、run で評価する DC の境界は基体 profile の `boundary_rule = "outgoing_nonzero_edges"`、つまり
**グラフの外向き辺による境界**である。DC2 の定義はグラフの隣接を一切参照しないので、DC2 からグラフの
境界について何かを導くことは型の上でできない。

具体例: κ が全ユニットのとき、κ の外にユニットが無いのでグラフの境界は空になり `hBound` は偽になる。
他方、κ を全体集合 `Set.univ` とする DC2 は証明済みの参照模型として存在する（`M1.dc2`）。
したがって**正しい実装でも「DC2 が真で DC が偽」は起こりうる**。v1 の条件のままだと、正しい DC2 の
記録を実装誤りとして撤回してしまう。

**訂正**: `DC2.toDC` の証明から実際に従うものだけを検査する。

- DC2 が真なら `hSelf`・`hSMC`・`hAct` は真。偽があれば実装誤りとして撤回する。
- DC2 が真なら `beta` は空でない（`DC2.beta_nonempty`）。空なら実装誤りとして撤回する。
- **グラフ境界による `hBound` と `beta` による `hBound` は別の概念**として両方を記録し、
  一致・不一致を DC2 批准のための資料として報告する。不一致を誤りとは扱わない。

### 誤り2: ALL-OFF の期待値が定義と矛盾している

v1 の反証行は、全ユニット off の case で「DC false (hSelf and hBound false)」を期待している。
しかし κ = ∅ なら `hSelf : κ ⊆ Φ(κ)` は空集合の包含として**真**であり、ε = ∅ なら `hSMC` も真。
偽になるのは `hAct`（`DC.empty_propagation_left` により行為集合が空）と `hBound` である。

この誤りは 2026-09-08 の設計レビューで一度指摘され訂正された内容と同じであり、2026-09-27 に
凍結された解析計画 v1 に**再び入り込んだ**。

**訂正**: 期待値を「DC false（hAct と hBound が偽。hSelf と hSMC は空の核について空虚に真）;
DC2 false（空でない既約単位が存在しない）」とする。

**再発防止**: 反証行の期待値を `expected_components` として構造化し、定義に照らして機械的に照合する。
文章として書かれた期待値が定義とずれたら、その試験が落ちるようにする。

**2026-09-30 実施済み**:
- 訂正を反映した草案 `specs/drafts/reactivation-analysis-plan-v2.toml`（未登録。DC・DC2 の実装の同一性など
  RSB-003 を待つ欄は `PENDING-RSB-003`）。
- 照合試験 `test/test_analysis_plan_expectations.jl`。DC の値で決まる期待値は、200 通りの関係の選び方の
  それぞれで定義と照合する。DC2・`beta`・冗長性の分類が要る期待値は、行と欄を明示した保留一覧に載せ、
  RSB-003 まで保留する。保留一覧にも手続き的な行の一覧にも無い行があれば試験が落ちる。
- 変異テスト4件（ALL-OFF を v1 の誤りに戻す、ISOLATED の期待を逆にする、期待値を黙って消す、
  v1 の撤回条件を戻す）がすべて検出された。

## 6c. DC2 の有限モデル監査（2026-09-30 実施）と、未決の研究判断

誤り1は、DC2 が有限モデル監査に入っていなかったために事前に捕まらなかった。そこで DC2 を監査へ入れた
（証拠: `logs/gates/DC2-AUDIT-20260930/`）。

- Julia の DC2 判定 `tools/model_audit/DC2.jl` は、Lean の参照模型 M1〜M5 について証明済みの事実 14 件と
  すべて一致し、抽象担体 C3・M2・E1 の全符号化 1,048,576 通りで直接の量化式と一致した。
- DC2 が真の 912 通りすべてで、境界を `beta` とした DC が成り立った（`DC2.toDC` の有限版）。
- 含意行列では `dc2 → hSelf / hSMC / hAct / beta_nonempty` に有限反例が無く、`dc2 → hBound`
  （グラフ境界）には有限反例がある（Lean 参照模型 M1・M5、抽象担体の κ が全体の符号化）。誤り1の訂正と整合する。
- DC2 の4条件の全条件と単独脱落の5型は、抽象担体 C4・M2・E1 の標本で非退化な証人がそろった。

**未決の研究判断（ユーザー決定待ち）**: 測定した回路では `hUnit` が一度も真にならなかった
（4ユニット全列挙 32,768 回路、6ユニット系列 20,000 回路）。空でない κ が PostFixed2 になる回路
（2,611 と 734）のすべてで、κ の中に**単独で** PostFixed2 になる構成素があり、非単元の既約単位が生じない。
このままでは RSB-003 の本番 run で DC2 は全 case 偽と記録され、DC2 の記録は判別に使えない可能性が高い。
これは損失型の π・ρ の読み方と DC2 の `NonSingleton` 条項の組み合わせの問題であり、どちらを動かすかは
DC2 の批准判断に属する。仕組みの推定は証拠に支えられているが、証明されてはいない。

**同日のユーザー決定**: NonSingleton 側を見直し、hUnit を相互産出の対（N3, `MutualPair`）に置き換えた。
決定・撤回条件・実装結果は `specs/packets/DC2-HUNIT-N3.md`。N3 のもとで測定回路でも DC2 が実現する
（4ユニット全列挙で非退化 656、6ユニット系列で 111）。

## 7. 解析計画 v2 の骨子

```toml
analysis_schema_version = 2
profile_id = "reactivation-substrate-v1"
analysis_plan_id = "reactivation-analysis-plan-v2"
supersedes_analysis_plan = "reactivation-analysis-plan-v1"

[interpretation]              # v1 の各キーを引き継ぐ
primary_criterion = "dc"
recorded_criteria = ["dc", "dc2"]
criterion_result_format = "rsb-criterion-result-v1"
# ...

[redundancy]                  # 項目3
classification = ["pass", "fail_redundancy_ambiguous", "fail"]
primary_tally = "dc_as_defined_ambiguous_counted_as_fail"
sensitivity_tally = "ambiguous_excluded"
uninformative_threshold = <X>

[incomplete_runs]             # v1 の2キー + 項目4
missing_case = "run_incomplete_not_analyzed"
duplicate_case = "run_invalid_not_analyzed"
max_attempts = 2
retry_condition = "previous_attempt_not_complete"
partial_outputs = "sealed_by_sha256_not_opened_until_retry_completes"
overlap_rule = "retry_must_equal_first_attempt_on_overlapping_cases"
after_last_attempt = "registration_spent_not_analyzed"

[decisions]                   # v1 の各行 + 追加
# 追加する撤回条件:
#   "retry output differs from the first attempt on an overlapping case -> retract the run"
#   "a criterion result lacks or adds a registered key -> retract the run"

[[criterion_binding]]         # 項目1・2、判定基準ごとに1行
# ...

[[falsification]]             # v1 の7件 + §9 の追加分
```

## 8. SubstrateRegistry の変更

- 解析計画 schema **v2** を追加する（`rsb-analysis-schema-v2`）。v1 は残す。
- 登録行と run 開始レコードの `analysis_schema_validation_version` に v2 を許す。
- v2 の登録を検証するとき、§3.2 の検査（`criterion_binding` の tree の一致と不変）を行う。
- `primary_criterion` は v2 でも `"dc"` に固定のままとする。ERIE-C 以外の判定基準を主判定にする
  登録は本 packet の範囲外。

## 9. エンジンの変更

- `start_run` は v2 の解析計画について §3.3 の4検査と §4.2 の欄の完全一致を行う。
- v1 の解析計画については名前だけの束縛（現行）のままとする。**v1 の登録 rsb-002 は §2(5) で
  取り下げられるので、以後 v1 の本番登録は存在しない。** v1 の経路は scratch 試験だけに残る。
- 試行の管理（§6）を `start_run` に加える。試行番号、1回目の出力の封印、重なる case の一致検査。

## 10. 反証条件（解析計画 v2 に追加するもの）

| ID | 内容 | 期待 |
|---|---|---|
| `FALSIFICATION-PLAN-STAND-IN` | 登録パッケージの外で定義された同名の判定基準を渡す | `start_run` が拒否 |
| `FALSIFICATION-PLAN-TREE-DRIFT` | 判定基準パッケージの1ファイルを変更 | tree OID が変わり拒否 |
| `FALSIFICATION-PLAN-FOREIGN-LOAD` | 同名パッケージを checkout の外から読み込む | `pkgdir` の検査が拒否 |
| `FALSIFICATION-PLAN-RESULT-KEYS` | 判定結果に欄を1つ足す、または欠く | 記録を拒否し run 失敗 |
| `FALSIFICATION-PLAN-REDUNDANCY` | 冗長に支えられた構成素を持つ fixture | DC 偽かつ ambiguous に分類される |
| `FALSIFICATION-PLAN-UNMASKED` | `hBound` が偽の fixture | ambiguous ではなく fail |
| `FALSIFICATION-PLAN-RETRY-MISMATCH` | 2回目の重なる case を1バイト変える | run を撤回 |
| `FALSIFICATION-PLAN-THIRD-ATTEMPT` | 3回目の試行 | `start_run` が拒否 |
| `FALSIFICATION-PLAN-DC2-GRAPH-BOUNDARY` | κ が全ユニットで DC2 が真になる fixture | DC2 の記録は撤回されず、グラフ境界の `hBound` 偽と `beta` の非空が並んで記録される |
| `FALSIFICATION-PLAN-EXPECTED-VALUES` | 反証行の期待値を1つ定義と食い違わせる | 期待値の機械的照合が落ちる |

`REDUNDANCY` の fixture は RSB-GEN-001 の `redundant_edges`（ユニット5が2つ同時停止でのみ失われる）を
土台にする。

## 11. ユーザー確認事項（推奨値つき）

設計はこの推奨値で完結している。変える場合だけ指示してほしい。

| 事項 | 推奨 | 理由 |
|---|---|---|
| X: ambiguous の割合の閾値 | **0.5** | DC が偽の case の半数以上が冗長性で説明しうるなら、DC の偽は主として読みの限界を表していると見る |
| `src/` の tree を束縛するか | **しない**（記録のみ） | §3.5 |
| 結果の形式をどちらに置くか | **解析計画側** | §4.1 |
| 試行の上限 | **2回** | §6 |

X は研究判断であり、**結果を見た後では決められない**。一括再登録の前に確定させる必要がある。

## 12. 禁止変更

`phenomenal_claim` を `:not_certified` から動かさない。`specs/ledger.toml`・`formal/` を変更しない。
登録済みの profile ファイル `specs/reactivation-substrate-v1-r2.toml` と解析計画 v1 を書き換えない
（v2 は別ファイル）。**§2(5) より前に登録済み profile で run しない。**
候補の数値を通過率を見て調整しない。κ に選好を入れない。C = ユニットを変えない。

## 13. ゲート

本 packet は設計のみでゲートを持たない。§2(2) の実装、§2(3) の RSB-003、§2(5)(6) の再登録は、
それぞれ別の作業単位としてゲートを定める。
