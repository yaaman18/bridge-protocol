# Julia 実装仕様書 v3 — Wld 最小数値層

**状態**: v2 の上に積む実装仕様。  
**対象**: `src/world.jl`  
**スコープ**: `Wld = L = T' * T` の固有値 1 近傍部分空間。Lenia 場の実シミュレーション結合、到達可能性の力学証明、critical slowing down は後続。

---

## 1. 目的

`Wld` は外部表象ではなく、感受性テンソル `T = ∂σ/∂a` から内生的に計算される行為化世界である。

```text
L = T' * T
Wld = eigenspace(L, λ ≈ 1)
```

Julia v3 では、有限次元数値線形代数としてこの構造を実装する。

---

## 2. Julia API

```julia
struct WldResult
    loop::AbstractMatrix
    eigenvalues::Vector
    basis::AbstractMatrix
    selected::Vector{Bool}
end
```

必須関数:

- `world_loop_operator(tensor)`
- `world_loop_operator(sigma, a)`
- `actuated_world(tensor; target=1.0, tol=1e-6)`
- `actuated_world(sigma, a; target=1.0, tol=1e-6)`
- `world_nontrivial(result)`
- `world_projection(result)`
- `check_umwelt_relative(sigma1, a1, sigma2, a2; target=1.0, eig_tol=1e-6, diff_tol=1e-6)`

---

## 3. Guardrails

- `Wld` は `T` または `sigma,a` からのみ計算する。
- 外部 target pattern / goal / image representation は入力にしない。
- `target=1.0` は `L` の不変部分空間を取るためのスペクトル基準であり、外部 set point ではない。
- `check_umwelt_relative` は同じ物理次元でも `sigma` が変われば `Wld` が変わることを数値的に確認する。

---

## 4. 受け入れ条件

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
lake build
```

必須テスト:

- `L == T' * T`
- 固有値 1 の部分空間が非自明
- 固有値 1 がない場合は非自明でない
- `sigma` 改変で `Wld` の射影が変わる
