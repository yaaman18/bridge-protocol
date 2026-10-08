# RSB-ANALYZE-001 登録した解析を実行する解析プログラムのゲート 2026-10-08

packet: `specs/packets/RSB-ANALYZE-001.md`。実装: `tools/ReactivationERIEC/src/analysis.jl`、CLI `bin/eriec-rsb-analyze.jl`。
登録済み profile では run していない。scratch の run と、その改変コピーだけで試験した。

| ファイル | 内容 |
|---|---|
| `plugin-tests.log` | ReactivationERIEC の試験 476 件、すべて通過（解析の試験を含む） |

## 確かめたこと（`tools/ReactivationERIEC/test/runtests.jl` の `analysis_checks` と照合の testset）

1. 本物の DC・DC2 で行った scratch の run を解析すると `analyzed` になり、DC の通過数、dc_T の通過数、DISCRIMINATION、
   分類の合計、DC2 の通過数が、判定結果のファイルから独立に数え直した値と一致する。同じ入力から同じ報告になる。
2. run の改変コピーで、各規則がそれぞれ発動する:
   完了 manifest を消す・case を1つ消す・結果に欄を足す → `not_analyzed`。
   ALL-OFF（q = 0）の case で DC を真にする、DC 真で境界を空にする（ISOLATED）→ `run_retracted`。
   DC2 真で hSelf を偽にする、DC2 真で beta を空にする → DC2 の記録を撤回。
3. 正解 v4 の対と既知の差分の分類を case 記録だけから計算した結果が、監査側の実装（回路から計算する
   `tools/model_audit/GroundTruth.jl`）と、4 ユニット全列挙と 6 ユニット系列の先頭 4,000 回路で完全に一致する
   （食い違いの分類が実際に起きる回路を含む）。

## 設計上の注意（ユーザー判断事項）

解析プログラムは判定基準と同じ束縛されたパッケージにあるので、tree OID ごと事前登録される。他方、既知の差分の登録簿
（`tools/model_audit/fixtures/dc2-known-differences.toml`）はパッケージの外にあり、報告に SHA-256 を残すだけで、
事前登録では縛られていない。未決の種類をユーザーが決めたときに再登録を要しないためだが、run の後に書き換えうる。

## 追記: 登録前の点検（preflight）

`tools/ReactivationERIEC/src/preflight.jl`、CLI `bin/eriec-rsb-preflight.jl`。読むだけで何も変えない。解析計画 v2 について、
PENDING の残り、schema v2、profile との対、束縛するパッケージの HEAD での tree OID と未コミットの変更、パッケージが実際に
定義する版と結果の欄、依存パスを点検する。試験: 一時 git リポジトリにパッケージを写して通ること、版の食い違い・未コミットの変更・
tree の変化をそれぞれ報告すること（`plugin-tests.log`、480 件通過）。

`preflight-current.out`（2026-10-08 時点の実リポジトリ）:
- 草案そのまま: PENDING と tree OID の空欄だけで止まる。
- 登録予定の値で埋めた一時コピー: 残る問題は「`tools/ReactivationERIEC` の未コミットの変更」と「実際の tree OID の未記入」だけ。
  profile との対、判定基準の版、結果の欄は通る。

