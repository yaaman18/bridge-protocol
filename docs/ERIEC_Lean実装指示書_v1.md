# ERIEC Lean 実装指示書 v1(Codex 5.5 用)

対象: 『三層構造の圏論的定式化 v2.1』『§14 凍結準備書 v1』『§14 凍結文書 v1』の Lean 4 実装(Phase 1)。
読者: 実装エージェント。**本書に書かれていない判断を行う権限は実装者にない。**

---

## §0. 統治規則(違反は即差し戻し)

- **G1(典拠優先順位)** 矛盾を発見した場合の優先順位は 凍結文書 > 準備書 > v2.1 本体。矛盾の解消は実装者の仕事ではない。§6 の質問プロトコルで停止せよ。
- **G2(解釈禁止)** 仕様の定義・定理文・名前を「改善」「一般化」「簡略化」してはならない。数学的に同値な別定式を思いついても採用しない。mathlib に同等物がある場合も、仕様名のラッパを定義して仕様の文面を保存する(§3-R7)。
- **G3(公理禁止)** `axiom` 宣言を一切書かない。`sorry` / `admit` / `native_decide` を最終成果物に残さない。仕様が `[FLD]` とする命題は structure のフィールドとして、`[CNJ]` は `def ... : Prop` として**主張のみ**定義し、証明も反証も試みない。
- **G4(賭けの不可侵)** `W₁–W₆`(凍結文書 §2)を決定する公理・インスタンスを追加しない。無解釈記号 `Ph, Mat, impl, k₀` は変数・引数のままにする。これらに具体値を与えてよいのは独立性定理(凍結文書 §4)の証人の内部だけである。
- **G5(名前の凍結)** §4 の宣言台帳にある識別子は一字も変えない。台帳にない補助定義は `private` とし、接頭辞 `aux_` を付ける。
- **G6(語彙規律)** 識別子・docstring に対象領域語彙(認知・生命・意識等)を使わない。docstring は仕様の節番号への参照のみとする(例: `/-- v2.1 定理 1.4 -/`)。
- **G7(‡ の標識)** 再構成箇所(FM3、R2′、E5)に依存する宣言は docstring 冒頭に `‡` を付け、`ERIEC/Reconstructed.lean` 経由でのみ import する(依存の一方向性、v2.1 規律 0.2-6)。
- **G8(停止条件)** 次のいずれかに該当したら作業を止め、QUESTION を残す: (a) 仕様のシグネチャが型エラーになる、(b) 指定 API が mathlib に見つからない(§3-R8 の検索後)、(c) 二つの典拠が矛盾する、(d) 台帳にない公開宣言が必要になった。

---

## §1. 環境固定

```text
Lean:        leanprover/lean4:v4.x 系の最新安定(lean-toolchain に固定して記録)
mathlib:     master の直近タグにピン(lakefile 内 rev を固定して記録)
プロジェクト: lake new eriec; ルート名前空間 ERIEC
リント:      lake build が警告ゼロ。#lint は Phase 1 では任意
```

ディレクトリと import 順(依存はこの順に一方向。逆向き import は禁止):

```text
ERIEC/Core.lean           §1 関係核・随伴・剛性
ERIEC/Grading.lean        §2–3 階数・前層族・sieve
ERIEC/Closure.lean        §3 Φ, Θ, ν(gfp)
ERIEC/Cert.lean           §4 DC 述語・Act
ERIEC/Dynamics.lean       §5 遷移・W₆ 用到達
ERIEC/Continuous.lean     §6 最小連続層(Nontriv, Fix)
ERIEC/Reconstructed.lean  ‡ 集約(FM3 用データ構造)
ERIEC/FM.lean             §9 機能マーカ
ERIEC/Wager.lean          凍結文書 §2, §5
ERIEC/RefModel/KBad.lean, M0.lean, KPlus.lean, MPlus.lean, MCyc.lean
ERIEC/RefModel/Indep.lean 凍結文書 §4
ERIEC/Pinned.lean         ピン留め台帳の再輸出(§5)
```

---

## §2. タグ → Lean 対応(機械的規則)

| 仕様タグ | Lean 上の姿 |
|---|---|
| `[DEF]` | `def` / `structure` / `abbrev` |
| `[THM]` | `theorem`(証明必須。Phase 1 スコープ外なら着手しない、`sorry` で置くことも禁止 → そもそも宣言しない) |
| `[FLD]` | structure のフィールド。**決して theorem に昇格させない** |
| `[OBL]` | Phase 1 スコープ内なら `theorem`(証明必須)。スコープ外は宣言しない |
| `[CNJ]` | `def name : Prop := ...` のみ。`theorem` 化禁止(G3, G4) |
| `‡` | docstring 先頭に `‡`、Reconstructed 経由 import(G7) |

---

## §3. 型エンコーディング規約(全決定済み・選択の余地なし)

- **R1** 集合値関係は `A → Set E`。`Finset` は RefModel 内部の計算補助のみ(公開シグネチャに出さない)。
- **R2** 直像は `⋃ a ∈ N, α a` の形で定義(`Set.iUnion₂`)。独自の像演算子を発明しない。
- **R3** 順序・随伴は mathlib の `GaloisConnection` を使う(向きは `l a ≤ b ↔ a ≤ u b`。仕様の `α★(N)⊆X ⇔ N⊆σ∀(X)` と同じ向き)。
- **R4** 最大不動点は `OrderHom.gfp` を使う。`Set C` の完備束インスタンスは mathlib 既存。独自 gfp を書かない。
- **R5** 濃度は `Set.ncard`。`Fintype.card` への橋は RefModel 内でのみ。
- **R6** 階数は `variable (W : Type*) [LinearOrder W] [Fintype W] [OrderBot W] [OrderTop W]` とし、`(h0T : (⊥:W) ≠ ⊤)` を必要箇所で仮定に取る。`W = Fin 2` の具体化は RefModel のみ。
- **R7(ラッパ規則)** mathlib の既存定理で仕様の `[THM]` が一行証明できる場合、仕様名の theorem を宣言し本体を mathlib 補題に委譲する。仕様名を捨てて mathlib 名を直接使うことは禁止。
- **R8(API 検索規則)** 本書が挙げる mathlib 名は「確認済み想定」であり、リネームされていた場合は最近傍の同内容 API を**検索して**使う(`exact?` / loogle 相当)。同内容が存在しない場合のみ G8-(b)。想定 API: `GaloisConnection`, `OrderHom.gfp`, `OrderHom.le_gfp`, `OrderHom.isFixedPt_gfp`, `Relation.TransGen`, `Relation.ReflTransGen`, `Finset.max'`, `Set.ncard`, `LinearMap.eqLocus`, `orthogonalProjection`, `orthogonalProjection_mem_subspace_eq_self`。
- **R9(古典論理)** mathlib 依存のため `Classical.choice` は許容。ただし RefModel の有限事実は可能な限り `decide` / `fin_cases` / `simp [定義名リスト]` で示し、`Classical.byCases` の濫用をしない。`simp` は Wager/RefModel 内では必ず補題リスト付き(裸の `simp` 禁止)。
- **R10(宇宙)** すべて `Type*`。`Prop` への埋め込みで済むものを `Type` にしない。

---

## §4. 宣言台帳(Phase 1 完全版)

シグネチャは規範である。型エラーになる場合は G8-(a)。`variable {A E C S : Type*}` を各所で共有する。

### 4.1 ERIEC/Core.lean

```lean
structure RawCore (A E C S : Type*) where
  alpha : A → Set E
  sigma : E → Set A
  pi    : A → Set C
  rho   : C → Set A

/-- 凍結文書 定義1.2 -/
def RawCore.ConvHolds (K : RawCore A E C S) : Prop :=
  (∀ a e, e ∈ K.alpha a ↔ a ∈ K.sigma e) ∧ (∀ a c, c ∈ K.pi a ↔ a ∈ K.rho c)

/-- v2.1 §1.4 -/
structure ConvSystem (A E C S : Type*) extends RawCore A E C S where
  hConv  : ∀ a e, e ∈ alpha a ↔ a ∈ sigma e
  hConvP : ∀ a c, c ∈ pi a ↔ a ∈ rho c

def astar   (K : RawCore A E C S) (N : Set A) : Set E := ⋃ a ∈ N, K.alpha a
def sstar   (K : RawCore A E C S) (X : Set E) : Set A := ⋃ e ∈ X, K.sigma e
def pstar   (K : RawCore A E C S) (N : Set A) : Set C := ⋃ a ∈ N, K.pi a
def rstar   (K : RawCore A E C S) (Y : Set C) : Set A := ⋃ c ∈ Y, K.rho c
def sigmaForall (K : RawCore A E C S) (X : Set E) : Set A := {a | K.alpha a ⊆ X}

theorem astar_mono (K) : Monotone (astar K)                     -- 同型4本: sstar/pstar/rstar
theorem gc_forall (K) : GaloisConnection (astar K) (sigmaForall K)   -- v2.1 定理1.2
theorem sigmaForall_eq_of_conv (K : ConvSystem A E C S) :
    (fun X => {a | ∀ e, a ∈ K.sigma e → e ∈ X}) = sigmaForall K.toRawCore  -- v2.1 定理1.4

/-- v2.1 定理1.3(剛性) -/
theorem rigidity {A E : Type*} (α : A → Set E) (σ : E → Set A)
    (h : ∀ (N : Set A) (X : Set E), (⋃ a ∈ N, α a) ⊆ X ↔ N ⊆ ⋃ e ∈ X, σ e) :
    ∃ f : A → E, (∀ a, α a = {f a}) ∧ ∀ e, σ e = f ⁻¹' {e}
```

証明方針: `gc_forall` は両辺を `∀ a ∈ N, α a ⊆ X` に `simp [astar, sigmaForall, Set.iUnion_subset_iff]` で展開。`rigidity` は v2.1 の証明手順(`N={a}, X=∅` → 非空、二元仮定 → 単集合 X で矛盾、残り前像計算)を忠実に写す。

### 4.2 ERIEC/Grading.lean

```lean
structure GradedCore (A E C S W : Type*) [Preorder W] where
  alpha : W → A → Set E
  sigma : W → E → Set A
  pi    : W → A → Set C
  rho   : W → C → Set A     -- 引数順は必ず W が先頭(全フィールド共通)
  hConv  : ∀ w a e, e ∈ alpha w a ↔ a ∈ sigma w e
  hConvP : ∀ w a c, c ∈ pi w a ↔ a ∈ rho w c
  anti_alpha : ∀ ⦃u v⦄, u ≤ v → ∀ a, alpha v a ⊆ alpha u a
  anti_pi    : ∀ ⦃u v⦄, u ≤ v → ∀ a, pi v a ⊆ pi u a
  -- σ, ρ の反単調は定理として導出する(次行)。フィールドに入れない。
theorem GradedCore.anti_sigma / anti_rho   -- v2.1 定理2.2 の系(hConv 経由)
def GradedCore.at (K : GradedCore ...) (w : W) : ConvSystem A E C S
```

### 4.3 ERIEC/Closure.lean

```lean
def PhiHom (K) (w : W) : Set C →o Set C := ⟨fun Y => pstar (K.at w).toRawCore (rstar (K.at w).toRawCore Y), 単調性⟩
def ThetaHom (K) (w : W) : Set E →o Set E   -- 同型
def nuPhi (K) (w : W) : Set C := OrderHom.gfp (PhiHom K w)
theorem coinduction : Y ⊆ (PhiHom K w) Y → Y ⊆ nuPhi K w        -- OrderHom.le_gfp へ委譲(R7)
theorem nuPhi_fixed : (PhiHom K w) (nuPhi K w) = nuPhi K w      -- isFixedPt_gfp へ委譲
def sieveSet (K) (Y : Set C) : Set W := {w | Y ⊆ (PhiHom K w) Y}
theorem sieve_downclosed : u ≤ v → v ∈ sieveSet K Y → u ∈ sieveSet K Y   -- v2.1 定理3.4
structure Sig2 (K : GradedCore A E C S W) where               -- v2.1 公理3.7 [FLD]
  wstar : W
  wstar_lt_top : wstar < ⊤
  bounded : ∀ Y : Set C, Y.Nonempty → ∀ w ∈ sieveSet K Y, w ≤ wstar
```

### 4.4 ERIEC/Cert.lean(凍結文書 §1 の一階展開に一致させる)

```lean
structure CertData (K : GradedCore A E C S W) where
  kappa : S → Set C
  eps   : S → Set E
  Dd    : Set C
  omega : S → W
def Act (K) (w : W) (Kс : Set C) (X : Set E) : Set A :=
  rstar (K.at w).toRawCore Kс ∩ sstar (K.at w).toRawCore X
def h1 (d) (s : S) : Prop := d.kappa s ⊆ (PhiHom K (d.omega s)) (d.kappa s)
def h2 (d) (s : S) : Prop := d.eps s ⊆ (ThetaHom K (d.omega s)) (d.eps s)
def h3 (d) (s : S) : Prop := (Act K (d.omega s) (d.kappa s) (d.eps s)).Nonempty
def h4 (d) (s : S) : Prop := (d.kappa s ∩ d.Dd).Nonempty
def DC (d) (s : S) : Prop := h1 d s ∧ h2 d s ∧ h3 d s ∧ h4 d s
theorem empty_propagation : d.kappa s = ∅ ∨ d.eps s = ∅ → Act ... = ∅   -- v2.1 定理4.2
theorem crit_bound (sig : Sig2 K) : DC d s → d.omega s ≤ sig.wstar      -- v2.1 定理4.3
def PosV (d) (s : S) (e : E) : Prop :=
  ∃ c ∈ nuPhi K (d.omega s), ∃ a ∈ (K.at (d.omega s)).sigma e, c ∈ (K.at (d.omega s)).pi a
```

### 4.5 ERIEC/Dynamics.lean

```lean
structure Dyn (S : Type*) where
  stepInt : S → S → Prop
  stepExt : S → S → Prop
def Dyn.Step (dyn : Dyn S) (s t : S) : Prop := dyn.stepInt s t ∨ dyn.stepExt s t
```

(内的更新則・R2′・崩壊定理は Phase 2。ここでは W₆ に要る遷移のみ。)

### 4.6 ERIEC/Continuous.lean

```lean
def Nontriv {V : Type*} [AddCommGroup V] [Module ℝ V] (L : Module.End ℝ V) : Prop :=
  ∃ x : V, x ≠ 0 ∧ L x = x
def fixSubmodule (L : Module.End ℝ V) : Submodule ℝ V := LinearMap.eqLocus L 1
theorem nontriv_iff : Nontriv L ↔ fixSubmodule L ≠ ⊥
```

### 4.7 ERIEC/Reconstructed.lean(‡)

```lean
/-- ‡ FM3 用データ(v2.1 定義9.4)。批准まで差し替え可能に隔離。 -/
structure FMData (A S Ωι : Type*) where
  lstep : A → S → S → Prop
  oiota : S → Ωι
```

### 4.8 ERIEC/FM.lean

```lean
def phiMinus (K) (w : W) (m : A) (Y : Set C) : Set C :=
  pstar (K.at w).toRawCore (rstar (K.at w).toRawCore Y \ {m})
def FM1 (d) (m : A) (s : S) : Prop := ¬ (d.kappa s ⊆ phiMinus K (d.omega s) m (d.kappa s))
theorem fm1_mem_rstar : FM1 d m s → m ∈ rstar ... (d.kappa s)      -- v2.1 定理9.2(h1 仮定要)
def FM2 (d) (m : A) (s : S) : Prop := 1 < ((K.at (d.omega s)).alpha m).ncard
/-- ‡ -/ def FM3 (fd : FMData A S Ωι) (m : A) (s : S) : Prop :=
  ∃ s', fd.lstep m s s' ∧ fd.oiota s' ≠ fd.oiota s
def FM4 (L : Module.End ℝ V') (r : A → V') (m : A) : Prop := r m ∈ fixSubmodule L ∧ r m ≠ 0
-- 注: FM4 は Phase 1 では η=0 特化(v2.1 定義9.5 の Wld₀=Fix 形、定理6.6-2 による)。
--     射影版(orthogonalProjection ≠ 0)への一般化は Phase 2。この特化は本書が決定済み。
/-- ‡(FM3 経由) -/ def Conscious (…) (m : A) (s : S) : Prop := InH ∧ FM1 ∧ FM2 ∧ FM3 ∧ FM4
```

`InH (d) (a : A) (s : S) : Prop := a ∈ Act K (d.omega s) (d.kappa s) (d.eps s)`(Cert.lean に置く)。

### 4.9 ERIEC/Wager.lean(凍結文書 §2。文面変更禁止の最重要ファイル)

```lean
variable (Ph : S → Prop) (Mat : S → E → Prop) (impl : RawCore A E C S) (k₀ : ℕ)
def W1 : Prop := ∀ s, (DC d s ∧ Nontriv L) ↔ Ph s
def W2 : Prop := ∀ s, DC d s → ∀ e, PosV d s e ↔ Mat s e
/-- ‡ -/ def W3 : Prop := ∀ s, (∃ m, InH d m s ∧ FM1 d m s ∧ FM2 d m s ∧ FM3 fd m s ∧ FM4 L r m) ↔ Ph s
def W4 : Prop := impl.ConvHolds
def W5 : Prop := ∀ s, DC d s → k₀ ≤ {a | InH d a s}.ncard
def W6 (dyn : Dyn S) : Prop :=
  ∃ traj : ℕ → S, (∀ n, dyn.Step (traj n) (traj (n+1))) ∧ ∀ n, ∃ m, n ≤ m ∧ DC d (traj m)
theorem W6_iff_cycle [Finite S] : W6 dyn ↔ ∃ s, DC d s ∧ Relation.TransGen dyn.Step s s
```

`W6_iff_cycle` 証明方針: (⇐) 閉路周回列を `Nat.rec` で構成。(⇒) 鳩の巣(`Finite.exists_infinite_fiber` 相当を検索、なければ「DC 状態は有限種、無限回出現 → ある一つが二回出現」を `Set.Infinite` の補題で)。

### 4.10 ERIEC/RefModel/*.lean(凍結文書 §3 と一対一)

具体型は次に固定: `A := Fin 2, E := Fin 2, C := Fin 2, S := Fin 3, W := Fin 2`(`M0` のみ全部 `Fin 1`+`Fin 2` 階数、`KBad` は `A := Fin 1, E := Fin 2`)。関係は `match` で定義し、`Set` 表示(例: `fun a => match a with | 0 => {0, 1} | 1 => {1}`)。各補題(3.1–3.6)の証明は `ext x` → `fin_cases x` → `simp [定義名]` を基本形とし、`nuPhi = Set.univ` 型の等式は `le_antisymm le_top (coinduction …)` で示す(`decide` を `Set` 命題に直接使わない)。`Indep.lean` は凍結文書 定理4.1–4.6 を同名 `W1_indep … W6_indep` で証明し、`preservation`(定理5.1)で束ねる。

---

## §5. ピン留めと受け入れ検査

`ERIEC/Pinned.lean` に次を再輸出し、CI はこのファイルの解決可能性を検査する:
`ConvSystem, rigidity, gc_forall, nuPhi, coinduction, DC, Act, PosV, Nontriv, FM1–FM4, Conscious, W1–W6, W6_iff_cycle, W1_indep–W6_indep, preservation`。

**完了定義(全項必須)**:

1. `lake build` 成功、警告ゼロ。
2. `grep -rn "sorry\|admit\|native_decide\|^axiom\| axiom " ERIEC/` が空。
3. `#print axioms ERIEC.preservation` の出力が `{propext, Classical.choice, Quot.sound}` の部分集合。
4. `Pinned.lean` の全名が解決し、台帳のシグネチャと一致(引数順含む)。
5. ‡ 宣言が `Reconstructed.lean` 起点の依存に閉じている(`FM3` を import せずに `W1, W2, W4, W5, W6` がビルドできることを、Wager を二ファイルに割らずに確認する手段として `#print axioms` ならぬ import グラフ目視で可: `W3` 以外が `FMData` を引数に取らないこと)。

---

## §6. 質問プロトコル

停止時は該当ファイルに次の形式で残し、それ以上の実装を進めない:

```lean
-- QUESTION(典拠: 凍結文書§4.3 / 指示書§4.8):
--   FM4 の η=0 特化では補題 X が成立しない。選択肢 A: … / B: …
--   本 QUESTION の解決まで W3 系列を凍結し、他モジュールを続行する。
```

規則: 一つの QUESTION で止めるのは依存する系列のみ。独立なモジュールは続行する。QUESTION に自答して進むことは G2 違反。

---

## §7. フェーズ境界(Phase 1 でやらないことの明示)

- 崩壊定理(v2.1 定理5.4)、K 吸収性、INS、スペクトル帯 `Wld_η`(η>0)と射影版 FM4、不変性定理群(§12)、E5 → **Phase 2**。宣言すら置かない。
- 設計命題 8.5、予想 6.9、W₁–W₆ の決定 → **着手永久禁止**(G3, G4)。`Prop` 定義として置くのも Phase 2 で指示があるまで行わない。
- v2.1 §16 の既存ファイル(`Adjunction.lean` 等)との統合 → Phase 3。Phase 1 は新規プロジェクトとして独立にビルドする。
