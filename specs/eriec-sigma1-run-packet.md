# Σ1 実走作業パケット（改訂C・codex 向け）

作成 2026-07-20（codex の設計依頼への回答）。**本パケットは準備作業の契約であり、
`execute=true` での実走はユーザー承認が出るまで禁止**（下記 §7 の承認ラッチ参照）。
`specs/eriec-sigma1-experiment-spec.md` の固定値・契約は一切変更しない。

## 0. 変更可能ファイル（これ以外を触らない）

- **新規** `src/sigma1_run.jl` — 本パケットの全関数。certified 済み `src/sigma_selection.jl` は不変更。
- `src/ERIEC.jl` — include と export の追記のみ。
- **新規** `test/test_sigma1_run.jl` — dry-run テストのみ（CI で `execute=true` を呼ばない）。

固定名（export）: `sigma1_reference_individual`, `sigma1_random_individual`,
`sigma1_initial_population`, `sigma1_mutate`, `sigma1_observe_candidate`,
`sigma1_observe_trace`, `sigma1_execute_replicate`, `sigma1_run_all`。

## 1. 初期 64 個体（v3 — 抽象実走契約。具象化は新規 adapter VP へ分離）

**v1 の全関係族（縮退のため撤回）、v2 の帯構造 builder と新規 seed Xoshiro(20260719)
（承認済み spec にない固定値の追加 = certificate 仮定違反のため撤回）は本版で除去した。**
codex challenge（2026-07-20、指摘 1〜4）を accept した結果、本節は**抽象契約のみ**を保持する。

- **母集団契約（不変・spec 由来）**: 64 = 参照族 16（sizes (2,3,8,32) × 各 4 変分）+
  admissible ランダム 48。B/G/格子/replicate seed 系列 Xoshiro(20260720+k) も spec のまま。
- **個体の抽象契約**: 個体 = **DC 認証ユニット + read-only observation adapter**。
  具体 carrier（ERIEState か wrapper か）、参照族 constructor、個体 → ObservationArtifact
  写像、carrier → QDCandidate adapter は本パケットで固定しない。
  **新規 adapter VP として分離・起票する**（起票はユーザー承認後。可視ギャップとして明示）。
- **adapter VP が払うべき証明義務（本パケットからの引継ぎ契約）**:
  1. admission: 全個体が `is_DC` ∧ 蝶番非空 ∧ M4-safe（参照族は構築時 hard error、
     ランダム個体はリサンプル上限 1000）。
  2. 参照族の非縮退証人: 16 個体が初期 QD 格子上で複数セルを占有すること
     （占有下限値、および k=2 のように変分自由度が小さいサイズでの充足可能性は、
     adapter VP の statement 段階で構成とともに提示する — v2 の「8 セル・pairwise 相異」
     hard assert は k=2 での充足可能性未提示のため契約から降格し、証明義務に移す）。
  3. サイズ違い個体間の diversity 意味論: **二段 adapter**（有限最大 M_f を先に計算し
     Inf を M_f へ置換 —「初期集団内で最遠」の意味論。certified の
     `diversity_upper = 1.5 × maximum` 規則は不変更）。VP-META-004 statement 参照。
- **初期集団の生成方式（ユーザー決定 2026-07-20: 案B）**: 各 replicate が自身の
  `Xoshiro(20260720+k)` から初期集団（ランダム 48 個体）も生成する。承認済み seed 系列から
  全乱数が導出され、新規固定値は追加しない。初期条件の分散が統計に含まれる
  （帰無系との比較は同一 replicate 内で同一初期集団を共有するため検定の妥当性は保たれる）。
  参照族 16 個体は決定的構成（乱数不使用）なので全 replicate で自然に同一。

## 2. callback ↔ 既存 API の対応

- `sigma1_observe_candidate(ind) :: QDCandidate`（read-only）:
  - `dc = check_DC(ind)`（[dc.jl:96](../src/dc.jl#L96)）
  - `quality = Float64(length(dc.act))`（蝶番濃度 |Act|）
  - `depth` = `actuated_world` の basis 列数（既定 tol 変更禁止）
  - `diversity` = `umwelt_relative_diff(artifact(i_ref), artifact(ind)).projection_norm_diff`
    （[observation_artifact.jl:322](../src/observation_artifact.jl#L322)）。
    個体→`ObservationArtifact` の最小構成（fingerprint = 関係のハッシュ、
    timeseries = actuated_world basis の単一スナップショット）は G0 で凍結。
    `Inf` は最上位ビンへ clamp。
  - `dc_ok = is_DC(dc)`、`hinge_nonempty = !isempty(dc.act)`
  - `m4_safe` = `check_terminal_guard(cores, reach)`（[guard.jl 系](../src/guard.jl)）。
    reach は π∘ρ 合成から導出（c から c' へ: ∃m ∈ ρ(c), c' ∈ π(m)）。正確な導出は
    G0 で凍結（制約: 全結合 reach に終対象 sink が無いこと）。
- `sigma1_mutate(ind, rng) :: ERIEState`: α または σ を一様に選び、関係辺の
  追加/削除/付替のいずれか1つ（一様）。**admission はここで検査しない** —
  `qd_selection_step` の `_qd_admissible` が棄却しカウントする（R4 の入力）。
  非破壊（新 ERIEState を返す。アーカイブ内個体の in-place 変更禁止）。
- `sigma1_observe_trace(ind) :: String`: 決定的直列化
  `repr((sort∘collect)(κ(s)), (sort∘collect)(ε(s)), is_DC, (sort∘collect)(act), depth)`。
  purity 動的検問のハッシュ対象。

## 3. 実行順と資源見積り

- replicate k = 0..9 を**逐次**実行（並列禁止 — RNG 決定性の保全）。
  各 `sigma1_execute_replicate(k)` は `run_sigma1_experiment(; replicate=k, execute=true, …)`
  を1回呼ぶ（選択系と帰無系は関数内部で両方実行される）。
- 評価回数: 1 replicate あたり (64 + 200×16) × 2 系 ≈ 6,530 評価。全体で ≈ 65,300 評価。
  個体は k ≤ 32 の有限集合演算なので 1 評価 ≪ 10ms。**全体で 30 分未満・単一プロセス・
  追加メモリ無視可**の見積り。超えたら異常として停止・報告。

## 4. 出力の保存形式（監査可能な平文）

出力先 `logs/sigma1/run-20260720/`:

- `rep<k>.toml` — plan エコー、purity 結果（動的 10 ペアのハッシュ対）、
  世代別 coverage 配列、最終アーカイブ（セルごとに bin・depth・diversity・quality）、
  rejection_rate、depth_max、diversity_median（選択系・帰無系の両方）。
- `trace_hashes_rep<k>.txt` — purity 検問の全ハッシュ（bit 同一の証跡）。
- `summary.toml` — 10 replicates の depth_max / diversity_median ベクトル、
  `check_selection_nondegenerate` の出力（U 検定 p 値・Cliff's delta・成分別判定）、
  R1〜R4 の最終判定、生成時刻、git commit hash。

## 5. R1〜R4 の判定と即時停止

- **R1（最優先・即時停止）**: いずれかの replicate で purity 検問失敗
  （`run_sigma1_experiment` が `valid=false, reason=:R1` を返す）→ 以降の replicate を
  実行せず全体を invalid とし、`summary.toml` の代わりに `invalid.toml` を出力して停止。
- **R4（早期打切り）**: 完了済み replicate のうち 5 本以上で rejection_rate > 0.90 →
  残りを実行せず停止（変異 kernel 再設計へ差し戻し）。
- **R2 / R3**: 10 replicates 完走後の `summary.toml` でのみ判定
  （α' = 0.025 ∧ Cliff's delta ≥ 0.474 の両充足規準は spec どおり）。
- 判定結果がどうであれ、**E1 再判断・Φ_rich 合成の確定はユーザー専権**（改訂D）。
  summary はデータ提示のみとし、推奨判断を書かない。

## 6. 不変条項ガード（実走時）

- Σ-purity: `src/sigma1_run.jl` を静的検問（`_sigma_static_purity`）の走査対象に追加。
  callback は全て read-only / 非破壊（§2 の対応のみ呼ぶ。個体 sink への書込関数を呼ばない）。
- 灯り: `phenomenal_claim` フィールドにいかなる形でも触れない。
- E1 不採用のまま: 個体に環境動態を持たせない（静的関係構造のみ）。
- tol / seed: `actuated_world`・`umwelt_relative_diff` の既定 tol 変更禁止。
  seed は §1・§3 の固定値のみ。ad hoc な seed 追加禁止。

## 7. 承認ラッチ（実走のブロック）

- `sigma1_run_all()` は先頭で `ENV["ERIEC_SIGMA1_APPROVED"] == "true"` を検査し、
  不成立なら即座に error（"Σ1 実走はユーザー承認待ち"）。CI・テストではこの環境変数を
  設定しない。**ユーザー承認が agmsg で伝達されるまで、codex はこの環境変数を設定して
  実行してはならない。**
- `test/test_sigma1_run.jl` は dry-run（`execute=false` の plan 検証、生成元の決定性、
  callback の型と read-only 性、ラッチの error）のみをテストする。
