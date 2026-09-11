# RSB-AUDIT-009 evidence

- `G3-viewer-20260911.log` preserves the initial failure: 62 checks passed and the
  Node syntax check found a missing parenthesis in `renderNetwork`.
- After that syntax fix, `G3-viewer-retry-20260911.log` passed all 63 checks.
- `generate-viewer-retry-20260911.log` regenerated seven cases and 4,480 complete
  intervention branches. The HTML SHA-256 is
  `74f23cb45196ddaf9d9061b57411532f7c8d44cb9980c0de2941e91304730418`.
- Playwright loaded the local `file:` URL and saved `viewer-desktop.png`; visual
  inspection confirmed the controls, predicate cards, circuit and support panel render.
- The HTML has no network resources. Its CSP denies external loads and connections;
  embedded data is Base64 JSON and dynamic labels use text nodes.
- The viewer is a review artifact. It does not change measurements, residual history,
  certification or `phenomenal_claim = not_certified`.
- The first full `Pkg.test()` run is preserved at
  `../quiet/test-20260911-233209-14444.log.a5elGf`; its isolated environment rejected
  the undeclared Base64 standard-library dependency. `Project.toml`/`Manifest.toml`
  were updated with that direct dependency and no external package version change.
- The retry at `../quiet/test-20260911-233933-17698.log.a2XgQM` passed the complete
  package test suite. Its SHA-256 is
  `b3c410c970ef6b3acd73fed92312402674d58da9650c53c99db99f3cbc7e8633`.
