# RSB-AUDIT-010 evidence

- `G3-countermodels-20260911.log`: PASS (25/25). Thirteen distinct circuits are
  remeasured and kept in three exact contexts.
- `finite-model-catalog.toml` SHA-256:
  `c9adad2fd93e50ac6015bba0c119bb530b51e65e1291f883eddbbbdbc77a0c70`.
- `report-self-implies-smc.toml`, `report-dc-implies-max.toml` and
  `report-max-support-selects-component.toml` each contain a finite countermodel.
- `report-one-input-active-boundary.toml` reports `not_found_in_finite_catalog` with
  one eligible model, while retaining `implication_proved=false` and
  `general_impossibility=not_established`.
- Unknown predicates are omitted rather than filled with false. Context-free queries
  and context names absent from the catalog are rejected.
- `phenomenal_claim = not_certified`; no certified interface or ledger was changed.
