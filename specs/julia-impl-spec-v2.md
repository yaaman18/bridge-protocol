# Julia 実装仕様書 v2 — 現行 Lean 対応版

**状態**: 現行の権威仕様。`specs/julia-impl-spec-v1.md` は歴史的記録として保持する。  
**根拠**: `formal/ERIEC/` の Lean コード（`lake build` 通過対象）  
**対象**: Julia 実装の `src/` モジュール  
**スコープ**: v1 離散層 + Sensitivity + Value + Body。`Wld` 固有値分解と Lenia 場の実シミュレーション結合は v3 以降。

この仕様は、すでに Lean で確定した定義を Julia の数値・有限集合実装へ落とすための契約である。Julia 側では証明そのものではなく、有限宇宙上の検査、型分離、テストで Lean の不変条件に対応する。

---

## 1. モジュール構成

```text
src/
  relation.jl      # Relation, DiscreteRelation, apply
  adjunction.jl    # alpha_star, sigma_star, sigma_star_induced, GC checks
  closure.jl       # pi_star, rho_star, Phi, nu_phi
  hinge.jl         # T_prime, Act, check_K2
  dc.jl            # ERIEStructure, ERIEState, check_DC
  sensitivity.jl   # sensitivity_tensor, adjoint, dual symmetry check
  value.jl         # structural value / mattering bridge guardrail
  body.jl          # body-mode typing, body Jacobian, body GC helpers
test/
  test_adjunction.jl
  test_closure.jl
  test_hinge.jl
  test_dc.jl
  checkpoints.jl
  test_sensitivity.jl
  test_value.jl
  test_body.jl
```

---

## 2. 離散随伴層

### 2.1 像作用素

Lean 対応:

- `formal/ERIEC/Adjunction.lean`: `alpha_star`, `sigma_star`, `sigma_star_induced`, `galoisConn_induced`

Julia 対応:

- `alpha_star(alpha_rel, N)`
- `sigma_star(sigma_rel, X)`
- `sigma_star_induced(alpha_rel, all_M, X)`
- `check_K3(alpha_rel, all_M, sample_E_subsets)`
- `check_galois_conn(alpha_rel, sigma_rel, all_M, sample_E_subsets)`

`sigma_star_induced` は `alpha_rel` から構成される右随伴であり、Lean の `galoisConn_induced` に対応する。独立に与えられた `sigma_rel` は自動では随伴を満たさないので、`check_galois_conn` で有限宇宙上の

```text
alpha_star(alpha_rel, N) ⊆ X  iff  N ⊆ sigma_star(sigma_rel, X)
```

を検査する。

### 2.2 ERIEStructure と hGC

`ERIEStructure` は以下を持つ。

- `alpha_rel`
- `sigma_rel`
- `pi_rel`
- `rho_rel`
- `hGC`

`hGC` は `Union{Bool,Nothing}` とする。既存の 4 関係だけの構築では `nothing`、有限宇宙 `all_M/all_E` を渡す smart constructor では `check_galois_conn` を実行し、成功時に `true` を保存し、失敗時に `ArgumentError` を投げる。

理由:

- v1 互換の手動構築を壊さない
- 独立 `sigma_rel` の不正な随伴を検出できる
- 誘導随伴を使う場合は `sigma_star_induced` / `check_K3` で構成的に保証できる

---

## 3. 閉包層

Lean 対応:

- `formal/ERIEC/Closure.lean`: `pi_star`, `rho_star`, `Phi`, `phi_mono`, `NuPhi`

Julia 対応:

- `pi_star(pi_rel, A)`
- `rho_star(rho_rel, Y)`
- `Phi(pi_rel, rho_rel, Y)`
- `nu_phi(pi_rel, rho_rel, all_C; max_iter=1000)`
- `check_nu_phi_fixedpoint(pi_rel, rho_rel, result)`

`nu_phi` は最大元 `all_C` から `Y ∩ Phi(Y)` で下降反復する。有限集合で十分な `max_iter` があれば収束する。`max_iter` が不足した場合は `NuPhiResult(..., false, max_iter)` を返す。

必須テスト:

- `phi_mono`: `X ⊆ Y` なら `Phi(X) ⊆ Phi(Y)`
- 収束成功ケース
- 複数 iteration 収束ケース
- `max_iter` 不足による `converged=false` ケース

---

## 4. Hinge / DC 層

Lean 対応:

- `formal/ERIEC/Hinge.lean`: `T_prime`, `Act`, `hinge_requires_both`
- `formal/ERIEC/DC.lean`: `DC`, `DC.act_nonempty`

Julia 対応:

- `T_prime(alpha_rel, sigma_rel, X)`
- `Act(rho_rel, sigma_rel, kappa, epsilon, s)`
- `check_K2(sys)`
- `ERIEState`
- `check_DC(sys)`
- `is_DC(result)`

必須テスト:

- `epsilon(s) == empty` なら `Act == empty`
- `check_DC` は `hSelf/hSMC/hAct/hBound` をそれぞれ返す
- `is_DC` は四条件の論理積

---

## 5. Sensitivity 層

Lean 対応:

- `formal/ERIEC/Sensitivity.lean`: `T_w`, `T_w_adjoint`, `dualSymmetry`

Julia 対応:

- `sensitivity_tensor(sigma, a)`
- `sensitivity_tensor_adjoint(sigma, a)`
- `check_dual_symmetry(sigma, a, x, y; tol=1e-10)`

Julia では `ForwardDiff.jacobian` と行列転置で実装する。`check_dual_symmetry` は

```text
dot(T * x, y) ≈ dot(x, T' * y)
```

を許容誤差付きで確認する。

---

## 6. Value 層

Lean 対応:

- `formal/ERIEC/Value.lean`: `viabilityContribution`, `HasStructuralWeight`, `MatteringBridge`, countermodel

Julia 対応:

- `viability_contribution(nu_phi, contribution, e)`
- `has_structural_weight(nu_phi, contribution, e)`
- `MatteringBridge`
- `mattering_of_bridge(bridge, nu_phi, contribution, e)`
- `value_countermodel()`

`Value` は現象的 mattering を構造から自動導出しない。構造側は `nu_phi` への寄与数であり、現象側へ進むには明示的な `MatteringBridge` が必要である。この分離が §13-5 guardrail である。

---

## 7. Body 層

Lean 対応:

- `formal/ERIEC/Body.lean`: `InterventionMode`, `KernelParam`, `SensoryFeature`, `BodyResponse`, `body_galoisConn_induced`, `bodyJacobian`, `bodyJacobian_dualSymmetry`

Julia 対応:

- `InterventionMode`, `KernelParam`, `SensoryFeature`
- `IndexedState{K,T}`
- `MotorState`, `KernelParamState`, `SensoryState`
- `BodyResponse`, `EndogenousBodyResponse`
- `body_sigma_star_induced`
- `body_galois_conn_induced`
- `body_unit_induced`, `body_counit_induced`
- `body_jacobian`, `body_jacobian_adjoint`
- `body_loop_operator`
- `check_body_tensor_requirements`

`BodyResponse` は `IndexedState{InterventionMode}` のみを受ける。`KernelParamState` は別型であり、Lenia rule/kernel parameter offset を body action として渡せない。

`EndogenousBodyResponse` は外部 set point フィールドを持たない。ただし Julia のクロージャが外部変数を捕捉する可能性までは型で完全には禁止できない。v2 では構造フィールド検査を guardrail とし、より強い factory 制約は将来課題とする。

---

## 8. 実装しない

| 項目 | 状態 |
|---|---|
| `Wld` 固有値分解 | v3 以降 |
| Lenia 場の実シミュレーション結合 | v3 以降 |
| 外部 set point 捕捉の完全静的検出 | 将来課題 |

---

## 9. 受け入れ条件

必須:

```sh
julia --project=. -e 'using Pkg; Pkg.test()'
lake build
```

期待されるテスト群:

- adjunction
- closure
- hinge
- dc
- checkpoints
- sensitivity
- value
- body

削除・ロールバック判断:

- Lean 形式ファイルと対応テストが存在し、`lake build` と Julia test が通る実装は削除しない
- v1 とのスコープ衝突は v2 仕様への昇格で解消する
- 破壊的削除は明示的なユーザー判断がある場合のみ実行する
