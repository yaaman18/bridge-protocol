# VP-BDY-003 implementation packet

VP: `VP-BDY-003`

- Target declaration: `ERIEC.FieldBridge.PeriodicBoundaryWitness`
- Mutable files: `formal/ERIEC/FieldBridge/Boundary.lean`,
  `formal/ERIEC/FieldBridge.lean`, `formal/ERIEC/CertifiedArtifact.lean`,
  `src/field_bridge.jl`, `test/test_field_bridge.jl`,
  `test/test_formal_julia_contract.jl`, `test/test_checker_semantic_manifest.jl`,
  `test/test_cert_scope.jl`, `specs/ledger.toml`,
  `specs/checker-semantic-manifest.toml`, and
  `specs/cert-scope-registry.toml`.
- Direct dependencies: `Mathlib.Data.Set.Basic`, the fixed
  `specs/sensory-carrier-profile-v1.toml`, and the existing FieldBridge and
  certified-artifact infrastructure.
- Fixed names: `PeriodicBoundaryWitness`, `PeriodicBoundaryCertificate`,
  `check_periodic_body_boundary`, `body.periodic_boundary_extraction`.
- Prohibited changes: existing certified Body/DC APIs, the profile's threshold,
  connectivity, tolerance, seed, or horizon values, target-layer axioms,
  `ERIEState`, `check_DC`, and all phenomenal markers.
- Verification: G1, G2, focused falsification tests, commit-bound G3C, then G4
  dependency-edge audit.

## Frozen statement

For a cell type `Cell`, a supplied neighborhood `neighbors : Cell → Set Cell`,
support `support : Set Cell`, and boundary `boundary : Set Cell`, the witness
stores the pointwise biconditional

```text
c ∈ boundary ↔ c ∈ support ∧ ∃ n, n ∈ neighbors c ∧ n ∉ support.
```

The certified consequence is `boundary ⊆ support`.  The Lean declaration is
parametric in `neighbors`; it does not claim that an arbitrary neighborhood is
periodic.  The Julia instantiation uses the preregistered square torus and its
periodic four-neighbor boundary rule from the fixed sensory-carrier profile.

## Julia checker boundary

`PeriodicBoundaryCertificate` contains finite support and boundary masks plus
the fixed profile identity. `check_periodic_body_boundary` exhaustively checks
every grid cell against the periodic four-neighbor predicate, rejects malformed
or empty masks, and rejects a profile identity mismatch.  It is a
`witness_validator`: it does not prove that caller-supplied masks originated
from a field measurement.

Required falsifications:

1. removing one true boundary cell is rejected;
2. adding one cell outside support to boundary is rejected;
3. changing the profile digest is rejected;
4. a support crossing the array edge is evaluated with wrap-around neighbors.

This VP remains in the observation layer. It does not construct an `ERIEState`,
establish `hBound`, identify `ViableSystem.viable` with `DC`, or write any
measured value back into an individual object. Julia symbols remain
module-visible and are not exported during P0.
