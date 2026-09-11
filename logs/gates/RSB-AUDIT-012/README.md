# RSB-AUDIT-012 evidence

- `G3-assumption-suites-20260911.log`: PASS (64/64).
- `assumption-suites.toml` SHA-256:
  `351fa9977042bcb73423126961597fa671c57cbd3d7b8df82d253dde53967e34`.
- The P3/M2/two-input suite contains a nondegenerate all-four witness and all four
  isolated-drop witnesses in one exact context.
- The P6/no-M2/one-input-two-motor suite also contains all five patterns.
- The P6/M2/one-input suite currently contains only the all-four witness. Its four
  missing isolated-drop patterns remain `not_found_in_finite_catalog`, not impossible.
- The report does not establish full M1-M4 or any phenomenal claim, and it changes no
  certified interface or ledger state.
- The complete package retry, including this suite and the other audit additions,
  passed at `../quiet/test-20260911-233933-17698.log.a2XgQM`.
- `G1-full-20260911.log`: PASS; the default Lean build completed 2,813 jobs.
- `G2-contract-20260911.log`: PASS (1,317/1,317). No certificate catalog entry was
  added, so there is no new G4 registration to advance.
