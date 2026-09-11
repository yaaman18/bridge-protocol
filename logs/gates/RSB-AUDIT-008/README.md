# RSB-AUDIT-008 evidence

- `G3-closure-expansion-20260910.log`: PASS (38/38). It checks finite fixed-point
  convergence, fixed-point validity and coverage of all postfixed carrier subsets.
- `closure-expansion-examples.toml` contains a measured all-DC/M2 model in which
  observed K is a proper subset of νΦ. Thus the checker does not silently replace K.
- `G3-symmetric-union-20260910.log`: PASS (9/9). The symmetric-union fixture has a
  greatest support equal to the union of two exchanged fixed components, with no
  invariant choice of one component in the specified candidate class.
- These are finite relational checks. They do not establish M1 equivalence, an
  intrinsic decomposition or an owner of experience.
- `phenomenal_claim = not_certified`; no write-back or ledger update occurred.
