# ERIE-C Σ1 実験仕様（改訂B → C 実走契約）

起票 2026-07-20（ユーザー実装指示済み）。改訂順 A→B→C→D→E（2026-07-14 合意）の B。
メタ層の外部選択公理 Σ1 を初めて実走させるための実験仕様。本仕様の6項目が実装契約であり、
codex はこれを G0 で凍結して実装する（C = 実走はこの仕様に従う）。

## 前提となる不変条項（実験全体を拘束）

- **Σ1 はメタ層のみ**: 選択子 𝒮 は集団 registry の上で作用し、個体の対象理論（M1〜M4）に不可視。
- **Σ-purity**: 𝒮 の値・状態は個体 sink（νΦ / V / 求めの図式 D / action trace）へ write-back しない。
  σ 越しの read-only 観測のみ可。
- **灯り**: 選択で豊穣化した zoo の各個体も `phenomenal_claim = :not_certified`。不接触。
- **E1 不採用のまま**（2026-07-08 ユーザー決定）: 環境は定常。本実験は E1 に依存しない設計とし、
  結果を受けた E1 再判断（改訂D）はユーザー専権・自動昇格なし。
- **tol・seed は certificate 仮定**: `actuated_world` の既定 tol を変更しない。seed は本仕様で固定。

## Lean 側アンカー（証明済み・G1 は既存宣言の照合）

- `ERIEC.MetaSelection.SigmaPure`（[MetaSelection.lean:96](../formal/ERIEC/MetaSelection.lean#L96)）:
  観測的非干渉 ∀ s₁ s₂ i, observe s₁ i = observe s₂ i。
- `ERIEC.MetaSelection.trace_preserved_of_sigmaPure`（同 131）/ `m4_preserved_of_sigmaPure`（同 152）:
  Σ-purity ⇒ 個体トレース保存 ⇒ M4 保存（一方向・入力 M4 前提付き）。
- `ERIEC.MetaSelection.M4SafeMutation`（同 121）: 変異の M4 安全性。

Julia 実装はこれらの checker 契約に束縛される（Lean が payload checker 契約を検証し、
実数計算・データ取得は Julia shell の trust boundary — 既存分界どおり）。

---

## 項目1: 選択 kernel 𝒮 の具体化（MAP-Elites 型 QD 選択）

- **アーカイブ格子**: 2軸 8×8。
  - 軸1（diversity）: 固定参照個体 i_ref（項目2の系列最小個体）に対する `umwelt_relative_diff` を
    [0, 上限] で 8 等分ビン。上限は初期集団の最大値の 1.5 倍で実走開始時に固定しログに記録。
  - 軸2（diversity）: Φ_depth = `dim Wld`（`actuated_world` の basis 列数）。ビン = {1,2,3,4,5,6,7,8+}。
- **quality**: 蝶番濃度 |Act|（`Hinge.Act` の要素数）。DC 余裕の構造的代理
  （VP-GEN-005 の cardPhiRich と同族のスカラー。check_DC は真偽値なので margin 代理を使う）。
- **世代更新**: 各世代、アーカイブから一様に B=16 親をサンプル → 変異 → 評価 →
  「セル空 or quality 上回り」で配置（標準 MAP-Elites）。世代数 G=200。
- **変異 kernel**: (α, σ) 関係の構造摂動 — 1 変異につき関係辺の追加/削除/付替のいずれか1つ。
  変異後は **admission check** を通過したものだけ集団に入る:
  (i) `check_DC` 成立、(ii) M4-safe 検査（`check_terminal_guard` / `check_trace_safe` 相当）、
  (iii) 蝶番非空。不通過は棄却しカウントを記録（項目6 R4 の入力）。
- **𝒮 の外部性**: kernel は zoo registry（個体への参照の集合）のみを持ち、
  個体構造体のフィールドへの書き込み関数を一切呼ばない（項目5で機械検査）。

## 項目2: 初期分布

- **系列個体**: 既存の非退化参照モデル族（`check_arbitrarily_large_nondegenerate_models` の
  構成子）から sizes (2, 3, 8, 32) で各4個体 = 16 個体。i_ref = size 2 の第1個体。
- **ランダム個体**: admissible な (α, σ) 関係の一様ランダム生成（admission check 通過まで
  リサンプル）で 48 個体。合計 64 個体で初期アーカイブを埋める。
- **RNG**: `Xoshiro(20260720 + k)`、replicate k = 0..9（項目4）。seed は certificate 仮定であり
  実装中の変更禁止。

## 項目3: Φ_rich の観測（σ 越し read-only・合成しない）

- **Φ_depth(i)** = `dim Wld`（`actuated_world`、tol は既定値）。
- **Φ_div(P)** = 集団の全ペア `umwelt_relative_diff` の中央値と IQR。
- **Φ_level**: 閉包階層検出は未実装のため **v1 実験の報告対象外**（可視ギャップとして明示。
  定数扱いで先取りしない）。
- **合成禁止**: 三成分の重みづけ・スカラー化は memo §11 のユーザー専権未確定事項。
  報告は成分別 + (Φ_depth, quality) の Pareto front 図示のみ。

## 項目4: 非退化測度（選択がドリフトと区別できること）

- **帰無系**: 同一パイプラインで quality 比較を無効化（セル配置を常に上書きランダム受理）。
  変異 kernel・seed 系列・世代数は選択系と同一。
- **replicate**: 選択系・帰無系とも k = 0..9 の 10 本ずつ。
- **統計量**: 世代 G 時点の (a) アーカイブ内 Φ_depth 最大値・平均値、(b) Φ_div 中央値。
  選択系 vs 帰無系を Mann–Whitney U（両側、α = 0.05、成分数 2 で Bonferroni 補正 α' = 0.025）、
  効果量 Cliff's delta ≥ 0.474（large）を**両方**満たして初めて「非退化」と主張する。
- **付帯報告**: アーカイブ被覆率（充填セル率）の推移。

## 項目5: Σ-purity 実験契約（二段検問・実装必須）

- **(a) 静的**: 選択 namespace（新規 `src/sigma_selection.jl` 内の関数）から個体 sink
  （νΦ / V / D / action trace を保持する構造体の更新関数）への呼び出し到達不能を静的走査で検査。
  許可リストは σ-observation getter（`actuated_world`, `umwelt_relative_diff`, `check_DC`,
  蝶番濃度取得）のみ。
- **(b) 動的**: メタモルフィック差分 — 同一個体・同一入力の下で 𝒮 の内部状態
  （アーカイブ内容・kernel 側 RNG 状態）を摂動した 2 走行について、各個体の観測トレースの
  直列化ハッシュが **bit 同一**であることを assert。10 ペア。
- **優先度**: 検問失敗時は実験結果全体を invalid とし Σ1 実装を差し戻す（項目6より優先）。

## 項目6: 反例基準（事前登録・実走前に固定・事後変更禁止）

| ID | 条件 | 帰結 |
|---|---|---|
| R1 | 動的 Σ-purity 検問失敗 | 実験無効。実装差し戻し（設計の反証ではない） |
| R2 | G=200 で項目4の非退化基準を両成分とも未達 | 現行 QD kernel 設計を棄却し再設計（Σ1 自体の棄却ではない） |
| R3 | 選択系の Φ 成分が帰無系より**有意に低い** | Σ1「豊穣化選択」仮説への反証データとして改訂D（ユーザー再判断）へ |
| R4 | admission check 棄却率 > 90% | 変異 kernel を再設計 |

本表は実走ログ生成より先にコミットされ、変更は新実験の起票としてのみ許す。

## 改訂D への接続

実走結果は成分別レポート（Pareto front・統計量・反例基準判定）として出力する。
E1 採否・genericity の再判断は**ユーザー専権**であり、いかなる結果からも自動昇格しない。

---

## 検証点（台帳起票分）

### VP-META-001 — Σ-purity 二段検問の実装

`check_sigma_purity(experiment)`: 項目5 (a)(b) の実装。Lean アンカー
`ERIEC.MetaSelection.m4_preserved_of_sigmaPure`（証明済み・G1 は照合のみ）。

### VP-META-002 — QD 選択 kernel と非退化測度

`qd_selection_step` / `check_selection_nondegenerate`: 項目1・4 の実装。Lean アンカー
`ERIEC.MetaSelection.SigmaPure`。

### VP-META-003 — Σ1 実験ハーネス（実走契約）

`run_sigma1_experiment(; replicate)`: 項目2・3・6 を束ねた実走。反例基準判定を含む。
Lean アンカー `ERIEC.MetaSelection.trace_preserved_of_sigmaPure`。
depends_on: VP-META-001, VP-META-002。

### VP-META-004 — Σ1 個体 adapter（carrier・参照族・観測写像。2026-07-20 起票）

codex challenge（run packet v1/v2 の具象化の縮退・seed 違反）を受け、個体の具象化を
本 VP に分離（`specs/eriec-sigma1-run-packet.md` §1 v3 の引継ぎ契約を払う）。

- **(i) carrier**: DC 認証ユニットの担体型（ERIEState 直か wrapper かは G0 凍結）と
  carrier → QDCandidate adapter `sigma1_observe_candidate`（read-only）。
- **(ii) 参照族 constructor**: sizes (2,3,8,32) × 各 4 変分の 16 個体。構築時 admission
  （`is_DC` ∧ 蝶番非空 ∧ M4-safe）を hard error で自己認証（リサンプル禁止）。
  `|α(a)| ≥ 2`（shape checker の非退化条件を継承）。乱数不使用の決定的構成。
- **(iii) 非縮退証人**: 参照族 16 個体の初期 QD 格子占有セル数 **≥ 5**、かつ k=2 群
  （i_ref を含む 4 変分）単独で **≥ 2 セル**（G3 の pass/fail 基準。この下限を満たす
  構成の充足可能性を statement 段階で構成とともに提示する）。
- **(iv) 観測写像（二段 adapter・2026-07-20 G0 衝突修正）**: 個体 → ObservationArtifact の
  最小構成を固定。サイズ違い個体間 diversity の Inf は**二段処理**とする —
  第1段で全候補の有限 diversity 最大値 M_f を計算し、第2段で Inf を M_f に置換する
  （「次元不一致個体は初期集団内で最遠」の意味論）。certified な
  `diversity_upper = 1.5 × maximum` 規則（`sigma_selection.jl` 不変更）はそのまま適用される。
  旧「Inf → 最上位ビン clamp」は certified の 1.5 headroom 規則下で最上位ビンが初期候補に
  対し算術的に到達不能なため撤回。
- **(v) 初期集団**: ユーザー決定（2026-07-20）の案B — 各 replicate が承認済み
  `Xoshiro(20260720+k)` からランダム 48 個体を生成。新規 seed の追加禁止。

実走（改訂C）は本 VP certified 後、かつユーザーの実走承認（承認ラッチ）後。

## 実装順序（codex）

1. VP-META-001 と VP-META-002 は並行可（いずれも新規 `src/sigma_selection.jl`）。
2. VP-META-003 は両者の後。
3. contract 領域は `meta.*`。実走（C）は VP-META-003 certified 後、別途ユーザー承認で開始。

## 不変条項チェック（設計段階・偽C）

- 層分離: 𝒮 は zoo registry 上のメタ操作。対象層に対象・公理を追加しない。✓
- Σ-purity: read-only 観測のみ。write-back 経路は二段検問で機械的に排除。✓
- M4: 変異は admission check で M4-safe を強制。quality/選択圧は個体の D へ write-back されない
  （アーカイブ配置はメタ層の事実）。✓
- 灯り: `phenomenal_claim` 不接触。✓
- E1: 環境定常のまま。E1 再判断はユーザー専権（改訂D）。✓
- tol/seed: `actuated_world` 既定 tol 不変更、seed は本仕様で固定。✓
- Φ_rich 合成: 未確定のまま固定しない（成分別報告のみ）。✓
