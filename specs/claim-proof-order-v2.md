# ERIEC schema v2 証明波

対象台帳: `specs/claim-ledger-v2.toml`

依存DAGは循環なし。機械的トポロジカル順だけでは難しいスペクトル定理と単純な集合論補題が同じ波に入るため、実作業では次の順を採用する。

## Wave 0 — statement基盤

- statement specの共通型を決める。
- `Conf`, `upd`, `Reachable`, `downV`, `K`, `BdPair` の型を凍結する。
- `R2Prime` と `E5` は theorem ではなくfieldとして凍結する。
- 既存v1宣言を変更せず、v2仕様との型比較表を作る。

完了条件: 対象claimの `statement_spec` と `statement_hash` が存在し、`spec_status="frozen"`。

## Wave 1 — 有限集合・到達構造

対象:

- `VP2-DYN-DESCENT-001`
- `VP2-DYN-K-ABSORB-001`
- `VP2-DYN-BD-ONEWAY-001`
- `VP2-DYN-INS-001`
- `VP2-DYN-INS-FIBER-001`

理由: スペクトル理論や参照模型に依存せず、集合・反射推移閉包だけで閉じる。ここでG0/G1の新方式を先に安定させる。

## Wave 2 — 有限価値

対象:

- `VP2-VAL-RAW-001`
- `VP2-VAL-NORMALIZED-001`
- `VP2-VAL-WELLDEF-001`
- `VP2-VAL-RANGE-001`
- `VP2-VAL-ENDOGENOUS-001`
- `VP2-VAL-COUNTERMODEL-001`
- `VP2-VAL-WEIGHTED-001`
- `VP2-VAL-WEIGHTED-PURE-001`

証明の核心は `|A∩B|≤|A|` と分母非零。現行 `V_endogenous` の外延性だけで完了扱いにせず、well-definednessと範囲を別に閉じる。

## Wave 3 — WorldDC反例

対象:

- `VP2-WDC-FORWARD-CE-001`
- `VP2-WDC-BACKWARD-CE-001`

前向反例ではDC witnessと零作用素を同じ存在量化内に置く。逆向反例では恒等作用素とDC不在模型を同じ存在量化内に置く。二方向を一つのchecker結果で代用しない。

## Wave 4 — スペクトル世界

対象:

- `VP2-WLD-EETA-001`
- `VP2-WLD-BAND-001`
- `VP2-WLD-INVARIANT-001`
- `VP2-WLD-ZERO-FIX-001`
- `VP2-WLD-MONO-001`
- `VP2-WLD-SUBSET-EETA-001`
- `VP2-WLD-LAMBDAMAX-001`
- `VP2-WLD-CHI-001`
- `VP2-WLD-CHI-NONTRIV-001`

最初にmathlibの有限次元自己随伴作用素・固有空間APIを確定する。現在の「固有ベクトル集合のspan」が文書の固有空間直和と一致することを補題として要求する。

`VP2-WLD-SLOWING-001` は予想のまま残す。Juliaの `critical_slowing_score` は `observation_only` であり証明ゲートには使用しない。

## Wave 5 — 有限崩壊

対象:

- `VP2-DYN-R2P-001`
- `VP2-DYN-COLLAPSE-CONF-001`
- `VP2-DYN-PATH-ITERATE-001`
- `VP2-DYN-TOTAL-ORBIT-001`
- `VP2-DYN-HINGE-COLLAPSE-001`

証明を三分割する。

1. κ非空中の階数厳密増加から、有限W上の最上階到達を示す。
2. 最上階でSig-2により非空後不動点を排除し、有限C上の真減少から空集合到達を示す。
3. 空集合の恒久性を示し、経路層・TotalNext軌道・蝶番空性へ持ち上げる。

現行 `Dynamics.collapse` のように `FiniteCollapse` 自体を仮定する命題は補助的な証明書展開に留め、定理5.4のVPには使わない。

## Wave 6 — 不変性

順序:

1. 四関係の直像保存。
2. `Phi`, `nuPhi`, 蝶番の保存。
3. DC保存。
4. κ・ε更新成分の保存。
5. `DriftEquivariant` を仮定した全更新可換。
6. 到達構造とINS保存。
7. ユニタリ共役による連続層保存。

現行の「一段可換を仮定すれば反復も可換」は補題として再利用できるが、`VP2-INV-UPD-001` の主定理にはしない。

## Wave 7 — 参照模型

順序:

1. `VP2-REF-STABLE-001`: 全関係、閉包、DC、Wld、価値、三状態遷移を持つwitness package。
2. `VP2-REF-DYN-001`: 同じ模型上のR2′充足とE5空虚充足。
3. `VP2-REF-NONDEG-001`: 多価関係、INS、Blind、NoTStarを同時に持つ非退化模型。

単なる `s0→s1→s2→s2` の遷移表はwitness packageの一フィールドであり、構成義務全体の証明にはしない。

## 全体完了条件

- theorem/counterexample/obligationの全原子claimがG0–G4を通過する。
- fieldは指定structureに現れ、定理へ昇格していない。
- conjectureは未証明のまま明示される。
- 全claim groupのG5 coverageが `complete` または正当な `open` になる。
