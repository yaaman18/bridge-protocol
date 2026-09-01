# VP-BDY-002 implementation packet

VP: `VP-BDY-002`

- Target declaration: `ERIEC.FieldBridge.ClampSigmaIdentificationAssumption`
- Mutable files: `formal/ERIEC/FieldBridge.lean`, `formal/ERIEC.lean`,
  `formal/ERIEC/CertifiedArtifact.lean`, `src/field_bridge.jl`, `src/ERIEC.jl`,
  `test/test_field_bridge.jl`, `test/test_formal_julia_contract.jl`,
  `test/parallel_test_plan.jl`, `specs/sensory-carrier-contract.md`,
  `specs/sensory-carrier-profile-v1.toml`, `specs/ledger.toml`,
  `specs/checker-semantic-manifest.toml`, `specs/cert-scope-registry.toml`.
- Direct dependencies: `ERIEC.Adjunction`, the existing Lenia field update and
  certified-artifact infrastructure.
- Fixed names: `ClampSigmaIdentificationAssumption`,
  `ClampSigmaMeasurementCertificate`, `check_clamp_sigma_identification`,
  `body.clamp_sigma_identification`.
- Prohibited changes: existing `SensoryFeature`, certified Body/DC APIs,
  existing numerical tolerances, target-layer axioms, and all phenomenal markers.
- Verification: G1, G2, focused G3 plus full G3, then G4 dependency-edge audit.

The implementation is observation-layer only.  It introduces no policy and
does not write a measured relation back into an individual Body or DC object.
The Julia symbols remain module-visible but are not exported during P0.
