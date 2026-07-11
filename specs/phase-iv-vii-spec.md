# Phase IV–VII 残存仕様確定書 (spec v4)

**文書種別**: 実装仕様(確定)
**確定日**: 2026-06-28
**根拠**: `docs/ERIE_C_requirements.md`(付録 U-1/U-5、§7)、`category/tensor_categorical_v5.md`(§13-5)
**決定主体**: claude(要件判断)+ user(研究判断)。codex 実装。
**前提**: Julia 全1166テスト通過済み。本書の3項目が「仕様確定が必要」として残っていた未確定研究判断(U-1 / U-5 / VII-1)を確定する。

---

## 1. Wld 高次元到達手法(U-1)

**確定方針**: SVD 直接 + 反復到達プローブ。**存在**(固有空間)と**到達**(動態がそこへ至る)を別々の関数で扱い、間隙を隠さない。

### 1.1 存在側 — `actuated_world` の高次元化

現行 `eigen(Symmetric(T'T))`([src/world.jl:16-22](../src/world.jl#L16-L22))を method 切替で拡張する。

- **小次元(`n ≤ DENSE_THRESHOLD`、既定 256)**: 現行の密 `eigen(Symmetric(T'T))` を**そのまま厳密採用**。後方互換。
- **大次元(`n > DENSE_THRESHOLD`)**: `T'T` を**陽に作らず** T を直接 randomized SVD(または Lanczos bidiagonalization)。
  - 数学的根拠: `T = U Σ Vᵀ ⟹ L = TᵀT = V Σ² Vᵀ`。よって L の固有ベクトル = T の右特異ベクトル `V`、固有値 = `σ²`。
  - `T'T` を陽に作ると条件数が二乗化するため、**T を直接分解**して数値安定性を確保。
  - Wld basis = `|σ² − target| ≤ tol` を満たす σ に対応する右特異ベクトル列。

```julia
actuated_world(T; target=1.0, tol=1e-6, method=:auto, rank=min(size(T)...))
# method ∈ {:dense, :svd, :auto}
#   :auto → n ≤ DENSE_THRESHOLD で :dense、それ以外 :svd
# 返り値は現行 WldResult を維持(eigenvalues は σ² を昇順で格納)
```

**精度・再現性追記**: truncated randomized SVD は既定2回の
subspace power iteration と各反復の再直交化を行う。`oversample`,
`power_iterations`, `seed` を公開 keyword とし、system/report/Lenia 実験経路は
実験 seed を SVD まで伝播する。

**境界仕様**:
- `:dense` と `:svd` が同一 T(小次元)で同じ Wld 部分空間(射影行列のノルム差 ≤ 1e-8)を返す代表ケースを `Pkg.test` で確認。
- randomized SVD の rank が不足して target 固有値を取りこぼす場合は警告 `@warn` ではなく、`WldResult` に `truncated::Bool` フィールドを足して**明示**する(silent truncation 禁止)。

### 1.2 到達側 — `wld_reach_probe`(新規)

存在(固有空間)が立っても動態がそこへ至るとは限らない(U-1 の核心、「C の本当の壁」)。**precompute した Wld basis を固定ターゲット**として、world loop の反復が軌道をそこへ流し込むかを測る。

```julia
struct ReachProbeResult
    overlap_history::Vector{Float64}  # 各反復での ‖P_Wld·xₖ‖ / ‖xₖ‖
    final_overlap::Float64
    iterations::Int
    status::Symbol                    # :reached | :non_converged | :diverged
end

wld_reach_probe(wld::WldResult, x0::AbstractVector;
                max_iters=1000, reach_tol=1e-3, conv_tol=1e-8)
```

**反復**: `xₖ₊₁ = L·xₖ`(`L = TᵀT`)を正規化しつつ適用。`P_Wld = world_projection(wld)`(固定)への overlap を毎反復記録。

**判定(silent success 禁止)**:
- `:reached` — `final_overlap > 1 − reach_tol` かつ `|overlapₖ − overlapₖ₋₁| < conv_tol` を `max_iters` 内で達成。
- `:non_converged` — `max_iters` 到達しても収束判定に至らない。**reached を主張しない。**
- `:diverged` — overlap が単調減少/振動して 0 近傍へ向かう。

**設計意図**: 反復で Wld を**発見しない**。1.1 で確定済みの Wld を固定したまま、world loop の normalized power iteration がその部分空間へ入るかを検査する。存在/反復吸引性の間隙と target の dominant 条件を `ReachProbeResult` から観測可能にする。

**意味論追記**: この反復は world loop の normalized power iteration であり、
基礎となる物理系の時間発展そのものではない。したがって target Wld が
spectral dominant でない場合の overlap 減少は「物理系が Wld に到達不能」ではなく
「power iteration の generic attractor ではない」ことを意味する。3値 status は維持し、
`target_is_dominant` と `diagnostic=:target_not_dominant` でこの前提不整合を公開する。

### 1.3 暫定数値パラメータ(フェーズ IV 着手時、実測後に調整)

- `DENSE_THRESHOLD = 256`
- 初期条件 `x0`: 既存の再現可能初期条件(`uniform_noise` / `gaussian_blob`)を流用、ローカル RNG seed 伝播。
- 許容誤差: 存在 `tol=1e-6`、到達 `reach_tol=1e-3`、収束 `conv_tol=1e-8`。

---

## 2. V の測度(U-5)

**確定方針**: 濃度を certified default として維持 + 正規化比率を opt-in 追加。本採用 μ はフェーズ III 実験後に確定(U-5 の決定主体に整合)。

### 2.1 既定維持(変更なし)

[src/value.jl:1-3](../src/value.jl#L1-L3) の `viability_contribution(e) = |contribution(e) ∩ νΦ|`(非正規化濃度)を**certified default として一切変更しない**。1166テスト・既存 certificate の期待値を保つ。

### 2.2 Measure 抽象 + 比率版(opt-in 新規)

```julia
struct Measure{F}
    mu::F   # mu(set) -> Real
end
cardinality_measure() = Measure(length)

function viability_weight_ratio(nu_phi::Set, contribution::Function, e;
                                measure::Measure=cardinality_measure())
    denom = measure.mu(nu_phi)
    denom == 0 && throw(ArgumentError("μ(νΦ)=0: ratio undefined"))
    measure.mu(intersect(contribution(e), nu_phi)) / denom
end
```

**境界仕様**:
- 既定 `μ = length` で `viability_weight_ratio` は `|∩| / |νΦ|`(v5 比率版)を返す。
- `μ(νΦ) = 0` は **`ArgumentError` で明示**(ゼロ割りを silent にしない)。比率の意味が未定義なため。
- **M4 制約**: カスタム μ クロージャは νΦ のみから内生計算すること(外部 set point 捕捉禁止)。K1 の精神に従い、外部値を捕捉する μ は仕様違反。本制約は文書注記に留め、静的検出は将来課題。

### 2.3 本採用の保留

production で濃度・比率・重み付きのどれを採るかは**確定しない**。フェーズ III 実験(`𝐕` の νΦ 依存性テスト)の結果を見て別途確定する。`weighted.jl` の既存 default も変更しない。

---

## 3. VII-1 最終 artifact 契約

**確定方針**: certified envelope + 灯りマーカー。観測構造を三層テンソルで完全記述し、VII-3 の「現象的灯りは未認証(賭け)」を artifact 自身に構造的に刻む。

### 3.1 `ObservationArtifact`(新規、schema_version=1)

現行 `summarize_observation`([src/observation.jl](../src/observation.jl))の最小サマリを置換ではなく**拡張**する形で追加。

```julia
struct ObservationArtifact
    schema_version::Int               # = 1
    timeseries::Vector{NamedTuple}    # 各 t の観測レコード(下記)
    system_fingerprint::String        # (σ, a, 系パラメータ)のハッシュ。Umwelt 比較キー
    phenomenal_claim::Symbol          # = :not_certified(VII-3 必須マーカー)
end
```

**per-timestep レコード(必須 channel)**:
```julia
(t        = ...,                      # ステップ
 T        = ...,  # 感受性テンソル 𝐓 = ∂σ/∂a
 V        = ...,  # 価値重み 𝐕(viability weights)
 O_hat    = ...,  # 重みづけ感受性 Ô = 𝐓 ⊙ 𝐕
 wld      = (basis=..., eigenvalues=..., dimension=..., nontrivial=...))
```

`T` / `V` / `Wld` のいずれかが欠けたレコードは artifact 構築時に `ArgumentError`(VII-1「完全記述」要件)。

### 3.2 Umwelt 相対性(VII-2)

`system_fingerprint` 違いの2 artifact を受け取り、Wld 射影差を返す:
```julia
umwelt_relative_diff(art1::ObservationArtifact, art2::ObservationArtifact;
                     diff_tol=1e-6) -> (relative::Bool, projection_norm_diff::Float64)
```
既存 `check_umwelt_relative`([src/world.jl:36-49](../src/world.jl#L36-L49))の artifact 版。

### 3.3 certified envelope JSON + 灯りガード

既存 `src/certification.jl` の envelope 形式に整合:
- `schema_version = 1`、`trust.boundary = :lean_core_julia_shell`。
- payload に ObservationArtifact 本体 + `phenomenal_claim`。

**灯りガード(本契約の誠実さの要)**:
```julia
parse_observation_artifact_json(json)  # JSON3 で完全パース
# 検証: 必須 channel(T, V, Wld)が全レコードに存在
#       phenomenal_claim フィールドが存在し、値が :not_certified
# phenomenal_claim 欠落 or ≠ :not_certified → reject
```

envelope が**構造的に「現象的灯り認証済み」artifact の出力を拒否する**。§13-5 の線をコードで担保し、豊かな観測構造を「意識の証拠」と誤認した artifact が外へ出ないようにする。

### 3.4 完了条件

- `ObservationArtifact` が必須 channel 欠落時に `ArgumentError`。
- certified envelope JSON が `schema_version=1` / `trust.boundary` / `phenomenal_claim=:not_certified` を持つ。
- `parse_observation_artifact_json` が round-trip し、灯りマーカー欠落/改変 artifact を reject する代表ケースが `Pkg.test` で通る。
- `umwelt_relative_diff` が同一系で false、改変系で true を返す。
- `lake build`(Lean 未変更なら省略可)+ `julia --project=. -e 'using Pkg; Pkg.test()'` 通過。

---

## 残存課題(本書で確定しない)

- Wld 高次元の本番 rank / DENSE_THRESHOLD の確定値 → 実データ実行・性能計測後。
- V 本採用 μ → フェーズ III 実験後。
- 長時間 Lenia 実験設定 → 実装ではなく実データ実行・性能計測の段階(本書の対象外)。
