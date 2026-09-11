# RSB-AUDIT-007 — M2を保つ測定分離の明示構成

2026-09-10、継続実装の第七単位。新規certified VPではない。
許可範囲: 本packet、specs/drafts/reactivation-substrate-v1-design.md、tools/model_audit/Circuits.jl、
tools/BackgroundAudit.jl、tools/background_audit/MeasuredWitnesses.jl、bin/eriec-background-audit.jl、
test/test_measured_adjunction_separation.jl、test/parallel_test_plan.jl、logs/gates/RSB-AUDIT-007/、
logs/gates/RSB-AUDIT-002/README.md（資源上限の更新注記）。
直接依存: ModelAuditの発信停止測定、BackgroundAuditの全有限随伴検査。
固定API: BackgroundAudit.adjoint_measured_witnesses、adjoint_measured_witness_report。

背景をP=3、H=6、L=R=4、二入力・二出力へ明示的に固定する。
RSB-AUDIT-006のP=6探索とは異なるcontextであり、その探索域での独立性を主張しない。
全条件/hSelf/hBoundの3例は二帰還対から構成する。
hSMC例は、出力の周期4の活動と最終点との差を使い、εにα像外の入力を含める。
hAct例は、初期の支持維持から遅れて立ち上がる帰還へ切り替え、
支持側の出力と分岐時の入力が応答させる出力を別々にする。
いずれも関係表を直接編集せず、全停止集合からπ/ρ/α/σを生成する。

hAct候補には11ユニットを要するため、汎用監査器の資源上限だけを10→12へ拡張する。
これは既存の認証済み数値条件、8ユニット候補、観測定義、P/H/L/Rを変更するものではない。
最大分岐数4096。極小喪失集合の全真部分集合比較も同じ12ユニット上限で保護する。
対称性の完全列挙上限8、M/Eの随伴検査上限10は変更しない。

対象G3: 全5patternのM2・DC・非退化・有効境界・全停止集合を検査。
回路入力の12境界/13拒否、時間窓と入力の原文保持、旧測定器/探索の回帰を検査。
既存G1/G2/G4接続は無変更。対象層・src/・ledger・catalog・candidateは変更しない。

統合時の追加範囲: test/test_background_audit.jlのinclude guard。
新suiteとの同一worker実行でBackgroundAuditを再定義しないため。
保存した全介入traceはlogs内のPython独立実装でも照合し、Julia本体と同じ更新ループをコピーしない。
