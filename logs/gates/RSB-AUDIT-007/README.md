# RSB-AUDIT-007 evidence

- `G3-adjoint-separation-20260910.log`: PASS (54/54). All-five DC patterns were
  remeasured with M2, nondegeneracy and effective-boundary checks in the same
  P=3, H=6, L=R=4, two-input/two-motor context.
- `independent-replay.log`: PASS. A Python implementation replayed all 2,368 stored
  intervention branches and reproduced each DC pattern and M2 result.
- `G3-full-20260910.log`: the repository-wide Julia suite passed at that revision.
- The hAct construction has 11 units; the audit-only circuit bound was extended to 12.
  Existing certified tolerances and the eight-unit reactivation candidate were unchanged.
- `phenomenal_claim = not_certified`; the evidence does not certify M1-M4 as a whole.
