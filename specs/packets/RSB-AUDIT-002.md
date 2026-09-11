# RSB-AUDIT-002 — 測定モデル探索と再現

2026-09-10、継続実装の第二単位。新規certified VPではない。
対象宣言は既存ERIEC.DC、ERIEC.Closure.Phi、ERIEC.Hinge.Act（無変更）。
直接依存はModelAuditの既存checker adapter、Julia標準TOML/SHA。

変更可能: 本packet、specs/drafts/reactivation-substrate-v1-design.md、
tools/ModelAudit.jl、tools/model_audit/{Circuits,Search}.jl、
bin/eriec-model-audit.jl、test/test_model_audit_circuits.jl、test/parallel_test_plan.jl、
logs/gates/RSB-AUDIT-002/。
既存Witnesses.jlの6ユニットfixtureは独立した照合先として保持する。

固定tool API: AuditCircuit、measure_circuit、circuit_dict、parse_audit_circuit、
minimal_loss_masks、search_measured_models、measured_search_report。
禁止変更: formal/、src/、catalog、ledger、candidate、数値許容誤差、対象層公理、phenomenal marker。

測定規約: 改訂2の同期閾値更新、発信停止、P=H=6/L=R=4を探索で固定。
汎用入力はP/H/L/Rを明示し、制約を検証する。自己辺・重複辺・ゼロ辺を拒否し、
入力Eへの辺は出力Mからだけとする。Int64 checked加算とBigIntでの上界検証。
探索中は対照+全単独停止を使用。保存する証人は全2^N分岐を再実行し、既存checkerで全4条件を照合。
複数停止の極小喪失集合は全真部分集合と比較し、単項関係に書き戻さない。

第一探索域: 4ユニット、E={u1},M={u3,u4}、残り内部、自己辺なし、
Eへの辺はMからのみ、各許容辺の有無を全列挙、全重み/閾値1、全16初期配置。
許容辺11本、2048回路×16初期配置=32768ケース。P=H=6/L=R=4。
この域での未発見は当該有限域の結果に限る。
第二探索域: 6ユニット、E={u1},M={u5,u6}、許容辺の重みを{-1,0,1}、閾値{1,2}、
初期配置を固定LCG列から生成する探索。seed=20260910、試行数20000、途中成功で打ち切らない。
列挙域の網羅性も一般的不可能性も主張しない。探索で選んだモデルは探索的証人として記録する。

検証: RSB-AUDIT-001のG1/G2/G4 baselineを利用（依存とbindingに変更なし）。
対象G3は独立Boolean式との全配置・全停止の一致、既存6ユニット例との一致、
入力境界・overflow・不正窓・偽りの網羅性を拒否、極小喪失集合、探索候補の再測定。
全体G3は完成時に実行。ゲート状態は変更しない。

探索後の追加範囲: tools/model_audit/fixtures/measured-witnesses.toml。
依存理由は、発見した全条件/各条件分離の測定モデルを探索ログの可変な場所から切り離して
回帰テストと再測定CLIで共有するため。期待patternと由来domain/case_idを固定し、
結果に合わせた関係の手編集はしない。
追加tool API: verify_measurement_report、verify_search_report、measured_witness_corpus。
再検証では保存されたtraceやcoverage申告を信用せず、入力回路または探索域から再計算する。
