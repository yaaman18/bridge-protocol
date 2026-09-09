# 再活性化基体プロファイル v1 読取レビュー

結論: **challenge — 現草案だけでは「基体を先に凍結してから DC を問う」順序を機械的に保証できない。**
2026-09-08、agmsg erie/claude の `[AUTO 1/10]` 依頼への回答。対象は
`specs/drafts/reactivation-substrate-profile-v1-items.md`。実装・草案編集・設計決定は行っていない。
C=ユニット、M→E を基体に含める、κ=persistence の三前提は依頼どおり固定して評価した。
このセッションで直接確認できるユーザー承認の記録は草案と依頼文に限られ、追加の意味変更の承認とは扱わない。

## (a) accept: 抽象境界 witness の再利用

`formal/ERIEC/FieldBridge/Boundary.lean:17` は任意の `Cell : Type u` と
`neighbors : Cell → Set Cell` について、境界 membership と
`cell ∈ support ∧ ∃ neighbor ∈ neighbors cell, neighbor ∉ support` の **同値**を要求する。
周期性・対称性・格子・有限性は仮定されていない。グラフからこの同値どおり境界を作れば、
既存宣言および `boundary_subset_support` の変更・追加仮定は不要。
具体インスタンスを Lean に掲載するならその定義・証明は別途必要だが、抽象定理の拡張ではない。

ただし既存 Julia `check_periodic_body_boundary` の契約は固定正方トーラスであり、
グラフ用としてそのまま再利用できない（`specs/packets/VP-BDY-003.md`, Julia checker boundary）。
グラフの全ユニット・隣接・境界の完全照合は新パケットで確定する。
W_env を境界隣接から除外するかも明示が必要。現在の §5 は W のみで、環境経路を含めた孤立性とは異なる。

## (b) clarify: π/ρ の型方向は正しいが、測定意味は未確定

`formal/ERIEC/DC.lean:6` の binder は M,E,C,S、`piRel : M → Set C`,
`rhoRel : C → Set M`。§6 の lesion_motor→構成素、lesion_constituent→出力はこの方向に一致する。
`Closure.Phi` は π⋆∘ρ⋆（`formal/ERIEC/Closure.lean:7-15`）であり、逆向きに直す根拠はない。
ただし off 介入による喪失は、指定した対照・状態・期間における依存を測る。
これだけから「産出」や on 介入による十分性との同値は導けない。Lean の型もその同値を主張していない。

最小修正候補: 同一初期条件の baseline と lesion の最終 k+1 窓に対して
`π(m)=Persist(base)\Persist(lesion(m))`、
`ρ(c)=(Persist(base)\Persist(lesion(c)))∩O` と定義し、開始時刻・clamp 優先順位・観測窓を凍結する。
これは推奨案であり、意味決定はユーザーへ返す。
M⊆C のため c=m では物理的に同じ off 介入になり得る。別タグのハッシュを付けても独立な実験の証拠にはならない。
介入対象自身の機械的な脱落を含めるか、冗長な原因・抑制による活性増加をどう扱うかも固定が必要。
異なる s0 の測定を union/intersection するのか、状態ごとの関係として certificate を作るのかを明記する。
同時活性だけから π を定義する代案は、介入効果との同一視になるので推奨しない。

## (c) challenge: 整数だけで全経路の厳密性や認証分類は確定しない

`src/dc.jl:133-150` は全台の重複、関係・状態集合の台内閉性を検査し、4述語を評価する。
`src/adjunction.jl:1-19`, `src/closure.jl:1-10`, `src/hinge.jl:1-6` の経路は集合演算で tol を使わない。
有限で全域的・決定的な関係と κ/ε を渡す限り、ここでの集合判定は厳密。
一方、現行 `dc.system` の登録は **witness_validator**
（`specs/checker-semantic-manifest.toml:354-364`）。
整数化から `exact_finite_decision` へ昇格することはできない。
「与えられた状態の4述語の厳密評価」と「基体・測定由来を含む認証」を分け、新規契約の範囲を先に確定する。

更新計算には Int overflow があるため、BigInt または入力範囲と総和上界の検証が必要。
疎行列の重複辺、ゼロ辺、符号、自己辺、W/W_env の合成と加算順も決める。
既存 `PairedInterventionTrial` は Float64 へ変換し（`src/field_bridge.jl:116-141`）、
`estimate_alpha_relation` は absolute/relative tolerance を使う（同:507-523）。
この測定経路の無変更再利用は厳密な Boolean 測定に不適合。provenance 型の再利用とは分ける。
さらに既存 clamp は `retained` を集合にする（同:531-536）ので、草案の「変化する出力」と同型とは未確認。
有限台版 check_DC は hGC を検査しない。全台を渡す ERIEState コンストラクタは別途 hGC を要求するため、
RSB-003 はどちらの契約を使うか明記し、追加条件を暗黙に持ち込まない。

## (d) challenge: digest は内容同一性の検査であり、先後・全件報告を保証しない

§7 の方針を digest に入れるのは必要だが、結果の一部だけの採用、seed/profile のやり直し、
測定後の digest 作成を単独では検知できない。全列挙も「通る/落ちる両方の存在」を保証しない。
また §8 の「全部落ちたら基体棄却」を DC が通るまでの profile 再設計ループに使えば、目的と衝突する。

最小修正案: RSB-001 で内容 digest・schema/正規化版・実行プロトコル版を信頼する記録先へ事前登録し、
RSB-002/003 はその登録済み digest を参照必須にする。canonical な全 case ID、列挙順、
sample の PRNG/版/重複方針、全結果 manifest、欠落・重複・途中停止の扱いを凍結し、全件照合する。
全履歴・全 profile 版を残し、変更理由と再承認を記録する。これが保証できるのは管理対象パイプライン内の順序であり、
記録外の事前探索を hash で禁止できるわけではない。
キーをソートするだけでは配列順、辺表現、serializer 版の意味は決まらない。
§1 の schema/profile ID/正規化規則も digest の domain に結び付け、§8 の判定条件には別の監査用 digest/version を持たせる。

## (e) challenge: 6反証の期待値・契約範囲を修正し、欠落を追加

| 現行項目 | 判定と最小修正 |
|---|---|
| ALL-OFF | challenge。κ=∅ なら hSelf は空集合の包含で **true**。ε=∅ なら hSMC も true、hAct/hBound は false、DC は false（DC.lean:15-18）。初期全offから更新後も全offとは限らず、θ≤0 の自発点灯が許されている。全off窓の述語検査と初期全offの実軌道を分離する。 |
| DISCRIMINATION | challenge。「全通過/全不通過を棄却」は研究上の採否基準であり checker の誤りの反証ではない。全不通過を負の結果として残し、自動調整を起動しない。全off窓を実際に含む場合は全通過も既存DCで不可能。 |
| PROVENANCE | challenge。`src/field_bridge.jl:582-585` は非空・不一致文字列しか検査しない。W由来の関係にも別文字列を付けられる。登録profile/case/介入/対照・介入トレース/抽出器版を結び、再実行と関係再抽出で照合する。これは測定整合性を検査するが、同一結果を生成した者の内的な計算経路の証明ではない。 |
| ISOLATED | accept。指定 neighbors の下で外への辺がなければ boundary=∅、hBound=false。W_env を含めるか固定し、hSelf の偽は要求しない。 |
| PROFILE-DIGEST | accept。期待digestは事前登録記録から得る必要がある。payloadと期待値の両方を差し替えたものを拒否するケースも必要。 |
| DECOUPLING | challenge。k変更は state_window=k+1 と lesion_horizon=2k に波及する。型Sも長さを型に持てば変わる。「コード変更不要」と「データ・型・certificate不変」を区別し、派生項目を再生成してdigestと測定を更新する。 |

追加すべきケース: 台外・重複ユニット/辺/IO違反、overflow/不正閾値、W_env 実際未使用・更新時刻ずれ、
介入優先順位違反、窓長不整合、偽境界の追加/削除、関係改ざん・同タグ再利用・trace不一致、
列挙欠落/重複/seed不一致、凍結前の測定・評価要求の拒否。
4述語は独立に落ちる既存 fixture を参照できる（`test/test_dc.jl:32-50`）。
負の単体fixtureと「この基体に正例がある」という未検証の科学的主張を混ぜない。

## (f) 未決 A〜F の推奨（決定はユーザー）

| ID | 判定 | 推奨・根拠 |
|---|---|---|
| A | accept（候補） | 同期。順序の自由度を減らす。ただし W_env を同じ旧配置から加算するか、入力を上書きするか、遅延とclamp順を先に固定。現在の更新式は W_env を含まない。 |
| B | clarify | v1は閉世界を推奨。外生駆動の自由度を減らす。Wから入力への辺も許す現式と「入力はW_envのみ」が未整合で、許容辺と入力更新を明記。θ≤0による自発点灯は外生駆動と別に扱う。 |
| C | clarify | 最終窓ステップの active input を推奨。現定義はonの入力集合を読むので、実際にW_env経由で受信した事象とは自動的に同一でない。名称・観測対象を確定し、到達可能性に置き換えない。 |
| D | accept（候補） | 無向 in∪out を支持境界の候補として推奨。Leanは任意隣接を許すので有向案も排除しない。W_envの包含は別途決定。 |
| E | clarify | π:M→Set C、ρ:C→Set M の方向を維持し、paired lesionの喪失差分を候補とする。baseline/直接強制脱落/冗長性/状態依存を凍結し、産出との対応は未証明とする。 |
| F | accept（条件付き候補） | 整数＋BigIntまたは検証済み上界。Boolean閾値更新に有理数を必要とする証拠は現時点でない。整数であること自体をoverflow対策としない。 |

追加の凍結必須項目: baseline生成・初期履歴padding/warm-up・観測時刻/期間・介入の強制値と持続期間・
最終値/窓全体/一度でも変化のどれを抽出するか・全caseの関係の集約法。
κのwindowは「k+1点でk遷移を評価」なのかを固定する。Sの長さを実行時検証に置けばコードの一般化は可能だが、
型レベルの長さ依存を使った場合の同一Sは約束できない。

## 検証・作業状態

読取監査と、既存 src のみを include する局所 Julia probe を実行。
probe は PASS（exit 0）。空窓は hSelf=true, hSMC=true, hAct=false, hBound=false、有限台check=false。
Int overflow は typemax(Int)+1=-9223372036854775808 を確認した。
ログ: `logs/reviews/reactivation-profile-v1-probe-20260908.log`。
G1〜G4・パッケージ全テストは未実行。本報告は証明・実装完了や認証昇格を主張しない。
変更はこの報告とprobeログのみ。既存の ledger/test/tools/logs の未コミット分と草案は編集していない。
主判定(a)〜(e): accept 1、challenge 3、clarify 1。候補(f)は各行で分類し、いずれも設計採択ではない。
次はClaudeが上記の最小修正を草案に反映し、A〜Fおよび未確定の測定意味をユーザー判断へ返す。
