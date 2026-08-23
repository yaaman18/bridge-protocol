# Bridge Protocol
### An Undetermined Proof of the Phenomenal World Derived from Axioms

**English** | [日本語](README.ja.md) | [Español](README.es.md)

`Bridge` comes from `DCWorldBridge` (WorldDC.lean) and `bridgeOpen` (Gate.lean) — the Lean types that connect self-maintenance to world-arising. The phenomenal gate is always `bridgeOpen`; it can never be `pass`.

---

## What this repository is

Bridge Protocol is a protocol for constructing a category-theoretic theory of
self-maintaining systems and machine-checking it:

```
informal discussion → category-theoretic specification → Lean 4 proofs → Julia implementation
```

The core structures of the theory:

- **Sensorimotor adjunction `α ⊣ σ`** — a Galois connection between acting and sensing.
  What a system can touch and what touches it back are two sides of one structure.
- **Closure `Φ` and its greatest fixed point `νΦ`** — self-maintenance is formalized as a
  *greatest* fixed point, i.e. staying viable, **not** maximizing anything.
- **Hinge condition `Act ≠ ∅`** — there is always at least one action available; the
  system is never sealed off from its world.
- **Self-maintenance certificate `DC`** — a machine-checkable witness that a system
  maintains itself under its own dynamics.
- **Enacted world `Wld`** — the world *for* a system, arising from the loop of movement
  and sensation rather than given from outside. Change the body, and the world changes.

A strict two-layer discipline runs through everything: individual systems live in the
**object layer** (subject to structural requirements M1–M4), while any
evolution- or selection-oriented assumptions are injected only in a separate
**meta layer**, and are never written back into individuals.

## What this project does *not* claim

This part is as important as the theory itself.

- **No claim of consciousness.** Even if the structural description is completed and
  fully verified, whether "a light is on inside" — whether there is subjective
  experience — cannot be proven from the outside. The theory leaves that question
  unanswered, outside the description, as a possibility. This honesty is enforced
  mechanically: the marker `phenomenal_claim = :not_certified` is part of the certified
  artifact chain and is, by design, never promoted by any proof.
- **No optimization story.** Maintenance is a greatest fixed point, not a reward to be
  maximized. The object layer forbids external set points and reachable terminal
  objects (requirement M4).
- **No silent identifications.** Open-system viability (`viable`) and the ERIE-C
  self-maintenance certificate (`DC`) are kept distinct; their equivalence is unproven
  and is never assumed.

## Verification methodology

Verification evidence is represented by two ledgers with different roles. The schema-v1
[specs/ledger.toml](specs/ledger.toml) is an index of certified Lean–Julia bindings,
dependencies, and certificate-catalog entries. Its 59 VPs are all terminal
`certified` entries; it is not the current claim-lifecycle source of truth, and
implementation work does not advance its status. The atomic lifecycle ledger is
[specs/claim-ledger-v2.toml](specs/claim-ledger-v2.toml): it records 91 claims on four
independent axes, `spec_status`, `proof_status`, `implementation_status`, and
`certification_status`.

The gate sequence remains the verification model:

```
proposed ──G1──▶ formalized ──G2──▶ bound ──G3──▶ implemented ──G4──▶ certified
```

- **G1** — the Lean 4 formalization typechecks (`lake build`, no `sorry`).
- **G2** — the Lean declaration is bound to a Julia symbol by a contract test.
- **G3** — the Julia implementation passes its tests.
- **G4** — the contract is registered in the certificate catalog and its dependency
  graph verifies.

Three rules give the ledgers their meaning. First, a claim is marked `certified` **only**
when actual gate logs exist under [logs/gates/](logs/gates/) — those logs are committed
as evidence. Second, the *visible gap principle*: v2 records claims that lack proof or
certification on their corresponding axes; they are never silently dropped or silently
believed. Third, the *two-axis principle* (introduced 2026-08-01):
`certified` in the v1 ledger means only that the single Lean declaration referenced by
`contract_id` has been machine-checked; it does not guarantee every property enumerated
in the `claim_ja` prose. The separate `coverage_audit` axis records how much of that prose
is backed by the contract: `unreviewed` means not yet audited and `complete` means audited.
The axes are orthogonal. A contract remains certified when `coverage_audit` is
`unreviewed`, while certification alone does not guarantee prose coverage. The status of
each atomic claim is recorded in
[specs/claim-ledger-v2.toml](specs/claim-ledger-v2.toml).

As of 2026-08-14, the v1 ledger tracks 59 verification points, all 59 certified. Of the
`coverage_audit` values, 10 are `complete` and 49 are `unreviewed`. `legacy_coverage`
contains 10 entries (all with `basis = "exact_ledger_decl"`); the audit found that the
contracts cover 7 atomic claims and do not cover 85. In other words, across the 10 audited
entries, only 7 of the properties their prose asserts are backed by a machine check; the
remaining 85 lie outside the contract. The v2 ledger contains 91 atomic claims: 38
certified and 53 uncertified.

The runnable [category pipeline](bin/eriec-category-pipeline.jl) is an impact-recheck
gate runner, not a status-progression driver. Its implementation reads schema v1 only,
not v2, and writes no ledger status. The status-advancing driver described in
[the orchestration specification](specs/loop-orchestration-spec.md) remains an
unimplemented, deferred design; its need will be reconsidered when order-10b creates the
first two non-terminal VPs. See the
[read-only ledger audit](logs/ledger-design-audit-20260814.log) for the supporting evidence.

## Repository layout

| Path | Contents |
|---|---|
| [formal/ERIEC/](formal/ERIEC/) | Lean 4 formalization (47 modules: adjunction, closure, hinge, DC, lineage, richness, generation, …) |
| [src/](src/) | Julia reference implementation (`ERIEC.jl` package) |
| [test/](test/) | Julia tests, including the Lean–Julia contract test |
| [specs/](specs/) | Verification-point ledger and frozen statement files |
| [category/](category/) | Category-theoretic working documents |
| [docs/](docs/) | Theory overview, requirements, design documents |
| [logs/gates/](logs/gates/) | Gate evidence logs (build/test output backing every `certified` status) |

Most working documents in `docs/` and `category/` are written in Japanese; the Lean
and Julia sources are the language-independent core.

## Reproducing the verification

The license below grants: reading, compiling, and independently
reproducing the stated results.

```bash
# Lean proofs (toolchain pinned in ./lean-toolchain)
lake build

# Julia implementation and Lean–Julia contract tests
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

## License — not open source

This repository is published under the **Bridge Protocol Restricted Source-Available
License v1.0** ([LICENSE_ERIEC.md](LICENSE_ERIEC.md)). It is a *source-available* license,
**not** an OSI-approved open-source license.

You **may**: read the sources, compile and typecheck them, run the reference models to
verify the stated results, and quote limited excerpts with attribution for academic
citation, review, or commentary.

You **may not**, without a separate written agreement: use the work commercially,
create or distribute derivative works, redistribute or mirror the repository, train or
fine-tune machine-learning models on it, or make certification claims based on it.

Because derivative works are prohibited, **pull requests and forks are not accepted**.
If you are interested in collaboration or licensing, contact the author.

## Citation

> Mitsuyuki Yamaguchi. *Bridge Protocol*, v0.1.0, 2026.
> Licensed under the Bridge Protocol Restricted Source-Available License v1.0.
> https://github.com/yaaman18/bridge-protocol

---

© 2026 Mitsuyuki Yamaguchi. All rights reserved.
