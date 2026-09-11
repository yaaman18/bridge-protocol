# RSB-AUDIT-006 evidence

- `G3-two-input-search-20260910.log`: PASS (16/16). The fixed P6 search inspected
  20,000 N=6 and 20,000 N=7 circuits. It found only part of the target suite;
  an unfound pattern remains an in-domain negative result.
- `G3-explicit-two-input-20260910.log`: PASS (27/27). The explicit P6 constructions
  remeasure all interventions and establish three stored patterns with M2 in that context.
- Search and explicit constructions use P=H=6, L=R=4. They are not evidence for the
  later P3 context and do not establish a general impossibility.
- `phenomenal_claim = not_certified`; ledger and certificate states were not changed.
