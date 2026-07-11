# フェーズ I 形式証明設計書 v3 — 随伴 α⊣σ と感受性テンソル

**担当**: claude（設計）→ codex（Lean 実装）  
**対象**: ERIE-C v5 §2 Def 2.1–2.4, Prop 2.4  
**Lean バージョン**: Lean 4 + Mathlib4  
**ファイル配置**: `erie-c/formal/ERIEC/Adjunction.lean`

> **v2 からの変更点**
> - Block 1B の `induced_is_minimal` を削除（X=∅ 反例により成立しない）
> - Block 1A と Block 1B の関係を注記として整理

---

## Block 1A — 構成的ガロア接続（σ★ を α_rel から右随伴として定義）

### 1. 数学的意図
α_rel: M → Set E が与えられたとき、σ★ を α★ の**右随伴**として閉じた形で定義する：

```
α_star(N)        = ⋃ {α_rel(m) | m ∈ N}
σ_star_induced(X) = {m : M | α_rel(m) ⊆ X}
```

この定義では GaloisConnection が無仮定で証明可能。

> **Block 1A と 1B の関係**:
> - Block 1A は「任意の α_rel に対して右随伴を構成できる」という数学的事実
> - Block 1B は「実際の ERIE システムでは α と σ は独立に与えられる」という設計上の事実
> - 両者は別物であり、「induced が最小」等の一般的な関係は証明しない

### 2. 型/構造体/仮定
```lean
variable {M E : Type*}

def α_star (α_rel : M → Set E) (N : Set M) : Set E :=
  ⋃ m ∈ N, α_rel m

def σ_star_induced (α_rel : M → Set E) (X : Set E) : Set M :=
  {m | α_rel m ⊆ X}
```

### 3. 定理名と statement 案
```lean
theorem ERIEC.Adj.galoisConn_induced (α_rel : M → Set E) :
    GaloisConnection (α_star α_rel) (σ_star_induced α_rel) := by
  intro N X
  simp [α_star, σ_star_induced, Set.iUnion_subset_iff]

theorem ERIEC.Adj.unit_induced (α_rel : M → Set E) (N : Set M) :
    N ⊆ σ_star_induced α_rel (α_star α_rel N) :=
  (ERIEC.Adj.galoisConn_induced α_rel).le_u_l N

theorem ERIEC.Adj.counit_induced (α_rel : M → Set E) (X : Set E) :
    α_star α_rel (σ_star_induced α_rel X) ⊆ X :=
  (ERIEC.Adj.galoisConn_induced α_rel).l_u_le X
```

### 4. 証明で使ってよい補題
- `Set.iUnion_subset_iff`: `⋃ i ∈ s, f i ⊆ t ↔ ∀ i ∈ s, f i ⊆ t`
- `Set.mem_iUnion`, `Set.mem_sep_iff`
- `GaloisConnection.le_u_l`, `GaloisConnection.l_u_le`

### 5. Julia 実装仕様（Block 1A 証明通過後に確定）
```julia
α_star(α_rel, N) = reduce(∪, (α_rel(m) for m in N), init=Set{Any}())
σ_star_induced(α_rel, X) = Set(m for m in all_M if α_rel(m) ⊆ X)

function check_galois_conn_induced(α_rel, all_M, sample_subsets_E)
    for N in powerset(all_M), X in sample_subsets_E
        @assert (α_star(α_rel, N) ⊆ X) == (N ⊆ σ_star_induced(α_rel, X))
    end
end
```

---

## Block 1B — 仮説的ガロア接続（独立な σ_rel を持つ ERIE システム）

### 1. 数学的意図
v5 §2 では α と σ は**独立な二前層**。σ_rel は物理的知覚関係として独立に与えられる。
GaloisConnection は「ERIE システムが満たすべき条件（M2）」として構造の一部に持ち込む。

```lean
structure ERIESystem (M E : Type*) where
  α_rel : M → Set E
  σ_rel : E → Set M
  -- σ_star を union 像として定義し、GC を公理として要求
  hGC   : GaloisConnection (α_star α_rel) (fun X => ⋃ e ∈ X, σ_rel e)
```

### 2. 型/構造体/仮定
```lean
structure ERIESystem (M E : Type*) where
  α_rel : M → Set E
  σ_rel : E → Set M
  hGC   : GaloisConnection (α_star α_rel) (fun X => ⋃ e ∈ X, σ_rel e)
```

### 3. 定理名と statement 案
```lean
-- unit/counit は hGC から即座に導出（証明ほぼなし）
theorem ERIEC.Adj.unit_of_gc {M E : Type*} (sys : ERIESystem M E) (N : Set M) :
    N ⊆ ⋃ e ∈ α_star sys.α_rel N, sys.σ_rel e :=
  sys.hGC.le_u_l N

theorem ERIEC.Adj.counit_of_gc {M E : Type*} (sys : ERIESystem M E) (X : Set E) :
    α_star sys.α_rel (⋃ e ∈ X, sys.σ_rel e) ⊆ X :=
  sys.hGC.l_u_le X
```

### 4. 証明で使ってよい補題
- `GaloisConnection.le_u_l`, `GaloisConnection.l_u_le`

### 5. Julia 実装仕様（Block 1B 証明通過後に確定）
```julia
struct ERIESystem
    α_rel   # M → Set{E}
    σ_rel   # E → Set{M}
    # hGC は check_galois_conn で数値検証
end

σ_star(sys::ERIESystem, X) = reduce(∪, (sys.σ_rel(e) for e in X), init=Set{Any}())

function check_galois_conn(sys::ERIESystem, all_M, sample_subsets_E)
    for N in powerset(all_M), X in sample_subsets_E
        @assert (α_star(sys.α_rel, N) ⊆ X) == (N ⊆ σ_star(sys, X)) "M2 違反"
    end
end
```

---

## Block 2 — 感受性テンソル（連続・ヤコビアン版）

### 1. 数学的意図
σ: ℝ^m → ℝ^e を可微分とし、点 a での Fréchet 微分を T_w とする。
**σ(a)（値）でなく fderiv（微分）**が T_w。これが表象主義との分岐点。

### 2. 型/構造体/仮定
```lean
variable (m e : ℕ)
variable (σ : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
variable (a : EuclideanSpace ℝ (Fin m))
```

### 3. 定理名と statement 案
```lean
noncomputable def T_w
    (σ : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m)) :
    EuclideanSpace ℝ (Fin m) →L[ℝ] EuclideanSpace ℝ (Fin e) :=
  fderiv ℝ σ a

theorem ERIEC.Sens.isDerivative :
    T_w m e σ a = fderiv ℝ σ a := rfl

theorem ERIEC.Sens.wellDefined (h : DifferentiableAt ℝ σ a) :
    HasFDerivAt σ (T_w m e σ a) a :=
  h.hasFDerivAt
```

### 4. 証明で使ってよい補題
- `DifferentiableAt.hasFDerivAt`

### 5. Julia 実装仕様
```julia
using ForwardDiff
sensitivity_tensor(σ, a) = ForwardDiff.jacobian(σ, a)  # (e×m)、値 σ(a) ではない
```

---

## Block 3 — 双対対称性（Prop 2.4）

### 1. 数学的意図
T_w の随伴作用素 T_w* は ⟨T_w x, y⟩_E = ⟨x, T_w* y⟩_M。有限次元では転置行列。

### 2. 型/構造体/仮定
```lean
-- ContinuousLinearMap.adjoint を使用
noncomputable def T_w_adjoint
    (σ : EuclideanSpace ℝ (Fin m) → EuclideanSpace ℝ (Fin e))
    (a : EuclideanSpace ℝ (Fin m)) :
    EuclideanSpace ℝ (Fin e) →L[ℝ] EuclideanSpace ℝ (Fin m) :=
  ContinuousLinearMap.adjoint (T_w m e σ a)
```

### 3. 定理名と statement 案
```lean
-- Prop 2.4（adjoint_inner_left から1行で通るはず）
theorem ERIEC.Adj.dualSymmetry
    (x : EuclideanSpace ℝ (Fin m)) (y : EuclideanSpace ℝ (Fin e)) :
    ⟪T_w m e σ a x, y⟫_ℝ = ⟪x, T_w_adjoint m e σ a y⟫_ℝ :=
  (ContinuousLinearMap.adjoint_inner_left _ x y).symm
```

### 4. 証明で使ってよい補題
- `ContinuousLinearMap.adjoint_inner_left`

### 5. Julia 実装仕様
```julia
sensitivity_tensor_adjoint(σ, a) = transpose(sensitivity_tensor(σ, a))

check_dual_symmetry(σ, a, x, y; tol=1e-10) =
    abs(dot(sensitivity_tensor(σ,a)*x, y) - dot(x, sensitivity_tensor_adjoint(σ,a)*y)) < tol
```

---

## 実装優先順位（v3 確定版）

1. Block 1A: `galoisConn_induced` → `unit_induced` → `counit_induced`
2. Block 1B: `ERIESystem` 構造体 → `unit_of_gc` → `counit_of_gc`
3. Block 2: `T_w` 定義 → `isDerivative` → `wellDefined`
4. Block 3: `dualSymmetry`

（`induced_is_minimal` は削除。Block 1A と 1B の一般的な関係は証明しない。）

Block 1A が通ったら Julia 仕様確定。疑問があれば返信を。
