# 証書の射程衛生（相A1）— Stage 2 実装パケット v2（2026-08-30）

状態: **codex challenge（agmsg 5/10）を反映して改訂。再レビュー待ち。**
v1 からの変更: A1 の目的を **scaffold に限定**、`context_id` を A1 から**削除**、
`context_family_conditional` を**削除**、発行経路への fail-closed 配線を追加、
ラチェットを削除、変更可能ファイルを issuer まで拡張。

## この相が establish すること / しないこと（v1 の過剰主張を撤回）

**establish する**: 宣言された `claim_scope` に対する schema 強制と deny-list 強制。
禁止値および欄の省略が、発行経路と検査の両方で棄却されること。

**establish しない**: 「この装置は永続性・最終性を認証しない」。
`claim_scope` は呼び出し側が選ぶラベルであり、実際に永続的な保証を `context_local` と
自己申告すれば通る。deny-list 照合は**列挙値を独立に判定するだけで、主張の意味を独立に判定しない**。
意味の束縛は catalog / guarantee と結ぶ相A2 で行う。

**したがって `FM-CALLER-PROOF-BOOL` は A1 では解消しない。A2 deferred として明記する。**
これは v1 の設計判断の誤りであり、私が書いたサイドカーの緩和策
（「値そのものを固定の禁止集合と照合する」）はラベルを判定するだけで主張を判定しておらず、
当該失敗様式を discharge していなかった。

## 目的・解く問題

MX 第一段（証書の衛生）を、発行経路と検査の両方で機械化する足場を作る。
第二段（射程の語彙 = `context_id`）は本相に**含めない**。
v1 は二つの軸（拒否 / 語彙）と（境界 / 全証書）を混同していた。本相は
**拒否 × 境界**のみを扱う。

## 確認済みの証拠（codex 監査 2026-08-30）

- `certified_artifact_envelope(payload, check)` は 2 引数、repo 内に直接・間接 26 の call site、
  payload に `context_id` は無い（`src/certification.jl:345-363`）。
- **保存済み JSON / JSONL で `artifact_id = erie-c-certified-boundary` または certificate object を
  持つものは 0 件**。したがって後方互換のラチェットは**不要**。
- `tools/verify` の validator と新規 G3 だけでは発行経路を拒否しない。
- `failure_mode_review` の機構は catalog・保証文面・runtime certificate に束縛されない。

## 設計

### enum（v1 から縮小）

```
claim_scope ∈ {
  context_local,                 # 許可（既定）
  permanent,                     # 禁止（表現可能・棄却）
  final,                         # 禁止
  unconditional_cross_context,   # 禁止
}
```

- `claim_scope` は**必須**。省略は違反。
- `context_family_conditional` は **A1 から削除**。family / bridge identifier が無い状態では
  抜け道になるため、識別子が入る相で導入する。
- `context_id` は **A1 に入れない**（相A2）。

### 配線 — fail-closed を発行経路に置く

二重実装を作らない。**判定の core を `src` に置き、tools 側はそれを呼ぶ薄い wrapper とする。**

1. `src/certification.jl` に判定 core（`claim_scope` の妥当性を返す関数）を置く。
2. `certified_artifact_envelope` は禁止値・欠落を**発行前に fail-closed** する。
3. 保存 JSON 入口 `certified_json_artifact_audit` は同じ判定を `ok` に含める。
4. `tools/verify/cert_scope_validation.jl` は core を呼ぶ wrapper。独自判定を持たない。

### 既存 API

`certified_artifact_envelope` の 2 引数呼び出しは維持し、`claim_scope` の既定を
`context_local` とする。26 の call site を書き換えない。**既定値が禁止値になることはない**ため
fail-closed と両立する。

## 実装対象

1. `src/certification.jl` — 判定 core、`certified_artifact_envelope` の fail-closed、
   `certified_json_artifact_audit` の `ok` への組み込み、既定値の付与。
2. `tools/verify/cert_scope_validation.jl` — core を呼ぶ wrapper。
3. `test/test_cert_scope.jl` — 正例と負例 fixture（`test/fixtures/cert_scope/`）。
4. `test/parallel_test_plan.jl` への登録。
5. `src/ERIEC.jl` — 新規公開名がある場合のみ export 追加。

**変更可能ファイルは上記 5 件**（v1 の 4 件制限では実装不能という指摘を反映）。
issuer の call site を書き換える必要が生じた場合は停止して報告すること。

### 安定違反符号（固定名）

- `CERT_SCOPE_MISSING` — `claim_scope` が無い
- `CERT_SCOPE_FORBIDDEN` — `permanent` / `final` / `unconditional_cross_context`
- `CERT_SCOPE_UNKNOWN` — enum に無い値

## 反証条件（**ゲート項目として実行すること**）

1. 負例 fixture ごとに、**期待した違反符号だけ**が返ること。「何らかの失敗」では不可。
2. `claim_scope = permanent` を持つ envelope を**発行しようとすると発行経路が拒否する**こと。
   検査で後から見つけるだけでは不十分。fail-closed の確認である。
3. `claim_scope` を省いた入力が棄却されること（省略が抜け道にならない）。
4. `certified_json_artifact_audit` が禁止値を含む JSON に対して `ok` を返さないこと。
5. 現行の 26 call site を経た発行が違反ゼロで通ること（回帰なし）。

## 禁止変更

- catalog 側（`formal/ERIEC/CertifiedArtifact.lean`、159 行 manifest）。**相A2 の対象**。
- `checker-semantic-manifest` の既存 `scope` の意味変更・流用。
- `context_id` / `weather_id` / `T′` の導入。**相A2**。
- `context_family_conditional` の導入。**識別子が入る相まで保留**。
- `trust` / `execution_boundary` / `trustBoundary` の既存意味の変更。
- 許容誤差・seed・fixture 値・`phenomenal_claim`・`relation` 系。
- 既存テストの合否を変えること。
- 判定の二重実装（tools 側に独自ロジックを置くこと）。
- commit / push。

## ゲート

- **G3**: `tools/quiet-test.sh` 経由で `Pkg.test()`。既存全テスト不変
  （claim ledger 861/861、packet review 19/19）、新規 `test_cert_scope.jl` が正例・負例とも通過。
  ログ `logs/gates/cert-scope/G3-<timestamp>.log`。
- **反証条件 1〜5 を G3 の一部として実行し、出力をログに含めること。**

## 停止条件

- 既存テストの合否が 1 件でも変わったら、回避策を入れず停止して報告。
- 上記 5 件以外の変更が必要になったら停止（issuer call site の書き換えを含む）。
- catalog 側に触れざるを得ないと判明したら停止（相A2）。
- fail-closed が既存の 26 call site のいずれかを壊す場合は停止して報告。
