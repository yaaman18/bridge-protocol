# 圏論更新・影響レポート

- 変更節: §16, §19
- 削除節: なし
- 直接影響VP: VP-ADJ-001, VP-ADJ-002, VP-AUD-001, VP-BDY-001, VP-CER-001, VP-CLO-001, VP-CLP-001, VP-DC-001, VP-DEC-001, VP-DYN-001, VP-GEN-001, VP-GEN-002, VP-GEN-003, VP-GEN-004, VP-GEN-005, VP-GEN-006, VP-GRA-001, VP-GRA-002, VP-GRD-001, VP-GUA-001, VP-HNG-001, VP-INV-001, VP-KT-001, VP-LIN-001, VP-M1-001, VP-M1-FULL-001a, VP-M1-FULL-001b, VP-META-001, VP-META-002, VP-META-003, VP-META-004, VP-META-005, VP-MRK-001, VP-OPD-001, VP-REF-001, VP-RICH-001, VP-RICH-002, VP-SEN-001, VP-SEN-002, VP-TMP-001, VP-TMP-002, VP-TMP-003, VP-TMP-004, VP-TMP-005, VP-TTR-001, VP-VAL-002, VP-WDC-001, VP-WDC-002, VP-WGR-001, VP-WGR-002, VP-WGR-003, VP-WGR-004, VP-WGR-005, VP-WGR-006, VP-WGR-007, VP-WGR-008, VP-WGR-009, VP-WLD-001, VP-WLD-002
- 依存閉包VP: VP-ADJ-001, VP-ADJ-002, VP-AUD-001, VP-BDY-001, VP-CER-001, VP-CLO-001, VP-CLP-001, VP-DC-001, VP-DEC-001, VP-DYN-001, VP-GEN-001, VP-GEN-002, VP-GEN-003, VP-GEN-004, VP-GEN-005, VP-GEN-006, VP-GRA-001, VP-GRA-002, VP-GRD-001, VP-GUA-001, VP-HNG-001, VP-INV-001, VP-KT-001, VP-LIN-001, VP-M1-001, VP-M1-FULL-001a, VP-M1-FULL-001b, VP-META-001, VP-META-002, VP-META-003, VP-META-004, VP-META-005, VP-MRK-001, VP-OPD-001, VP-REF-001, VP-RICH-001, VP-RICH-002, VP-SEN-001, VP-SEN-002, VP-TMP-001, VP-TMP-002, VP-TMP-003, VP-TMP-004, VP-TMP-005, VP-TTR-001, VP-VAL-002, VP-WDC-001, VP-WDC-002, VP-WGR-001, VP-WGR-002, VP-WGR-003, VP-WGR-004, VP-WGR-005, VP-WGR-006, VP-WGR-007, VP-WGR-008, VP-WGR-009, VP-WLD-001, VP-WLD-002
- 台帳起票が必要な節: なし

## 更新対象

| VP | Lean | Julia | status | coverage |
|---|---|---|---|---|
| VP-ADJ-001 | `formal/ERIEC/Adjunction.lean` / `ERIEC.Adj.galoisConn_induced` | `src/adjunction.jl` / `check_galois_conn` | `certified` | unreviewed |
| VP-ADJ-002 | `formal/ERIEC/Adjunction.lean` / `ERIEC.Adj.rigidity_of_gc` | `src/adjunction.jl` / `check_relational_rigidity` | `certified` | unreviewed |
| VP-AUD-001 | `formal/ERIEC/Audit.lean` / `ERIEC.Audit.Simulation` | `src/audit.jl` / `FiniteSimulation` | `certified` | unreviewed |
| VP-BDY-001 | `formal/ERIEC/Body.lean` / `ERIEC.Body.NoTerminalSetPoint` | `src/body.jl` / `check_m4_no_terminal_setpoint` | `certified` | unreviewed |
| VP-CER-001 | `formal/ERIEC/DC.lean` / `ERIEC.DC.crit_bound` | `src/dc.jl` / `check_critical_bound` | `certified` | unreviewed |
| VP-CLO-001 | `formal/ERIEC/Closure.lean` / `ERIEC.Closure.NuPhi` | `src/closure.jl` / `check_nu_phi_fixedpoint` | `certified` | unreviewed |
| VP-CLP-001 | `formal/ERIEC/Collapse.lean` / `ERIEC.Collapse.hingeCollapse` | `src/slowing.jl` / `critical_slowing_score` | `certified` | unreviewed |
| VP-DC-001 | `formal/ERIEC/DC.lean` / `ERIEC.DC` | `src/dc.jl` / `check_DC` | `certified` | unreviewed |
| VP-DEC-001 | `formal/ERIEC/Decomp.lean` / `ERIEC.Decomp.copair_unique` | `src/decomp.jl` / `check_copair_unique` | `certified` | unreviewed |
| VP-DYN-001 | `formal/ERIEC/Dynamics.lean` / `ERIEC.Dynamics.collapse` | `src/dynamics.jl` / `check_finite_collapse` | `certified` | unreviewed |
| VP-GEN-001 | `formal/ERIEC/Generation.lean` / `ERIEC.Generation.dcViableTranslation` | `src/generation.jl` / `check_dc_viable_translation` | `certified` | unreviewed |
| VP-GEN-002 | `formal/ERIEC/Generation.lean` / `ERIEC.Generation.ProliferationMorphism` | `src/generation.jl` / `check_proliferation_morphism` | `certified` | unreviewed |
| VP-GEN-003 | `formal/ERIEC/Generation.lean` / `ERIEC.Generation.lineage_stays_open` | `src/generation.jl` / `check_lineage_stays_open` | `certified` | unreviewed |
| VP-GEN-004 | `formal/ERIEC/Generation.lean` / `ERIEC.Generation.richness_inherits_generational` | `src/generation.jl` / `check_richness_inherits_generational` | `certified` | unreviewed |
| VP-GEN-005 | `formal/ERIEC/RefModel/LineageWitness.lean` / `ERIEC.RefModel.rich_lineage_reference_model` | `src/generation.jl` / `check_rich_lineage_cofinal` | `certified` | unreviewed |
| VP-GEN-006 | `formal/ERIEC/RefModel/LineageWitness.lean` / `ERIEC.RefModel.branched_rich_lineage_reference_model` | `src/generation.jl` / `check_branched_rich_lineage_cofinal` | `certified` | unreviewed |
| VP-GRA-001 | `formal/ERIEC/Grading.lean` / `ERIEC.Grading.constPresheaf_iff_antitone` | `src/grading.jl` / `check_const_presheaf_antitone` | `certified` | unreviewed |
| VP-GRA-002 | `formal/ERIEC/Grading.lean` / `ERIEC.Grading.nuPhi_empty_above` | `src/grading.jl` / `check_sig2_collapse_bound` | `certified` | unreviewed |
| VP-GRD-001 | `formal/ERIEC/Graded.lean` / `ERIEC.Graded.PresheafTransitionCoproduct` | `src/graded.jl` / `check_presheaf_transition_coproduct` | `certified` | unreviewed |
| VP-GUA-001 | `formal/ERIEC/Guard.lean` / `ERIEC.Guard.hasTStar_iff_terminal` | `src/guard.jl` / `check_terminal_guard` | `certified` | unreviewed |
| VP-HNG-001 | `formal/ERIEC/Hinge.lean` / `ERIEC.Hinge.Act` | `src/hinge.jl` / `check_hinge` | `certified` | unreviewed |
| VP-INV-001 | `formal/ERIEC/Invariance.lean` / `ERIEC.Invariance.upd_bisim` | `src/invariance.jl` / `check_update_bisimulation` | `certified` | unreviewed |
| VP-KT-001 | `formal/ERIEC/Closure.lean` / `ERIEC.Closure.finalCoalgebra` | `src/closure.jl` / `check_final_coalgebra` | `certified` | unreviewed |
| VP-LIN-001 | `formal/ERIEC/Lineage.lean` / `ERIEC.OpenEvolution.Lineage` | `src/lineage.jl` / `FiniteLineage` | `certified` | unreviewed |
| VP-M1-001 | `formal/ERIEC/RefModel/Large.lean` / `ERIEC.RefModel.arbitrarily_large_nondegenerate_dc` | `src/reference_models.jl` / `check_arbitrarily_large_nondegenerate_models` | `certified` | unreviewed |
| VP-M1-FULL-001a | `formal/ERIEC/RefModel/LargeCore.lean` / `ERIEC.RefModel.arbitrarily_large_ax_core_discrete_model` | `src/reference_models.jl` / `check_arbitrarily_large_ax_core_discrete_models` | `certified` | unreviewed |
| VP-M1-FULL-001b | `formal/ERIEC/RefModel/LargeCore.lean` / `ERIEC.RefModel.arbitrarily_large_three_layer_reference_model` | `src/reference_models.jl` / `check_arbitrarily_large_three_layer_reference_models` | `certified` | unreviewed |
| VP-META-001 | `formal/ERIEC/MetaSelection.lean` / `ERIEC.MetaSelection.m4_preserved_of_sigmaPure` | `src/sigma_selection.jl` / `check_sigma_purity` | `certified` | unreviewed |
| VP-META-002 | `formal/ERIEC/MetaSelection.lean` / `ERIEC.MetaSelection.SigmaPure` | `src/sigma_selection.jl` / `check_selection_nondegenerate` | `certified` | unreviewed |
| VP-META-003 | `formal/ERIEC/MetaSelection.lean` / `ERIEC.MetaSelection.trace_preserved_of_sigmaPure` | `src/sigma_selection.jl` / `run_sigma1_experiment` | `certified` | unreviewed |
| VP-META-004 | `formal/ERIEC/MetaSelection.lean` / `ERIEC.MetaSelection.M4SafeMutation` | `src/sigma1_run.jl` / `sigma1_observe_candidate` | `certified` | unreviewed |
| VP-META-005 | `formal/ERIEC/MetaSelection.lean` / `ERIEC.MetaSelection.DiversityAuditPure` | `src/sigma1_diversity_audit.jl` / `check_sigma1_diversity_resolution` | `certified` | unreviewed |
| VP-MRK-001 | `formal/ERIEC/Markers.lean` / `ERIEC.Markers.FMMarkers` | `src/markers.jl` / `classify_action_markers` | `certified` | unreviewed |
| VP-OPD-001 | `formal/ERIEC/OpenDynamics.lean` / `ERIEC.OpenDynamics.OpenGraph` | `src/open_dynamics.jl` / `FiniteOpenGraph` | `certified` | unreviewed |
| VP-REF-001 | `formal/ERIEC/RefModel.lean` / `ERIEC.RefModel.reference_models` | `src/reference_models.jl` / `check_reference_models` | `certified` | unreviewed |
| VP-RICH-001 | `formal/ERIEC/Richness.lean` / `ERIEC.Richness.Branch` | `src/richness.jl` / `is_branch_point` | `certified` | unreviewed |
| VP-RICH-002 | `formal/ERIEC/Richness.lean` / `ERIEC.Richness.hinge_branch_pump` | `src/richness.jl` / `check_hinge_branch_pump` | `certified` | unreviewed |
| VP-SEN-001 | `formal/ERIEC/Sensitivity.lean` / `ERIEC.Sens.dualSymmetry` | `src/sensitivity.jl` / `check_dual_symmetry` | `certified` | unreviewed |
| VP-SEN-002 | `formal/ERIEC/Sensitivity.lean` / `ERIEC.Sens.not_id_le_adjoint_comp` | `src/sensitivity.jl` / `check_adjoint_unit_counterexample` | `certified` | unreviewed |
| VP-TMP-001 | `formal/ERIEC/TemporalDC.lean` / `ERIEC.TemporalDC.Certification.ObservedTerminationStep` | `src/temporal_dc.jl` / `check_observed_termination` | `certified` | unreviewed |
| VP-TMP-002 | `formal/ERIEC/TemporalDC.lean` / `ERIEC.TemporalDC.Certification.PermanentTerminationStep` | `src/temporal_dc.jl` / `check_permanent_termination_prefix` | `certified` | unreviewed |
| VP-TMP-003 | `formal/ERIEC/RefModel/CollapseTrace.lean` / `ERIEC.RefModel.collapse_trace_reference_model` | `src/temporal_dc.jl` / `check_collapse_trace_termination` | `certified` | unreviewed |
| VP-TMP-004 | `formal/ERIEC/RefModel/CollapseTrace.lean` / `ERIEC.RefModel.collapse_trace_precarious` | `src/temporal_dc.jl` / `check_precarious_prefix` | `certified` | unreviewed |
| VP-TMP-005 | `formal/ERIEC/RefModel/CollapseTrace.lean` / `ERIEC.RefModel.all_mortal_reference_model` | `src/temporal_dc.jl` / `check_no_escape_prefix` | `certified` | unreviewed |
| VP-TTR-001 | `formal/ERIEC/TheoryTranslation.lean` / `ERIEC.TheoryTranslation.phenomenal_notCertified` | `src/theory_translation.jl` / `GuaranteeProfile` | `certified` | unreviewed |
| VP-VAL-002 | `formal/ERIEC/Value.lean` / `ERIEC.Value.V_endogenous` | `src/value.jl` / `check_value_endogenous` | `certified` | unreviewed |
| VP-WDC-001 | `formal/ERIEC/WorldDC.lean` / `ERIEC.WorldDC.DCWorldBridge` | `src/worlddc.jl` / `check_worlddc_bridge` | `certified` | unreviewed |
| VP-WDC-002 | `formal/ERIEC/WorldDC.lean` / `ERIEC.WorldDC.no_forward_unconditional` | `src/worlddc.jl` / `check_no_unconditional_worlddc` | `certified` | unreviewed |
| VP-WGR-001 | `formal/ERIEC/Wager.lean` / `ERIEC.Wager.W6_indep` | `src/wager.jl` / `check_wager_independence` | `certified` | unreviewed |
| VP-WGR-002 | `formal/ERIEC/Wager/Richness.lean` / `ERIEC.Wager.W5_indep_all` | `src/wager.jl` / `check_w5_independence_family` | `certified` | unreviewed |
| VP-WGR-003 | `formal/ERIEC/Wager/Preservation.lean` / `ERIEC.Wager.W1_identification_conservative` | `src/wager.jl` / `check_wager_conservative_extension` | `certified` | unreviewed |
| VP-WGR-004 | `formal/ERIEC/Wager/Preservation.lean` / `ERIEC.Wager.global_frozen_protocol_invariant` | `src/wager.jl` / `check_frozen_protocol_invariant` | `certified` | unreviewed |
| VP-WGR-005 | `formal/ERIEC/Wager/Models.lean` / `ERIEC.Wager.named_frozen_models_boundary` | `src/wager.jl` / `check_wager_named_models` | `certified` | unreviewed |
| VP-WGR-006 | `formal/ERIEC/Wager/Models.lean` / `ERIEC.Wager.W6_of_dc_cycle` | `src/wager.jl` / `check_w6_cycle_soundness` | `certified` | unreviewed |
| VP-WGR-007 | `formal/ERIEC/Wager/Models.lean` / `ERIEC.Wager.frozen_model_checker_soundness` | `src/wager.jl` / `check_frozen_wager_model` | `certified` | unreviewed |
| VP-WGR-008 | `formal/ERIEC/Wager/Models.lean` / `ERIEC.Wager.frozen_interpretive_checker_soundness` | `src/wager.jl` / `check_frozen_wager_interpretive_model` | `certified` | unreviewed |
| VP-WGR-009 | `formal/ERIEC/Wager/Models.lean` / `ERIEC.Wager.frozen_full_model_checker_soundness` | `src/wager.jl` / `check_frozen_wager_full_model` | `certified` | unreviewed |
| VP-WLD-001 | `formal/ERIEC/World.lean` / `ERIEC.World.WldNontrivial` | `src/world.jl` / `actuated_world` | `certified` | unreviewed |
| VP-WLD-002 | `formal/ERIEC/World.lean` / `ERIEC.World.Wld_band` | `src/world.jl` / `world_band` | `certified` | unreviewed |

## ゲート

未実行。
