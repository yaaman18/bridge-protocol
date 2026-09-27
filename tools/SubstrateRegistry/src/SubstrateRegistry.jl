"""
RSB-001: registration mechanism for the reactivation substrate profile.

This module freezes nothing and measures nothing. It verifies that a profile and an
analysis plan were registered on a fixed remote before a run starts, and it defines the
run-start record and the completion-manifest template. It must not depend on ERIEC.

Scope of the guarantee (RSB-001 §2): a trusted, managed runner confirmed the registration on
the fixed remote before starting a run with that profile. It does not prove the absence of
exploration outside the repository, does not authenticate local logs, and is not a security
boundary against arbitrary Julia code.
"""
module SubstrateRegistry

using SHA
using TOML

export VerifiedRegistration, RegistrationRejected, SchemaViolation,
    verify_substrate_registration,
    validate_profile, validate_analysis_plan, validate_registry, validate_pair,
    canonical_case_ids, case_digest,
    runner_state, build_run_start_record, validate_run_start_record,
    write_run_start_record, completion_manifest, validate_completion_manifest,
    write_completion_manifest

include("schema.jl")
include("cases.jl")
include("git.jl")
include("verify.jl")
include("records.jl")
include("cli.jl")

end
