# Julia 実装仕様書 v1 — 離散層（Lean v1 確定版）

> **[SUPERSEDED]** この文書は歴史的記録です。現行の権威仕様は `specs/julia-impl-spec-v2.md` を参照してください。  
> v1 実装コード（`src/` 以下）は削除されていません。v2 仕様に包含・昇格されています。

**根拠**: `formal/ERIEC/` の Lean コード（`lake build` 通過済み）  
**対象**: Julia 実装の `core/` モジュール  
**スコープ**: Set/Poset 層のみ。テンソル（T_w, 𝐕, 𝐖𝐥𝐝）は v2 以降。

各関数に対応する Lean 定義・定理を明記する。Lean で証明された不変条件を Julia の `@assert` / テストで検証する。

---

## 1. 型の対応

| Lean 型 | Julia 型 | 備考 |
|---|---|---|
| `M : Type*` | `Set{M}` の要素型（型パラメータ） | 作動空間 |
| `E : Type*` | `Set{E}` の要素型 | 結合（環境）空間 |
| `C : Type*` | `Set{C}` の要素型 | 自己維持構成素空間 |
| `S : Type*` | 状態型 | システム状態 |
| `M -> Set E` | `Function{M, Set{E}}` / `Dict{M, Set{E}}` | 関係（前層） |
| `Set C` | `Set{C}` | 冪集合の元 |
| `GaloisConnection` | `check_galois_conn(...)::Bool` | 数値検証 |
| `NuPhi` 構造体 | `NuPhiResult{M,C}` 構造体 | 不動点計算結果 |
| `DC` 構造体 | `ERIEState{M,E,C,S}` 構造体 + `check_DC(...)` | 四条件の数値検証 |

---

## 2. 像作用素（Adjunction.lean / Closure.lean）

### 2.1 `α★` — alpha_star

```julia
# Lean: def alpha_star {M E} (αRel : M → Set E) (N : Set M) : Set E
#         := ⋃ m ∈ N, αRel m
function alpha_star(α_rel::Function, N::Set)
    isempty(N) && return Set{Any}()
    reduce(∪, (α_rel(m) for m in N))
end
```

### 2.2 `σ★_induced` — sigma_star_induced（右随伴として定義）

```julia
# Lean: def sigma_star_induced {M E} (αRel : M → Set E) (X : Set E) : Set M
#         := {m | αRel m ⊆ X}
# 不変条件: GaloisConnection(alpha_star, sigma_star_induced) が成立（Lean 証明済み）
function sigma_star_induced(α_rel::Function, all_M, X::Set)
    Set(m for m in all_M if α_rel(m) ⊆ X)
end
```

### 2.3 `σ★` — sigma_star（独立な σ_rel から）

```julia
# Lean: def sigma_star {M E} (σRel : E → Set M) (X : Set E) : Set M
#         := ⋃ e ∈ X, σRel e
function sigma_star(σ_rel::Function, X::Set)
    isempty(X) && return Set{Any}()
    reduce(∪, (σ_rel(e) for e in X))
end
```

### 2.4 `π★` / `ρ★` — pi_star / rho_star

```julia
# Lean: def pi_star (πRel : M → Set C) (A : Set M) : Set C := ⋃ m ∈ A, πRel m
function pi_star(π_rel::Function, A::Set)
    isempty(A) && return Set{Any}()
    reduce(∪, (π_rel(m) for m in A))
end

# Lean: def rho_star (ρRel : C → Set M) (Y : Set C) : Set M := ⋃ c ∈ Y, ρRel c
function rho_star(ρ_rel::Function, Y::Set)
    isempty(Y) && return Set{Any}()
    reduce(∪, (ρ_rel(c) for c in Y))
end
```

---

## 3. 自己維持閉包 Φ と νΦ（Closure.lean）

### 3.1 `Φ` — Phi

```julia
# Lean: def Phi (πRel : M → Set C) (ρRel : C → Set M) (Y : Set C) : Set C
#         := pi_star πRel (rho_star ρRel Y)
# 不変条件: Monotone(Phi) — Lean 証明済み（phi_mono）
function Phi(π_rel::Function, ρ_rel::Function, Y::Set)
    pi_star(π_rel, rho_star(ρ_rel, Y))
end
```

### 3.2 `νΦ` — 最大不動点（反復計算）

```julia
# Lean: structure NuPhi where
#         isFixedPoint : Phi piRel rhoRel nuPhi = nuPhi
#         isGreatest   : ∀ Y, Phi ... Y = Y → Y ⊆ nuPhi
#
# Julia では最大元から下降反復（Ψ(Y) = Y ∩ Φ(Y)）
struct NuPhiResult{C}
    value::Set{C}
    converged::Bool
    iterations::Int
end

function nu_phi(π_rel::Function, ρ_rel::Function, all_C::Set;
                max_iter::Int=1000)
    Y = Set(all_C)  # 最大元（全体集合）から開始
    for i in 1:max_iter
        PhiY = Phi(π_rel, ρ_rel, Y)
        Y_new = Y ∩ PhiY          # Ψ(Y) = Y ∧ Φ(Y)
        Y_new == Y && return NuPhiResult(Y, true, i)
        Y = Y_new
    end
    NuPhiResult(Y, false, max_iter)
end

# 検証: Lean の isFixedPoint に対応
function check_nu_phi_fixedpoint(π_rel, ρ_rel, result::NuPhiResult)
    Phi(π_rel, ρ_rel, result.value) == result.value
end
```

---

## 4. 感覚運動ループ T' と蝶番作動 Act（Hinge.lean）

### 4.1 `T'` — T_prime（感覚運動ループ作用素、離散版）

```julia
# Lean: def T_prime (αRel : M → Set E) (σRel : E → Set M) (X : Set E) : Set E
#         := alpha_star αRel (sigma_star σRel X)
function T_prime(α_rel::Function, σ_rel::Function, X::Set)
    alpha_star(α_rel, sigma_star(σ_rel, X))
end
```

### 4.2 `Act` — 蝶番作動

```julia
# Lean: def Act (ρRel : C → Set M) (σRel : E → Set M)
#              (κ : S → Set C) (ε : S → Set E) (s : S) : Set M
#         := rho_star ρRel (κ s) ∩ sigma_star σRel (ε s)
#
# 不変条件（Lean 証明済み）:
#   hinge_requires_both: Act(ε = ∅) = ∅
#   → 感覚運動閉包 ε が空なら Act は必ず空。蝶番は両側の制約が要る。
function Act(ρ_rel::Function, σ_rel::Function,
             κ::Function, ε::Function, s)
    rho_star(ρ_rel, κ(s)) ∩ sigma_star(σ_rel, ε(s))
end

# 検問 K2（蝶番）: Act ≠ ∅
check_hinge(ρ_rel, σ_rel, κ, ε, s) = !isempty(Act(ρ_rel, σ_rel, κ, ε, s))
```

---

## 5. 二重閉包 DC（DC.lean）

### 5.1 状態構造体

```julia
# Lean: structure DC (M E C S) where
#   hSelf  : κ s ⊆ Phi πRel ρRel (κ s)      ← κ が Φ の後不動点
#   hSMC   : ε s ⊆ T_prime αRel σRel (ε s)  ← ε が T' の後不動点
#   hAct   : Act(...).Nonempty               ← 蝶番非空
#   hBound : (κ s ∩ ∂).Nonempty             ← 生命境界との交わり
struct ERIEState{M,E,C,S}
    α_rel::Function     # M → Set{E}
    σ_rel::Function     # E → Set{M}
    π_rel::Function     # M → Set{C}
    ρ_rel::Function     # C → Set{M}
    κ::Function         # S → Set{C}  自己維持配置
    ε::Function         # S → Set{E}  結合配置
    boundary::Set{C}    # 区別部分 ∂
    s::S                # 現在の状態
end
```

### 5.2 DC 四条件の検証

```julia
# Lean 証明から導出された不変条件をそれぞれ検証する
struct DCResult
    hSelf::Bool    # (i)  κ ⊆ Φ(κ) — 自己維持後不動点
    hSMC::Bool     # (ii) ε ⊆ T'(ε) — 感覚運動閉包後不動点
    hAct::Bool     # (iii) Act ≠ ∅  — 蝶番非空（K2 検問）
    hBound::Bool   # (iv) κ ∩ ∂ ≠ ∅ — 区別との交わり
    act::Set       # Act の実際の値
end

function check_DC(sys::ERIEState)
    κs = sys.κ(sys.s)
    εs = sys.ε(sys.s)
    act = Act(sys.ρ_rel, sys.σ_rel, sys.κ, sys.ε, sys.s)

    # (i) κ ⊆ Φ(κ): Lean hSelf の検証
    h_self  = κs ⊆ Phi(sys.π_rel, sys.ρ_rel, κs)

    # (ii) ε ⊆ T'(ε): Lean hSMC の検証
    h_smc   = εs ⊆ T_prime(sys.α_rel, sys.σ_rel, εs)

    # (iii) Act ≠ ∅: Lean hAct（DC.act_nonempty）の検証
    h_act   = !isempty(act)

    # (iv) κ ∩ ∂ ≠ ∅: Lean hBound の検証
    h_bound = !isempty(κs ∩ sys.boundary)

    DCResult(h_self, h_smc, h_act, h_bound, act)
end

# DC 成立: 四条件全て true
is_DC(r::DCResult) = r.hSelf && r.hSMC && r.hAct && r.hBound
```

---

## 6. 検問（K1–K3）

### K1 内生性（外部 set point 禁止）

```julia
# Lean に直接対応する定理なし（構造的制約）
# Julia 側では: νΦ の計算が α_rel / σ_rel / π_rel / ρ_rel のみに依存し
#   外部 GOAL_PATTERN や定数 set point を含まないことを静的検査する。
# CI: grep で "GOAL" "TARGET" "SET_POINT" 等のシンボルが core/ に不在を確認。
```

### K2 蝶番（Act ≠ ∅）

```julia
# Lean 証明: DC.act_nonempty — DC ならば Act が空でない（定義から）
# Lean 証明: hinge_requires_both — ε=∅ なら Act=∅（片側だけでは成立しない）
function check_K2(sys::ERIEState)
    r = check_DC(sys)
    if !r.hAct
        @warn "K2 検問失敗: Act = ∅（蝶番崩壊）"
    end
    r.hAct
end
```

### K3 随伴（α⊣σ が消費層を貫通）

```julia
# Lean 証明: galoisConn_induced — GaloisConnection(α★, σ★_induced)
# ERIESystem を使う場合: hGC を構築時に渡す
function check_K3(α_rel::Function, σ_rel::Function, all_M, sample_E_subsets)
    for N in powerset(all_M), X in sample_E_subsets
        lhs = alpha_star(α_rel, N) ⊆ X
        rhs = N ⊆ sigma_star_induced(α_rel, all_M, X)
        @assert lhs == rhs "K3 検問失敗: N=$N, X=$X で GaloisConnection 破綻"
    end
    true
end
```

---

## 7. モジュール構成（実装ファイル）

```
core/
  adjunction.jl   # alpha_star, sigma_star_induced, sigma_star, check_K3
  closure.jl      # pi_star, rho_star, Phi, nu_phi, NuPhiResult
  hinge.jl        # T_prime, Act, check_hinge, check_K2
  dc.jl           # ERIEState, DCResult, check_DC, is_DC
tests/
  test_adjunction.jl   # galoisConn_induced に対応する数値テスト
  test_closure.jl      # phi_mono, nuPhi_isFixedPoint 対応
  test_hinge.jl        # hinge_requires_both 対応（ε=∅ → Act=∅）
  test_dc.jl           # DC 四条件の結合テスト
  checkpoints.jl       # K1/K2/K3 を一括実行
```

---

## 8. 実装しない（v2 以降）

| 項目 | 理由 |
|---|---|
| `T_w = ∂σ/∂a`（感受性テンソル） | Poset → Hilbert の橋が未定義 |
| `𝐕`（価値テンソル） | νΦ のテンソル化は v2 以降 |
| `𝐖𝐥𝐝`（行為化世界、固有値分解） | v3 以降 |
| Lenia 場との結合 | body/ モジュールは v2 以降 |

---

## 9. Lean → Julia 対応表（確定版）

| Lean 定義/定理 | Julia 関数/検証 | 状態 |
|---|---|---|
| `alpha_star` | `alpha_star()` | 確定 |
| `sigma_star_induced` | `sigma_star_induced()` | 確定 |
| `galoisConn_induced` | `check_K3()` で数値検証 | 確定 |
| `sigma_star` | `sigma_star()` | 確定 |
| `ERIESystem` | `ERIEState` + `hGC` フィールド | 確定 |
| `pi_star` / `rho_star` | `pi_star()` / `rho_star()` | 確定 |
| `Phi` | `Phi()` | 確定 |
| `phi_mono` | テストで `Phi(X) ⊆ Phi(Y) when X ⊆ Y` を確認 | 確定 |
| `NuPhi` + `isFixedPoint` | `nu_phi()` + `check_nu_phi_fixedpoint()` | 確定 |
| `T_prime` | `T_prime()` | 確定 |
| `Act` | `Act()` | 確定 |
| `hinge_requires_both` | `@test isempty(Act(ρ, σ, κ, _->Set(), s))` | 確定 |
| `DC` 構造体 | `ERIEState` + `check_DC()` | 確定 |
| `DC.act_nonempty` | `check_K2()` | 確定 |
