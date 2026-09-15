# RSB-AUDIT-009 — 回路・介入・時間のローカル閲覧

2026-09-10、測定結果を具体的にレビューするための自己完結HTML。
許可範囲: 本packet、specs/drafts/reactivation-substrate-v1-design.md、logs/gates/RSB-AUDIT-009/、
logs/reviews/reactivation-model-audit-viewer.html、tools/AuditViewer.jl、
test/test_model_audit_viewer.jl、test/parallel_test_plan.jl。
直接依存: BackgroundAuditのP3測定5例、ClosureAuditの支持拡張例、保存済みの対称合併例。
正式API・対象層・src/・ledger・catalog・candidate・既存数値条件は変更しない。

全介入traceを再計算してから、状態を整数bit maskとしてHTMLに埋め込む。
モデル、停止集合、時刻を切り替え、自然対照との差と分岐時のK/将来Q/νΦを区別して表示する。
DCとM2の値は、そのcaseの全測定から算出した値。表示中の単一branchの新たな認証値として扱わない。
図の座標は説明用で物理空間・分解Dではない。ノード位置を動かして対象の定義を変更しない。
ネットワーク要求・外部script・コードevalを使わず、埋込み文字列はHTML/scriptとして解釈させない。
検証: 埋込データのcase/分岐数と元測定の一致、JavaScript構文、可能ならヘッドレス画面操作。
レビュー用artifactであり、証明・認証台帳の状態を進めない。

固定tool API: AuditViewer.audit_viewer_data、render_audit_viewer、write_audit_viewer。
HTMLのContent-Security-Policyは外部resourceと通信を拒否し、script/styleは自己完結したinlineだけを許す。
埋込JSONはBase64化し、動的文字列はtextContent/SVG text nodeで表示する。
文字列注入への防御はBase64埋込みとinnerHTMLを使わないDOM構築による。
inline scriptを許すCSP自体を、埋込み文字列注入を防ぐ根拠にはしない。

全体G3統合時の追加範囲: `Project.toml` と `Manifest.toml`。閲覧モジュールが直接使う
Julia標準ライブラリBase64をpackageの直接依存に加える。通常projectでの対象テストは通ったが、
隔離された`Pkg.test()`環境が未宣言依存を拒否したため。外部packageやversion変更は加えない。
