import Lake
open Lake DSL

package ERIEC where

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git"

-- TODO: replace the local development dependency with a pinned git revision
-- before the first PCI certificate is published.
require proof_carrying_intersubjectivity from
  "../proof-carrying-intersubjectivity"

@[default_target]
lean_lib ERIEC where
  srcDir := "formal"

lean_exe eriec_certified_artifact where
  root := `ERIEC.CertifiedArtifact
  srcDir := "formal"

@[default_target]
lean_lib ERIECPCI where
  srcDir := "adapters"

@[default_target]
lean_lib ERIECPCIIntegrationTest where
  srcDir := "test"
  globs := #[`ERIECPCIIntegrationTest]
