# 再活性化基体プロファイル v1 — 凍結項目一覧（草案）

状態: 旧草案（2026-09-09、設計を Codex に移管）。後継は
`reactivation-substrate-v1-design.md` と `reactivation-substrate-v1-candidate.toml`。
本文は検討履歴として保存する。後継案も未凍結であり、本稿の旧期待値・未決案を実装契約に使わない。
作成: 2026-09-08。ユーザー決定（同日）: (1) 構成素 C = ユニット、(2) M→E の環境写像を
基体に含める、(3) κ は persistence のみで選好禁止。この三点は本草案の前提であり、
レビューの対象ではない。

この文書は `specs/sensory-carrier-profile-v1.toml` と同じ役割を、Lenia ではなく
有限有向グラフ上の離散再活性化過程に対して果たす TOML の項目一覧である。
目的は「基体を先に凍結し、その後で DC を問う」順序を機械的に保証すること。
DC が通るまで基体を調整する経路を塞ぐ。

命名について: 「神経」「ニューロン」は使わない。作るものは有限有向グラフ上の
再活性化過程であり、主張の見え方だけを変えないための措置。

---

## 0. この草案が答えること・答えないこと

答えること: 何を凍結し、digest が何を覆い、κ/ε/境界/測定プロトコルを何という名前の
規則として固定するか。

答えないこと: DC が通るかどうか。関係 α/σ/π/ρ の値。これらは測定の出力であり、
プロファイルには入れない（§6 参照）。

---

## 1. 識別 `[profile]`

| 項目 | 値（案） | 備考 |
|---|---|---|
| `schema_version` | 1 | |
| `profile_id` | `"reactivation-substrate-v1"` | |
| `digest_algorithm` | `"sha256"` | 正規化直列化（キーをソートした TOML.print 出力）に対して計算 |
| `digest_scope` | §2〜§7 の全項目 | §8 以降（反証・禁止・未決）は digest 対象外。理由: 反証条件の追加が基体の同一性を変えてはならない |

---

## 2. 基体 `[substrate]`

| 項目 | 値（案） | 備考 |
|---|---|---|
| `unit_count` | N（整数、v1 は 8〜16 を想定） | 構成素 C の台。全列挙可能な大きさに留める |
| `units` | `["u0", ..., "u{N-1}"]` | C の要素名。文字列で固定 |
| `input_units` | I ⊂ units | E の台。感覚側 |
| `output_units` | O ⊂ units | M の台。運動側 |
| `internal_units` | units \ (I ∪ O) | 空でもよい |
| `weights` | 整数の疎行列 W: (from, to, w) の配列 | **整数に限定**。浮動小数点を排し、更新を厳密にする。tol を certificate 仮定に持ち込まない |
| `thresholds` | 整数配列 θ（unit ごと） | 同上 |
| `update_rule` | `"synchronous_threshold"` | u_{t+1}(i) = [Σ_j W(j,i)·u_t(j) ≥ θ(i)]。同期更新。**未決 A 参照** |
| `environment_map` | 整数の疎行列 W_env: (o ∈ O, i ∈ I, w) | **出力が入力へ戻る経路**。これが無いと hSMC が退化する（Hinge.T_prime = α⋆∘σ⋆）。W とは別の関係として凍結 |
| `exogenous_drive` | `"none"` | v1 は閉世界。入力は W_env 経由のみ。**未決 B 参照** |
| `state_window` | k+1 | 型 S = 長さ k+1 の配置列。κ が「持続」を評価するために履歴が要る |

入力ユニットと出力ユニットの重なりは v1 では禁止（`require_disjoint_io = true`）。
理由: 同一ユニットが M と E の両方に属すると α と σ の測定が分離できない。

---

## 3. κ の規則 `[kappa]`

| 項目 | 値（案） | 備考 |
|---|---|---|
| `rule` | `"persistent_active"` | κ(s) = 窓 s の全ステップで on のユニット集合 |
| `window` | k（整数、v1 は 3 を想定） | `state_window` と整合させる |
| `persistence_only` | `true` | **M1 不変条項**。κ に選好・最大化・スコアを入れない。この項目は将来も `false` にできない（禁止事項 §9） |
| `carrier` | `"units"` | κ(s) ⊆ C。型級の約束（C = ユニット）をここで明示 |

再設計の自由度: `window` の変更はパラメータ級（プロファイル版上げのみ）。`rule` の変更は
規則級（認証が落ちる。再監査）。`carrier` の変更は型級（別 VP 系列）。

---

## 4. ε の規則 `[epsilon]`

| 項目 | 値（案） | 備考 |
|---|---|---|
| `rule` | `"received_inputs_last_step"` | ε(s) = 窓の最終ステップで on の入力ユニット集合 |
| `carrier` | `"input_units"` | ε(s) ⊆ E |

代案 `"received_inputs_window"`（窓の全ステップで on）と `"available_inputs"`（W_env 経由で
到達しうる入力）は v2 以降の予約名。**未決 C 参照**。

---

## 5. 境界 `[boundary]`

| 項目 | 値（案） | 備考 |
|---|---|---|
| `lean_decl` | `"ERIEC.FieldBridge.PeriodicBoundaryWitness"` | **無変更で再利用**。宣言は `neighbors : Cell → Set Cell` にパラメトリック（VP-BDY-003 パケット明記） |
| `neighbors` | `"graph_adjacency_undirected"` | neighbors(c) = {c' : W(c,c') ≠ 0 ∨ W(c',c) ≠ 0}。**未決 D 参照** |
| `support` | `"kappa"` | support = κ(s) |
| `name_note` | 固定文字列 | 「Periodic」は Lenia 由来の名で、グラフ隣接では意味を持たない。**Lean 側の改名は禁止**（証明済みファイル）。Julia 側で別名を与えることは可 |

境界 = κ(s) に属し、κ(s) の外へ隣接を持つユニット。`hBound : (κ s ∩ boundary).Nonempty` は
「核のどこかが外に接している」を要求する。孤立集合体（外へ辺なし）はここで落ちる。

---

## 6. 測定プロトコル `[measurement]`

**原則: 関係 α/σ/π/ρ は測定の出力であり、W や W_env から読み取らない。**
プロファイルが凍結するのはプロトコルであって関係ではない。関係は certificate に入る。

| 項目 | 値（案） | 備考 |
|---|---|---|
| `alpha_protocol` | `"output_intervention"` | 出力ユニット m を強制 on/off し、変化する入力ユニットの集合を α(m) とする。VP-BDY-002 の paired_intervention と同型 |
| `sigma_protocol` | `"input_clamp"` | 入力ユニット e をクランプし、変化する出力ユニットの集合を σ(e) とする。VP-BDY-002 の clamp と同型 |
| `rho_protocol` | `"lesion_constituent"` | 構成素 c を窓の間 off に固定して再実行し、持続活性から脱落する出力ユニットの集合を ρ(c) とする |
| `pi_protocol` | `"lesion_motor"` | 出力ユニット m を off に固定して再実行し、持続活性から脱落する構成素の集合を π(m) とする |
| `lesion_horizon_steps` | 整数（v1 は 2k を想定） | 再実行の長さ |
| `intervention_horizon_steps` | 整数 | α/σ 測定の再実行長 |
| `require_distinct_provenance` | `true` | α と σ、π と ρ の試行が同一ハッシュを共有しない（VP-BDY-002 の `require_distinct_hashes` 相当） |

**未決 E**: π と ρ の lesion 定義の向きが正しいかは codex のレビュー対象。DC.lean では
π : M → Set C（運動が生む構成素）、ρ : C → Set M（構成素が可能にする運動）。

---

## 7. 初期配置の列挙 `[enumeration]`

| 項目 | 値（案） | 備考 |
|---|---|---|
| `policy` | `"exhaustive"` または `"seeded_sample"` | N ≤ 12 なら全 2^N 配置を列挙。超えるなら seed 固定の標本 |
| `seed` | 整数 | `seeded_sample` のとき必須。digest に含める |
| `sample_count` | 整数 | 同上 |

**この節が digest に入る理由**: 初期配置 s_0 を凍結しないと「DC が通る s_0 を探す」経路が
残る。個々の s_0 ではなく列挙方針を凍結することで、通る配置と落ちる配置の両方が
出ることを要求できる。

---

## 8. v1 で必須の反証条件（digest 対象外）

| ID | 内容 | 落ちるべき条件 |
|---|---|---|
| `FALSIFICATION-RSB-ALL-OFF` | 全ユニット off の配置 | hSelf, hBound が false |
| `FALSIFICATION-RSB-DISCRIMINATION` | §7 の列挙で得た配置群 | **全部通る、または全部落ちる → 基体ごと棄却**。判別力の要求 |
| `FALSIFICATION-RSB-PROVENANCE` | W / W_env から直接読んだ関係を渡す | provenance 検査で拒否 |
| `FALSIFICATION-RSB-ISOLATED` | 外へ辺を持たない集合体 | hBound が false |
| `FALSIFICATION-RSB-PROFILE-DIGEST` | digest 不一致 | 拒否（VP-BDY-003 の PROFILE-DIGEST と同型） |
| `FALSIFICATION-RSB-DECOUPLING` | `kappa.window` のみ変更 | プロファイル以外（check_DC、測定コード）に変更が不要であること。**不要でなければ κ/ε の切り出しが誤り** |

---

## 9. 禁止事項（不変条項由来。digest 対象外だが VP パケットの「禁止変更」に転記する）

- `phenomenal_claim` は全 certificate で `:not_certified`。昇格させる編集は拒否。
- 測定した関係を W・W_env・θ へ書き戻さない（Σ-purity の対象層版）。
- `kappa.persistence_only = false` を許さない。κ に選好を入れない（M1）。
- `ERIEC.FieldBridge.PeriodicBoundaryWitness` を改名・改変しない。
- `ViableSystem.viable` と `DC` を同一視しない。DC 通過を「viable」と呼ばない。
- 対象層に新しい公理・対象を足さない。基体は測定対象であって公理ではない。
- 既存の certified API（`check_DC`、`ERIEState`）の signature を変えない。

---

## 10. 未決事項（ユーザー決定。codex は各項に推奨と根拠を付ける）

| ID | 論点 | 素直案 | 代案 |
|---|---|---|---|
| A | 更新方式 | 同期 | 非同期（順序を凍結する必要が生じる） |
| B | 外生入力 | 閉世界（W_env のみ） | 固定パターンの外生駆動（E1 的。set point ではない） |
| C | ε の読み | 最終ステップの受信入力 | 窓全体の受信入力 / 到達可能入力 |
| D | 境界の隣接 | 無向（in ∪ out） | out のみ / in のみ |
| E | π/ρ の lesion 向き | §6 の定義 | 逆向き、または π を「m が on のとき on になる構成素」で定義 |
| F | 重みの型 | 整数 | 有理数（厳密性は保てるが実装が重い） |

---

## 11. VP の切り方（提案。番号と系列名は未確定）

| VP | 内容 | 層 | ERIEState |
|---|---|---|---|
| RSB-001 | プロファイル v1 の凍結。digest 生成と検証のみ。**DC は評価しない** | 仕様 | 作らない |
| RSB-002 | 凍結基体上で α/σ/π/ρ を §6 のプロトコルで測定し certificate 化 | 観測 | 作らない |
| RSB-003 | 測定した関係から ERIEState を構成し check_DC を走らせる。§8 の反証を通す | **対象層** | **初めて作る** |

RSB-003 で初めて、VP-BDY 系列が毎回書いてきた「does not construct an ERIEState」の
宣言を降ろす。

---

## 12. 再利用できる既存資産

- `ERIEC.FieldBridge.PeriodicBoundaryWitness` と `boundary_subset_support`（無変更）
- `src/dc.jl` の `ERIEState` と `check_DC(sys, all_M, all_E, all_C)`（無変更）
- VP-BDY-002 の provenance 構造（`AlphaTrialProvenance` / `ClampSigmaTrialProvenance` の型）
- VP-BDY-003 の `FALSIFICATION-*-PROFILE-DIGEST` パターン
- `specs/sensory-carrier-profile-v1.toml` の節構成

再利用できないもの: `src/field_bridge.jl` の Lenia 依存部分（障害物場、68チャネル特徴、
周期格子の具体化）。`src/trm_experiments.jl`（ML 訓練実装であり別物）。
