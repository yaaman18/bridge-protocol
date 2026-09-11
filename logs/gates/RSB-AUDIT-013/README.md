# RSB-AUDIT-013 evidence

- `Lean-one-input-adjunction-recheck-20260911.log` under `../RSB-AUDIT-005/` was
  produced by an exit-0 individual Lean check. The source SHA-256 is fixed as
  `1d7030a44002e3cb220d44e32d529e513bacf290ba7d4c7397179ed8f9f53c3c`.
- `G3-constraint-overlay-20260912.log`: PASS (22/22).
- `constraint-overlay.toml` contains 15 target rows and zero current evidence
  conflicts. Its SHA-256 is
  `aa3f180fa4312d12ae7dead16d0a943f4340d31c81175ce0aa2f49b044c298d5`.
- In the one-input M2 context, `without_hSMC` and `without_hAct` are marked
  `incompatible_with_checked_experimental_statement`; `without_hSelf` and
  `without_hBound` remain ordinary finite-catalog absences.
- A synthetic conflicting witness is classified `conflict_requires_review` in the
  test. The real report does not contain that synthetic row.
- The Lean statement remains outside the default target and certificate catalog.
  `certificate_registered=false`, `general_impossibility=not_established`, and
  `phenomenal_claim=not_certified` remain explicit.
