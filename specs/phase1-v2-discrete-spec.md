# フェーズ I 形式証明設計書 v1-discrete — 離散層のみ（Lean v1）

**担当**: claude（設計）→ codex（Lean 実装）  
**対象**: ERIE-C v5 §1–§4（離散・Set/Poset 層のみ）  
**Lean バージョン**: Lean 4 + Mathlib4  
**方針**: 全定義・定理を `Set` / `GaloisConnection` の世界で閉じる。テンソル・fderiv・EuclideanSpace は v2 以降。

> **前回（v3）からの変更点**
> - Block 2/3（T_w, dualSymmetry）は `formal/ERIEC/Sensitivity.lean` に分離済みとして扱い、本 spec に含めない
> - `Adjunction.lean` は Block 1A/1B のみ残す（既存コードはそのまま）
> - 新規追加: Block 4（Φ, νΦ）/ Block 5（Act）/ Block 6（DC, dc_act_nonempty）

---

## 既存コード（変更なし）

`formal/ERIEC/Adjunction.lean` の以下は確定済みとして扱う：
- `alpha_star`, `sigma_star_induced`, `galoisConn_induced`, `unit_induced`, `counit_induced`（Block 1A）
- `sigma_star`, `ERIESystem`, `unit_of_gc`, `counit_of_gc`（Block 1B）

---

## Block 4 — 自己維持閉包 Φ と最大不動点 νΦ

### 1. 数学的意図
v5 §3 Def 3.1: `Φ_w = π★ ∘ ρ★`（産出前層と実現前層の合成）。  
`C` 上の単調関数として定義し、その最大不動点 `νΦ` が自己維持核。  
**実装方針**: `νΦ` をいきなり Knaster-Tarski で構成せず、`IsGreatestFixedPoint Φ νΦ` として仮定（型クラス/構造体）で持ち込む。後の v2 で complete lattice 上の構成に強化する。

### 2. 型/構造体/仮定
```lean
variable {M C : Type*}

-- 産出関係 π: M → 𝒫C、実現関係 ρ: C → 𝒫M
variable (piRel : M → Set C)
variable (rhoRel : C → Set M)

-- π★, ρ★ の像作用素（alpha_star と同じ構造）
def pi_star (piRel : M → Set C) (A : Set M) : Set C :=
  ⋃ m ∈ A, piRel m

def rho_star (rhoRel : C → Set M) (Y : Set C) : Set M :=
  ⋃ c ∈ Y, rhoRel c

-- Φ_w = π★ ∘ ρ★ : 𝒫C → 𝒫C（単調）
def Phi (piRel : M → Set C) (rhoRel : C → Set M) (Y : Set C) : Set C :=
  pi_star piRel (rho_star rhoRel Y)

-- νΦ: 仮定として持ち込む
structure NuPhi (M C : Type*) where
  piRel : M → Set C
  rhoRel : C → Set M
  nuPhi : Set C
  isFixedPoint : Phi piRel rhoRel nuPhi = nuPhi
  isGreatest : ∀ Y : Set C, Phi piRel rhoRel Y = Y → Y ⊆ nuPhi
```

### 3. 定理名と statement 案
```lean
-- Φ は単調（GaloisConnection への接続に必要）
theorem ERIEC.Closure.phi_mono (piRel : M → Set C) (rhoRel : C → Set M) :
    Monotone (Phi piRel rhoRel) := by
  intro Y Z hYZ
  simp [Phi, pi_star, rho_star]
  intro c m hm hc
  exact ⟨m, hYZ hm, hc⟩

-- νΦ は不動点（NuPhi 構造から直接）
theorem ERIEC.Closure.nuPhi_isFixedPoint (np : NuPhi M C) :
    Phi np.piRel np.rhoRel np.nuPhi = np.nuPhi :=
  np.isFixedPoint

-- νΦ は最大後不動点（postfixpoint ⊆ νΦ）
theorem ERIEC.Closure.nuPhi_isGreatest (np : NuPhi M C) (Y : Set C)
    (hY : Phi np.piRel np.rhoRel Y = Y) :
    Y ⊆ np.nuPhi :=
  np.isGreatest Y hY
```

### 4. 証明で使ってよい補題
- `Set.iUnion_mono`, `Set.iUnion_subset`
- `Set.subset_iUnion_of_mem`

### 5. Julia 実装仕様（Block 4 確定後）
```julia
pi_star(pi_rel, A) = reduce(∪, (pi_rel(m) for m in A), init=Set{Any}())
rho_star(rho_rel, Y) = reduce(∪, (rho_rel(c) for c in Y), init=Set{Any}())
Phi(pi_rel, rho_rel, Y) = pi_star(pi_rel, rho_star(rho_rel, Y))

# νΦ: 反復で近似（数値実装）
function nu_phi(pi_rel, rho_rel, all_C; max_iter=1000)
    Y = Set(all_C)  # 最大元から降下
    for _ in 1:max_iter
        Y_new = Phi(pi_rel, rho_rel, Y) ∩ Y  # Ψ(Y) = Y ∧ Φ(Y)
        Y_new == Y && return Y
        Y = Y_new
    end
    return Y
end
```

---

## Block 5 — 蝶番作動 Act

### 1. 数学的意図
v5 §4 Def 4.1: `Act_w(σ) = ρ★(κ(σ)) ∩ σ★(ε(σ))`。  
- `κ(σ)` = 状態 σ における自己維持配置（`Set C`）  
- `ε(σ)` = 状態 σ における結合配置（`Set E`）  
- 自己維持が要求する作動 ∩ 感覚運動が可能にする作動。  
**これが v5 の心臓部**。両側の制約の交わりが空でないことが二重閉包の蝶番。

### 2. 型/構造体/仮定
```lean
variable {M E C : Type*}

-- 状態型 S
variable {S : Type*}

-- 配置関数: κ: S → 𝒫C（自己維持配置）、ε: S → 𝒫E（結合配置）
variable (kappa : S → Set C)
variable (epsilon : S → Set E)

-- Act_w(σ) = ρ★(κ(σ)) ∩ σ★(ε(σ))
-- ここで sigma_star は ERIESystem.sigmaRel から来る（Block 1B）
def Act (rhoRel : C → Set M) (sigmaRel : E → Set M)
    (kappa : S → Set C) (epsilon : S → Set E) (s : S) : Set M :=
  rho_star rhoRel (kappa s) ∩ Adj.sigma_star sigmaRel (epsilon s)
```

### 3. 定理名と statement 案
```lean
-- Act の定義（展開補題）
theorem ERIEC.Hinge.act_def (rhoRel : C → Set M) (sigmaRel : E → Set M)
    (kappa : S → Set C) (epsilon : S → Set E) (s : S) :
    Act rhoRel sigmaRel kappa epsilon s =
    rho_star rhoRel (kappa s) ∩ Adj.sigma_star sigmaRel (epsilon s) := rfl

-- Act が空なら DC は成立しない（Prop 4.6 の一方向）
-- DC の定義に依存するため、まず Act_nonempty の「必要条件」として記述
theorem ERIEC.Hinge.act_nonempty_necessary
    {rhoRel : C → Set M} {sigmaRel : E → Set M}
    {kappa : S → Set C} {epsilon : S → Set E} {s : S}
    (h : Act rhoRel sigmaRel kappa epsilon s = ∅) :
    -- Act = ∅ ならば DC の条件 (iii) が破れる（後で DC 定義とつなぐ）
    rho_star rhoRel (kappa s) ∩ Adj.sigma_star sigmaRel (epsilon s) = ∅ :=
  h
```

### 4. 証明で使ってよい補題
- `Set.inter_empty`, `Set.empty_inter`
- `Set.nonempty_iff_ne_empty`

### 5. Julia 実装仕様（Block 5 確定後）
```julia
Act(rho_rel, sigma_rel, kappa, epsilon, s) =
    rho_star(rho_rel, kappa(s)) ∩ sigma_star(sigma_rel, epsilon(s))

# 検問 K2（蝶番）: Act が空でないことを確認
check_hinge(rho_rel, sigma_rel, kappa, epsilon, s) =
    !isempty(Act(rho_rel, sigma_rel, kappa, epsilon, s))
```

---

## Block 6 — 二重閉包 DC と定理 DC → Act≠∅

### 1. 数学的意図
v5 §4 Def 4.2: `DC(σ)` の四条件：
- (i) `κ(σ) ∈ Coalg(Φ_ω)`: 自己維持配置が Φ の後不動点（`Φ(κ) ⊆ κ`... 注意: v5 の余代数条件は `κ ⊆ Φ(κ)` の方向）
- (ii) `ε(σ) ∈ Coalg(T'_ω)`: 感覚運動閉包（`T' = α★ ∘ σ★` の後不動点）
- (iii) `Act(σ) ≠ ∅`: 蝶番が空でない
- (iv) `κ(σ) ∩ ∂ ≠ ∅`: 区別部分 ∂ との交わり（生命境界）

**設計判断**: DC の定義に (iii) を含める。`DC → Act≠∅` は定義から trivial になるが、それで正しい（DC の必要条件として Act≠∅ が内包されている）。逆向き（`Act≠∅ ∧ 他条件 → DC`）は自然に成立する。

### 2. 型/構造体/仮定
```lean
-- T'_w = α★ ∘ σ★（感覚運動ループ、離散版）
def T_prime (alphaRel : M → Set E) (sigmaRel : E → Set M) (X : Set E) : Set E :=
  Adj.alpha_star alphaRel (Adj.sigma_star sigmaRel X)

-- DC の四条件を構造体として定義
structure DC (M E C S : Type*) where
  -- システムパラメタ
  alphaRel : M → Set E
  sigmaRel : E → Set M
  piRel    : M → Set C
  rhoRel   : C → Set M
  kappa    : S → Set C
  epsilon  : S → Set E
  boundary : Set C         -- 区別部分 ∂
  -- 状態
  s : S
  -- 四条件
  -- (i) 自己維持配置が Φ の後不動点: Φ(κ(s)) ⊆ κ(s)... 
  --     v5 は余代数 κ ⊆ Φ(κ) の方向。ここを確認要。
  hSelf   : kappa s ⊆ Phi piRel rhoRel (kappa s)
  -- (ii) 感覚運動閉包: ε(s) ⊆ T'(ε(s))
  hSMC    : epsilon s ⊆ T_prime alphaRel sigmaRel (epsilon s)
  -- (iii) 蝶番非空
  hAct    : (Act rhoRel sigmaRel kappa epsilon s).Nonempty
  -- (iv) 区別との交わり
  hBound  : (kappa s ∩ boundary).Nonempty
```

### 3. 定理名と statement 案
```lean
-- DC → Act≠∅（定義から trivial）
theorem ERIEC.DC.act_nonempty {M E C S : Type*} (dc : DC M E C S) :
    (Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s).Nonempty :=
  dc.hAct

-- Act=∅ → ¬DC（対偶）
theorem ERIEC.DC.not_dc_of_act_empty {M E C S : Type*}
    (h : ¬(Act dc.rhoRel dc.sigmaRel dc.kappa dc.epsilon dc.s).Nonempty) :
    False :=
  h dc.hAct

-- DC の蝶番条件と自己維持条件の独立性（片側だけではDCにならない）
-- κ のみ（ε = ∅）→ Act = ∅ → ¬DC
theorem ERIEC.DC.hinge_requires_both
    (rhoRel : C → Set M) (sigmaRel : E → Set M)
    (kappa : S → Set C) (s : S) :
    Act rhoRel sigmaRel kappa (fun _ => ∅) s = ∅ := by
  simp [Act, Adj.sigma_star, rho_star]
```

### 4. 証明で使ってよい補題
- `Set.Nonempty`, `Set.nonempty_iff_ne_empty`
- `Set.inter_nonempty`
- `Set.subset_iUnion_of_mem`
- `Set.empty_inter`, `Set.inter_empty`

### 5. Julia 実装仕様（Block 6 確定後）
```julia
struct ERIEDC{M,E,C,S}
    alpha_rel; sigma_rel; pi_rel; rho_rel
    kappa; epsilon; boundary::Set{C}
    s::S
end

function check_DC(dc::ERIEDC)
    κs = dc.kappa(dc.s); εs = dc.epsilon(dc.s)
    Φκ = Phi(dc.pi_rel, dc.rho_rel, κs)
    Tε = T_prime(dc.alpha_rel, dc.sigma_rel, εs)
    act = Act(dc.rho_rel, dc.sigma_rel, dc.kappa, dc.epsilon, dc.s)
    (i)  = κs ⊆ Φκ            # 自己維持後不動点
    (ii) = εs ⊆ Tε             # 感覚運動閉包
    (iii)= !isempty(act)        # 蝶番非空（K2 検問）
    (iv) = !isempty(κs ∩ dc.boundary)  # 区別との交わり
    all([(i), (ii), (iii), (iv)])
end
```

---

## ファイル構成（v1 完成後）

```
formal/ERIEC/
  Adjunction.lean    # Block 1A/1B（確定済み）
  Closure.lean       # Block 4: Phi, NuPhi
  Hinge.lean         # Block 5: Act
  DC.lean            # Block 6: DC, dc_act_nonempty
  Sensitivity.lean   # Block 2/3（v2 以降、T_w, dualSymmetry）
  ERIEC.lean         # 全ファイルの import
```

---

## 実装優先順位

1. `Closure.lean`: `phi_mono` → `NuPhi` 構造体 → `nuPhi_isFixedPoint` / `nuPhi_isGreatest`
2. `Hinge.lean`: `T_prime` → `Act` 定義 → `act_nonempty_necessary` → `hinge_requires_both`
3. `DC.lean`: `DC` 構造体 → `act_nonempty` → `not_dc_of_act_empty`
4. 必要に応じて `Adjunction.lean` から不要な Block 2/3 を `Sensitivity.lean` へ移動

---

## 設計上の注意点（codex へ）

**DC (i) の方向について**: v5 §3 Def 3.1 の余代数条件は `κ ⊆ Φ(κ)`（Φ への「射」が存在する = 後不動点）。本 spec では `hSelf : kappa s ⊆ Phi ... (kappa s)` としているが、v5 の文言と方向を確認して修正してほしい。

**hinge_requires_both の証明**: `Adj.sigma_star sigmaRel ∅ = ∅` を示す必要あり。`Set.iUnion_empty` で通るはず。

**NuPhi を仮定として持ち込む理由**: `Set C` は complete lattice なので Knaster-Tarski は使えるが、Mathlib での `Set.lfp` / `Set.gfp` の取り扱いが複雑。v1 では構造体として外から与え、v2 で `OrderHom.gfp` や `CompleteLattice` ベースの構成に差し替える。
