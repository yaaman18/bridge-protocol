# RSB-AUDIT-REVIEW-001 再レビュー（Claude）

対象: HEAD 12d7be9 に対する未コミット差分17ファイル。
基準: logs/reviews/rsb-audit-review-fixes-20260913.patch
（SHA-256 d31c835b3d0b399d60528f888cae4e7498edee2ebed6b318128f2338c9ea8f29、手元で一致を確認）。
実施: 2026-09-13。読み取りと局所実行のみ。編集・commit・push は行っていない。
元レビュー: logs/reviews/rsb-audit-001-013-claude-review-20260913.md。

判定: critical 0 / high 0 / medium 0 / low 2。
**元レビューの HIGH-1・MEDIUM-1〜3・LOW-1〜3 はすべて解消または妥当に改訂されている。**
残る2件はいずれも新規の低優先度で、修正が壊したものではない。

---

## 手元で再現した検証

| 対象 | 結果 |
|---|---|
| test/test_test_plan.jl | 6/6、exit 0 |
| test/test_closure_audit.jl | 38/38、exit 0 |
| test/test_constraint_overlay_audit.jl | 46/46、exit 0 |
| test/test_model_audit.jl | 88/88、12289/12289、32/32、exit 0 |
| test/test_model_audit_circuits.jl | 8241/8241、16/16、33/33、exit 0 |

全体 `Pkg.test()` は約13分を要するため**再実行していない**。
logs/gates/RSB-AUDIT-REVIEW-001/G3-full.log の内容は確認した: 末尾 `Testing ERIEC tests passed`、
Test Summary 91件、`observed support is not silently replaced by greatest closure | 38 38` と
`test discovery is checked before scheduling | 6 6` を含む。

修正前の失敗ログ（G3-records-before.log、G3-overlay-before.log）も確認した。
それぞれ `type NamedTuple has no field context_shift_count`、
`KeyError: key "constraint_check_complete" not found` で error になっており、
新しいテストが修正前のコードに対して落ちることが示されている。

不変条項: `git status` で formal/・src/・specs/ledger.toml・Project.toml・Manifest.toml は
無変更。diff 全体に phenomenal / tol / threshold / seed の変更行は無い。

---

## 元指摘ごとの判定

### HIGH-1（テスト未登録）— accept、解消

`test_closure_audit.jl` が計画表に入り、`validate_eriec_test_plan` が
`run_eriec_tests()` の先頭で呼ばれる。`test/` 直下の `test_*.jl` を `readdir` で発見し、
登録漏れ・重複・存在しない登録を worker 起動前に拒否する。
`test_test_plan.jl` は一時ディレクトリで3種の拒否経路を検査し、
`validate()`（実際の計画表と実際のディレクトリ）も通している。
全体ログに ClosureAudit 38/38 が現れることで、通常の `Pkg.test` 経路での解消を確認した。

### MEDIUM-1（問いの不変性）— accept、改訂は妥当

私の最小修正案（context 全体を不変にする）は採用されず、診断の追加で対応された。
改訂の根拠として挙げられた2点を確認した:
- `test/test_model_audit.jl:61-62`（修正前から存在）は、`assumptions=()` で `:open` にした
  同一 ID へ `assumptions=("A",)` の context で `:conditional` を append している。
- `specs/drafts/reactivation-substrate-v1-design.md:245` は「conditionalは追加前提」と定める。
したがって context 全体の固定は既存の `:conditional` 遷移を壊す。改訂のほうが正しい。

診断の動作を手元の probe で確認した:
- 同一 ID で definition/definition_version/observation/subject を差し替えて `:explained` →
  `context_shift_count=1`、`changed_fields=[definition_version, definition, observation, subject]`。
- 元の context へ戻す（A→B→A）→ `context_shift_count=2`。復帰も遷移として数える。
- 既存の conditional 経路（assumptions 追加のみ）→ `context_shift_count=1`、
  `changed_fields=["assumptions"]`。テストもこれを明示的に表明する（同:86）。
- `bin/eriec-model-audit.jl check-history` が `context_shift_count` と `context_shifts` を出力する。

元レビューで問題にしたのは「2つの機構が同じ事象を反対に扱う」ことだった。改訂後は、
履歴側は**許可して記録**し、`compare_audit_claims` は**分類**する。答える問いが違うので
矛盾ではない。パケットの「unresolved_countは最新statusの集計であり、元の文脈での解決を
意味しない」という明記で、私が懸念した誤読経路は閉じている。

### MEDIUM-2（未知の結論）— accept、残余1件は LOW-A

`unknown_conclusions`（制約 ID・未指定キー・Lean 宣言）と `constraint_check_complete` が
行単位で追加された。分類は既存のまま保持し、未知診断と既知 conflict を併記する設計。
テストは status × violates の4組合せで `constraint_check_complete=false` と分類の保持を検査し、
前提不明の非適用制約では `unknown_conclusions` が空で `constraint_check_complete=true`
（適用済み制約に限る診断であること）も検査している。CLI 出力も確認された。

### MEDIUM-3（到達不能な交差検査）— accept、残余1件は LOW-B

対応は3層になっている。
1. `Witnesses.jl:35` の `valid` は保持し、「API 整合の検査であり独立な意味検証ではない」と
   コード・パケット双方に明記。`test_model_audit.jl:182-183` は `actual == ()` を追加で表明し、
   早期拒否経路であることを明示した。元レビューで指摘した「line 35 を覆っているという読み」は
   撤回されている。
2. **独立な述語計算の追加**（同 `DC predicates match direct quantifiers on all tiny encodings`）。
   C={e,m,c}、M={m}、E={e} の上で alpha/sigma/pi/rho/κ/ε の全 4096 通りを列挙し、
   `in`・`any`・`all` だけで書いた参照式と `check_dc_pattern` を比較する。参照式を確認した:
   - hSelf: ∀c∈κ, ∃m∈M, c∈π(m) ∧ ∃d∈κ, m∈ρ(d) — これは κ ⊆ π⋆(ρ⋆(κ)) の展開と一致
   - hSMC: ∀e∈ε, ∃m∈M, e∈α(m) ∧ ∃d∈ε, m∈σ(d) — ε ⊆ α⋆(σ⋆(ε)) と一致
   - hAct: ∃m∈M, (∃d∈κ, m∈ρ(d)) ∧ (∃e∈ε, m∈σ(e)) — Act≠∅ と一致。Act 集合そのものも照合
   - hBound: ∃c∈κ, ∃n∈neighbors(c), n∉κ — check_dc_pattern の boundary 導出と一致
   κ=∅ で hSelf が空包含により真、hAct が偽になる挙動も参照式が忠実に再現する。
   ERIEC の星印演算子・Φ・T′・Act を一切使っていないので、これは本物の独立検証である。
   `matches == (κ≠∅ ∧ κ≠C ∧ ε≠∅)` の表明は LOW-3 の nondegenerate 定義も同時に固定している。
3. `Search.jl` の自明な `actual == pattern` は `_check_search_replay` に置き換わり、
   prefix/anchor/baseline/model/actual/active_boundary/共有 trace/loss を照合する。
   これも同一実装の再実行整合であることはコメントとパケットに明記されている。
   到達不能な検査を「実際に落とす」ために、改変した trace/loss/actual を渡して
   拒否経路を直接検査するテストが追加された（`test_model_audit_circuits.jl:24-32`）。
   自然には発火しないガードの正しい検査方法である。

### LOW-1〜3、viewer 補足 — accept

`missing` → `missing_predicates`。パケットに「4ユニット回路全体ではない」、
nondegenerate の範囲、CSP ではなく innerHTML 不使用が防御である旨、いずれも追記を確認。

---

## 新規の所見（いずれも LOW、今回の修正が原因ではない）

### LOW-A — `constraint_overlay_report` にトップレベル集計が無い（clarify）

`tools/ConstraintOverlayAudit.jl` の `constraint_overlay_report` は `conflict_count` を出すが、
`constraint_check_complete=false` の行数を集計するフィールドが無い。
現在は全15行が complete なので顕在化しないが、将来 incomplete な行が1件生じたとき、
TOML の先頭だけを読む利用者は `conflict_count=0` を見て検査完了と誤読しうる。
最小修正: `"incomplete_check_count"=>count(row -> !row["constraint_check_complete"], rows)` を
report に追加し、テストで 0 を表明する。

### LOW-B — 4096 通り検査の neighbors が完全グラフ固定（clarify）

`test_model_audit.jl` の新テストは `neighbors = {c ↦ C∖{c}}` で固定している。
このとき boundary = κ（κ≠C のとき）または ∅（κ=C のとき）となり、
hBound は `κ≠∅ ∧ κ≠C` に退化する。参照式自体は正しいが、この fixture では
**neighbors を無視して κ の真部分集合性だけを見る実装**と区別がつかない。
境界の導出は circuits 側のテストが実グラフで検査しているので欠陥ではないが、
このテストの hBound 被覆は他の3述語より薄い。
最小修正: neighbors を非完全グラフ（例: e→m→c の鎖）にした第2 fixture を同じ列挙で回すか、
neighbors を数ビット分だけ列挙に含める。

---

## 結論

元レビューの指摘はすべて閉じている。改訂が入った MEDIUM-1 と MEDIUM-3 は、
私の最小修正案より改訂案のほうが既存の仕様（design §12、conditional 遷移）と整合する。
残る LOW-A / LOW-B は今回の修正の副作用ではなく、次の機会でよい。

台帳 status の移動は無く、パケットも「新規certified VPではなく、ledgerのstatusを動かさない」と
明記している。全体 Pkg.test の再実行は codex のログの確認にとどめ、私は行っていない。
