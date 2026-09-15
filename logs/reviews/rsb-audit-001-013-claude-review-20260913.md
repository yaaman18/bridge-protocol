# RSB-AUDIT-001〜013 読み取りレビュー（Claude）

対象コミット: 12d7be9（基体を凍結する前に有限モデル監査を行う RSB-AUDIT-001〜013 を追加する）
実施: 2026-09-13。読み取りと局所実行のみ。編集・commit・push は行っていない。
除外指定に従い candidate.toml、design-r2.md、tools/experiments/、reactivation-v2 既存ログは
採否対象に含めない。

判定: critical 0 / high 1 / medium 3 / low 3。
全体として、不在を定理へ昇格させない規律は一貫して実装されている。指摘の中心は
「実行されない検査」と「未知を既知として扱う経路」であり、いずれも局所修正で閉じる。

---

## HIGH-1 — 実行されないテストが1件ある（challenge）

`test/parallel_test_plan.jl` に `test_closure_audit.jl` が登録されていない。

`test/runtests.jl` は `parallel_test_runner.jl` のみを include し、そこから
`ERIEC_TEST_PLAN` に列挙されたファイルだけが worker に渡される。他のテストからの
include も無い（`grep -rn closure_audit test/*.jl` の結果は本体ファイル自身のみ）。
したがって **`Pkg.test()` でこのファイルは一度も実行されない**。

再現: `grep -c '"test_closure_audit.jl"' test/parallel_test_plan.jl` → 0。
単体実行では通る: `julia --project=. test/test_closure_audit.jl` →
`observed support is not silently replaced by greatest closure | 38 38`。

コードの欠陥ではなく登録漏れだが、存在するのに実行されない検査は
`specs/verification-failure-modes.toml` が記録する空洞化様式に該当する。

最小修正: `ERIEC_TEST_PLAN` に `("test_closure_audit.jl", 5.0)` 相当を追加する。
併せて、`test/` 直下の `test_*.jl` が計画表に全件載っていることを検査する
テストを1本置くと再発しない。

---

## MEDIUM-1 — 問いの不変性が question 本文だけにしか効いていない（challenge）

`tools/model_audit/Records.jl:115`

```julia
all(e -> e.context.question == c.question, earlier) ||
    throw(ArgumentError("original question text is immutable; use a new question ID"))
```

比較対象が `question` のみで、`definition`・`definition_version`・`observation`・
`subject`・`assumptions` は同じ `question_id` のまま差し替えられる。

再現（実行して確認）: `question_id="q1"` を `:open` で登録したあと、
`definition="全く別の定義"`, `definition_version="v9"`, `observation="別の観測"`,
`subject="別の主題"` に差し替えた context で `:explained` を append すると受理され、
`audit_history_summary` は `unresolved_count=0`・`explained=1` を返す。context が
移動したことを示すフィールドは summary に無い。

これは同ファイルの `compare_audit_claims` と矛盾する。あちらは同じ差分を
`:different_context` と分類し、`test/test_model_audit.jl:22-25` がそれを検査している。
つまり2つの機構が同じ事象について反対の扱いをしている。判定が context 相対で
あることが RSB-AUDIT-001 の主張の前提なので、履歴側だけが緩いのは主張範囲に影響する。

最小修正: `_validate_event` の不変性検査を context 全体へ広げ、変更時は新しい
`question_id`（または `:reformulated` リンク）を要求する。緩めたままにするなら、
`audit_history_summary` に `context_shift_count` のような診断を足し、
`interpretation` の根拠に含める。

---

## MEDIUM-2 — 評価できない結論が「違反なし」に吸収される（challenge）

`tools/ConstraintOverlayAudit.jl:41-42`

```julia
violated = sort!([key for (key, value) in constraint["conclusions"]
                  if haskey(valuation, key) && valuation[key] != value])
```

`valuation` に無い結論キーは黙って読み飛ばされ、違反としても未知としても
記録されない。結果として `classification` は `witness_found` になりうる。

前提側（同:37）は `haskey(...) && ...` により未知なら不適用となり保守的で正しい。
結論側だけが逆に倒れている。

現在の唯一の制約の結論は `hSMC`/`hAct` で、`valuation` は
`fixed_conditions ∪ target["expected"]` により4述語すべてを含むため顕在化しない。
ただし本モジュールは制約カタログを保持する設計であり、`kappa_equals_nu` のような
`expected` 外の述語を結論に持つ制約を1件足した時点で顕在化する。

同じリポジトリ内の対応する箇所は未知を明示している:
`ImplicationMatrixAudit._implication_cell` は `unknown_models` と
`predicate_unobserved_in_context` を、`AssumptionSuiteAudit._target_row` は
`unknown_model_count`/`unknown_models` を出力する。

最小修正: `unknown_conclusions` を集めて行に含め、非空なら
`constraint_conclusion_unobserved` として分類する。

---

## MEDIUM-3 — 落ちることのない交差検査が3か所、うち1か所はテストが別経路を通っている（clarify）

`tools/model_audit/Witnesses.jl:35`

```julia
valid = finite_dc == all(actual)
```

`_finite_encoding_valid` を通過した符号化では `ERIEC.check_DC(sys, M, E, C)` の
台検査はすべて成立するため、この等式は恒真になる。乱択で生成した符号化妥当な
モデル300件で `valid=false` は一度も出なかった。

さらに `test/test_model_audit.jl:122-123`

```julia
bad.pi[:m1] = Set([:outside_carrier])
@test !ModelAudit.check_dc_pattern(bad, (false, true, false, true)).valid
```

は line 35 ではなく **早期 return** を通っている（確認: この呼び出しの戻り値は
`actual == ()`、すなわち `_finite_encoding_valid` が false を返した経路）。
したがって「1引数 check_DC と4引数 check_DC が一致する」という交差検査は
実際には一度も試験されていない。

同型の到達不能な検査が2つある。`tools/model_audit/Search.jl:9`
（`measured.result.valid || error(...)`）と同 `:21`
（`complete.result.actual == pattern || error(...)`）。後者は
`all_interventions` の真偽で `model` が変わらない（`Circuits.jl:98-107` は
mask 0 と singleton しか参照しない）ため、やはり発火しない。

対照的に `tools/BackgroundAudit.jl:22` の
`holds == checker || error("adjunction audit disagrees with the existing checker")`
は、総当り列挙と `ERIEC.check_galois_conn` という**別実装**の突き合わせなので
有効な交差検査である。上の3件はこれとは性質が違う。

最小修正の候補は2つ。(a) 到達不能な3件を削り、`_finite_encoding_valid` に責務を
一本化する。(b) 交差検査を生かすなら、`check_dc_pattern` の早期 return を弱め、
符号化が妥当なケースで両経路の一致を実際に試験するテストを追加する。
どちらを採るかは設計判断なので defer する。少なくとも
`test_model_audit.jl:123` が line 35 を覆っているという読みは撤回すべき。

---

## LOW-1 — `missing` の shadowing（clarify）

`tools/CountermodelAudit.jl:113` のローカル変数名 `missing` が `Base.missing` を
隠す。動作に影響は無いが、同スコープで `missing` を使う変更が入ると壊れる。
`missing_predicates` などへの改名を推奨。

## LOW-2 — `exhaustive_in_declared_domain` の読み違いリスク（clarify）

`tools/model_audit/Search.jl` の `:four_unit_exhaustive` は、
`allowed` 11 辺の部分集合 2^11 × 初期状態 2^4 = 32768 を尽くすが、
**重みは 1 固定、閾値は 1 固定**である。フィールド名に `in_declared_domain` が
付いているので誤りではないが、パケット側に「4ユニット回路全体ではない」ことを
一行書くと読み違いが減る。

## LOW-3 — `nondegenerate` の範囲を明示してほしい（clarify）

`tools/model_audit/Witnesses.jl:33` の N は
`κ≠∅ ∧ κ≠C ∧ ε≠∅` であり、`logs/reviews/reactivation-model-witness-opinion-20260910.md`
が N の候補として挙げた「介入で実際の効果が確認できること」「境界用の無効な飾り辺や
到達不能ユニットだけで通過させないこと」を含まない。

`active_boundary` は別フィールドとして出力され、`CountermodelAudit.QUERY_PREDICATES`
からも照会できるので情報は失われていない。N を最小に保つ設計判断として妥当だが、
パケットに「N は境界の実効性と介入の効力を含まない」と明記してほしい。

---

## 問題を確認できなかった項目（accept）

以下は観点として検査し、指摘に至らなかった。

**観点(2) 不変条項**: `phenomenal_claim` は全出力で `not_certified`。
`:certified` / `"certified"` を代入する箇所は、いずれも拒否されることを要求する
変異ケースだった（`test_model_audit.jl:88`、`test_claim_audit.jl:45` ほか）。
`general_impossibility` は全経路で `not_established`。
`specs/ledger.toml`・`formal/`・`src/` は 12d7be9 で無変更。
Lean 実験を `formal/` ではなく `formal-experiments/` に置いた判断は、
証明済みツリーと certificate catalog の対応を壊さない点で妥当。

**観点(4) HTML**: `tools/AuditViewer.jl` は DOM を `createElement` /
`createElementNS` と `textContent` で構築し、`innerHTML` を使っていない。
データは base64 → `atob` → `TextDecoder` → `JSON.parse` を経由するため、
値から HTML への注入経路が無い。base64 の文字集合に引用符と逆スラッシュが
含まれないので、`atob('$encoded')` の JS 文字列リテラルからも脱出できない。
CSP は `default-src 'none'` と `connect-src 'none'`、`object-src 'none'` を宣言。
`script-src 'unsafe-inline'` は単一ファイル成果物では避けられないので、
**安全性は CSP ではなく innerHTML 不使用に依っている**旨をパケットに書くと良い。

**観点(3) 実装**: 整数 overflow は `Circuits.jl:40-43` の BigInt 上界検査と
`Witnesses.jl:66` の `Base.Checked.checked_add` で二重に塞がれている。
`minimal_loss_masks` の部分集合列挙は 0 を含めて正しい。
`_audit_digest` の単射性について、`Dict("a"=>Dict("b"=>1))` と `Dict("a.b"=>1)` は
TOML 出力が `[a]\nb = 1\n` と `"a.b" = 1\n` に分かれ、digest も異なる（実行確認）。
`verify_measurement_report` / `verify_search_report` が保存値を信用せず再計算して
digest 比較する設計は妥当。

**観点(5) 依存と include**: `Base64` が `[compat]` に無いのは
`LinearAlgebra`/`Random`/`SHA`/`TOML` と同じ既存の扱いであり、逸脱ではない。
include 連鎖は健全で、`ClosureAudit.jl:2` が `BackgroundAudit.jl` を取り込むため
`CountermodelAudit.jl` は単独プロセスでもロードできる（新規プロセスで確認、
`finite_model_catalog()` が 13 モデルを返す）。
`parallel_test_worker.jl` は複数ファイルを同一モジュールへ include するので、
各テスト冒頭の `isdefined(@__MODULE__, :X) ||` ガードは実際に機能している。

**観点(1) 定義**: 不在の扱いは
`:counterexample_found` / `:not_found_in_finite_catalog` /
`:premise_uninstantiated_in_finite_catalog` / `:predicate_unobserved_in_context`
の4値で分離され、未知述語を持つモデルは eligible から除外したうえで
`unknown` として報告される。`implication_proved=false` が全経路で保持されている。
`ρ(m) = π(m) ∩ M` は `Circuits.jl:104-105` がどちらも `losses[singleton(m)]` から
作るため構成上成立しており、9/9 の追加レビューで挙げられた整合条件を満たす。

---

## 既知の未達（codex 申告済み・追認）

RSB-AUDIT-013 追加後に全体 `Pkg.test()` は再実行されていない。
引用されている `logs/gates/quiet/test-20260911-233933-17698.log.a2XgQM` は
013 追加前の実行である。HIGH-1 の登録漏れを直すと計画表が変わるため、
どのみち全体再実行が必要になる。
