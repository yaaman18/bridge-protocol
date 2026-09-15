# RSB-AUDIT-001 — 問いの履歴と有限モデル監査

2026-09-10、ユーザー依頼による第一実装単位。工程IDであり、新規certified VPの予約ではない。
参照: specs/drafts/reactivation-substrate-v1-design.md §12、同design-r2.md。

対象宣言（既存・無変更）:
ERIEC.DC、ERIEC.Closure.Phi、ERIEC.Hinge.Act、ERIEC.FieldBridge.PeriodicBoundaryWitness。
WagerのPh解釈の可変性は監査記録の限界説明に用い、新たな非導出定理を主張しない。

変更可能:
- specs/drafts/reactivation-substrate-v1-design.md（手法追記）
- specs/packets/RSB-AUDIT-001.md（本packet）
- tools/ModelAudit.jl、tools/model_audit/Records.jl、tools/model_audit/Witnesses.jl
- bin/eriec-model-audit.jl
- test/test_model_audit.jl、test/parallel_test_plan.jl
- logs/gates/RSB-AUDIT-001/（実行証拠）

直接依存: Julia標準TOML/SHA、既存ERIEC.ERIEState/check_DC。
固定するtool API: ModelAudit.AuditContext、append_audit_event、audit_history_toml、
parse_audit_history、compare_audit_claims、audit_history_summary、
check_dc_pattern、model_witness_report、invariant_choices。
正式package export、Lean宣言、contract_idの追加は行わない。

禁止変更: formal/、src/、既存certified API、catalog、台帳status、数値候補、
phenomenal marker、対象層公理、既存の数値許容誤差。Claudeへの連絡を行わない。

実装の意味:
- 各contextはquestion ID/原文、定義版/内容、前提、観測対応、対象を持つ不変値。
  履歴中の同IDへの文脈変更はdesign §12のconditional等で許す。
  summary/CLIのcontext_shiftsに直前の同ID eventからの変更項目・sequence・前後の値を記録する。
  context_shift_countは変更遷移の数であり、元の文脈へ戻る遷移も数える。
  unresolved_countは最新statusの集計であり、元の文脈での解決を意味しない。
- 証拠参照は不透明な文字列。ファイル読取・コード実行・ネットワーク要求を起動しない。
- TOMLはデータとして厳格に検査し、未知キー/不正status/切れたdigest鎖を拒否。
- 履歴はimmutable tupleの追加で返す。receiptを指定すれば切り詰めも拒否する。
- 残余の全状態は記録された申告であり、その真理や経験の有無を認証しない。
- DCの全4真偽値を既存関数で再計算し、期待patternと完全一致させる。
  1引数/4引数checker間の一致はAPI整合の検査で、独立した意味検証ではない。
  nondegenerateはκ≠∅ ∧ κ≠C ∧ ε≠∅だけを表し、境界や介入の実効性を含まない。
  active_boundaryは別診断として扱う。
- 抽象モデルと改訂2方式で測定した小モデルを区別し、独立性の範囲を混同しない。

検証:
G1: 既存Lean全体のquiet-build（利用する定義のbaseline）。新規証明はない。
G2: 既存Lean–Julia contract test（利用する接続のbaseline）。toolに新bindingはない。
対象G3: 履歴roundtrip/切詰め/書換え/未知キー、contextの取り違え、全条件/各条件分離、
測定由来の全条件証人、対称選択不可の小モデル、CLIの入出力を検査。
全体G3: 既存parallel test planに登録して全テスト。
G4: 新しいcertified宣言を付与せず、既存dc.systemのcatalog/scopeと接続を確認する。
G1/G2/G4のbaseline成功を、toolやモデルの新規理論認証として報告しない。
台帳のstatusは変更しない。

実行結果（2026-09-10）: 第一実装単位は完了。
G1、G2（1317件）、対象G3（74件）、全体Pkg.test()、G4 baseline（8件）が通過。
初回失敗と修正後の成功は分けて `logs/gates/RSB-AUDIT-001/README.md` に記録した。
測定由来の各条件分離モデルとM1〜M4全体の適合性は、この完了範囲に含めない。
