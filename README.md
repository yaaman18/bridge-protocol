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

### The object layer — what an individual system is

Every individual system must satisfy four structural requirements, M1–M4. Nothing in this
layer is allowed to reach a terminal object.

- **Closure `Φ` and its greatest fixed point `νΦ` (M1)** — self-maintenance is formalized as a
  *greatest* fixed point, i.e. staying viable, **not** maximizing anything. Maintenance is
  precarious: it can be broken by perturbation, so it must be actively sustained.
- **Sensorimotor adjunction `α ⊣ σ` (M2)** — a Galois connection between acting and sensing.
  What a system can touch and what touches it back are two sides of one structure.
- **Hinge condition `Act ≠ ∅` (M3)** — there is always at least one action available; the
  system is never sealed off from its world.
- **Endogeneity / no terminal object (M4)** — the system's diagram of demands `D` has no
  reachable terminal object, and no set point is injected into it from outside. A terminal
  object would be a state the system could reach and stop at.
- **Self-maintenance certificate `DC`** — a machine-checkable witness that a system
  maintains itself under its own dynamics.
- **Enacted world `Wld`** — the world *for* a system, arising from the loop of movement
  and sensation rather than given from outside. Change the body, and the world changes.

### Derived lines built on that layer

- **Functional termination** (`TemporalDC`) — loss of whole-system `DC` on endogenous time,
  together with its permanence and exclusivity. The design goal of this line is to make
  explicit that functional termination *cannot be structurally escaped* without adding an
  external axiom; internal immortality would require violating both M1 and M4b at once.
  The formal layer never uses the word "death" — that reading stays in the prose documents.
- **Generation and proliferation** — the birth hemisphere. `DC ⇒ viable` is realized as a
  one-directional translation witness, never as an equivalence, and richness inheritance
  across generations is a separate statement from the single-step hinge branch pump.
- **Individuality as a pair ⟨system `S`, decomposition `D`⟩** — individuality is not a label
  on a substrate. The same substrate can be an individual under one decomposition and a
  colony under another, and both readings can be true.
- **The §14 wager (`W1`–`W6`)** — six frozen sentences with constructive independence
  witnesses, showing that they are *not* derivable from the object-layer axioms. This is
  where the "undetermined" of the subtitle is made formal.

### The meta layer — and why it is kept separate

A strict two-layer discipline runs through everything. Individual systems live in the
**object layer**; any evolution- or selection-oriented assumption lives only in the
**meta layer** and is never written back into individuals.

- **Σ1 external selection** — a selector `𝒮` acting on population state prefers structurally
  richer objects. It is not an object of any individual's own theory, and it is invisible to
  every individual.
- **Richness functional `Φ_rich`** — computed strictly read-only, through observation `σ`.
  It is never composed into an individual's closure operator `Φ`.
- **Σ-purity (noninterference)** — varying the selector's value or state must leave every
  individual's observational trace `(νΦ, V, D, action trace)` bit-identical. This is checked
  both statically (taint reachability from the selection namespace to individual sinks) and
  dynamically (metamorphic differential testing).
- **M4 preservation is one-directional.** `M4(i) ∧ Σ-purity(𝒮,i) ⇒ M4-preserved(𝒮,i)` is
  proved; the converse is **not**, and is never assumed.

## What this project does *not* claim

This part is as important as the theory itself.

- **No claim of consciousness.** Even if the structural description is completed and
  fully verified, whether "a light is on inside" — whether there is subjective
  experience — cannot be proven from the outside. The theory leaves that question
  unanswered, outside the description, as a possibility. This honesty is enforced
  mechanically: the marker `phenomenal_claim = :not_certified` is part of the certified
  artifact chain and is, by design, never promoted by any proof. A hierarchy of
  individuality can be certified; how many lights that hierarchy contains — one, many, or
  zero — is not.
- **No optimization story.** Maintenance is a greatest fixed point, not a reward to be
  maximized. The object layer forbids external set points and reachable terminal
  objects (requirement M4).
- **No silent identifications.** Open-system viability (`viable`) and the ERIE-C
  self-maintenance certificate (`DC`) are kept distinct; their equivalence is unproven
  and is never assumed. The same applies to `DC` and `Wld`: their non-triviality relation
  is an explicitly recorded assumption, not a theorem.
- **No claim that a certified contract covers its own prose.** See the two-axis principle
  below. Most contracts are certified with their prose coverage still unaudited.
- **No falsification conditions yet.** All 91 atomic claims carry a `falsification_ja`
  field and all 91 are currently `未記入` ("unfilled"). The debt is recorded and
  ratchet-guarded so it cannot grow, but it has not yet been paid down.

## Verification methodology

### The gate sequence

```
proposed ──G1──▶ formalized ──G2──▶ bound ──G3──▶ implemented ──G4──▶ certified
```

- **G1** — the Lean 4 formalization typechecks (`lake build`, no `sorry`).
- **G2** — the Lean declaration is bound to a Julia symbol by a contract test.
- **G3** — the Julia implementation passes its tests.
- **G4** — the contract is registered in the certificate catalog and its dependency
  graph verifies.

### Two ledgers with different roles

Verification evidence is represented by two ledgers. The schema-v1
[specs/ledger.toml](specs/ledger.toml) is an **index** of certified Lean–Julia bindings,
dependencies, and certificate-catalog entries. Its 61 verification points are all terminal
`certified` entries; it is not the claim-lifecycle source of truth, and implementation work
does not advance its status.

The **atomic lifecycle ledger** is [specs/claim-ledger-v2.toml](specs/claim-ledger-v2.toml).
It records 91 claims on four independent axes — `spec_status`, `proof_status`,
`implementation_status`, and `certification_status` — grouped into 15 claim groups with 44
evidence batches. Each claim points at a frozen Lean statement file under
[specs/statements/](specs/statements/) (108 files), and the ledger stores the sha256 of that
file so the statement cannot drift out from under the claim.

### What `certified` does and does not mean

Four rules give the ledgers their meaning.

**1. Evidence or nothing.** A claim is marked `certified` **only** when actual gate logs
exist under [logs/gates/](logs/gates/) — those logs are committed as evidence (159 gate
directories, 1389 log files as of 2026-08-31). The ledger validator independently re-checks
that each `certification_log` path exists on disk.

**2. The visible gap principle.** v2 records claims that lack proof or certification on
their corresponding axes. They are never silently dropped and never silently believed. A
claim with `proof_status = "unproved"` is *forced* by the validator to declare
`claim_kind = "conjecture"` and `checker_relation = "observation_only"`.

**3. The two-axis principle** (introduced 2026-08-01). `certified` in the v1 ledger means
only that the single Lean declaration referenced by `contract_id` has been machine-checked;
it does **not** guarantee every property enumerated in the `claim_ja` prose. The separate
`coverage_audit` axis records how much of that prose is backed by the contract:
`unreviewed` means not yet audited, `complete` means audited. The axes are orthogonal — a
contract stays certified while `coverage_audit` is `unreviewed`, and certification alone
never implies prose coverage.

**4. Checkers declare what they actually decide.** A Julia checker that returns `true` is
not automatically a decision procedure for the Lean statement it is bound to.
[specs/checker-semantic-manifest.toml](specs/checker-semantic-manifest.toml) classifies all
164 contracts by the relation their checker bears to the statement:

| `checker_relation` | Count | Meaning |
|---|---:|---|
| `lean_only` | 72 | machine-checked in Lean; no Julia-side decision claimed |
| `exact_finite_decision` | 28 | decides the statement on the supplied finite carriers |
| `witness_validator` | 28 | validates a supplied witness; does not establish identity with a fixed Lean object |
| `regression_only` | 14 | pins current behavior; decides nothing about the statement |
| `observation_only` | 10 | records an observation only |
| `sound_only` | 5 | no false accepts; may miss |
| `counterexample_generator` | 4 | constructs a counterexample |
| `counterexample_validator` | 2 | validates a supplied counterexample |
| `complete_only` | 1 | no false rejects; may over-accept |

Of the 164, 92 are `reviewed` (a named reviewer with a basis log) and 72 are
`machine_verified`. Each entry additionally records its `scope`, its `assumptions`, and the
`guarantee` it will and will not make.
[specs/cert-scope-registry.toml](specs/cert-scope-registry.toml) records the certification
scope of the same 164 contracts; all are currently `context_local`, meaning no contract
claims a scope beyond the context it was checked in.

### Guarding the checks themselves

A test suite that only ever runs the happy path cannot detect its own hollowing-out. The
practices confirmed on 2026-08-27 in
[specs/verification-practices-v2-draft.md](specs/verification-practices-v2-draft.md) address
three observed failure modes — weak acceptance checks, self-verification by the packet's own
author, and the same design error recurring three times.

- **Adversarial input goes to a temp copy.** Verification logic is split into
  path-injectable validators under [tools/verify/](tools/verify/) that return stable
  violation codes. The normal test and the mutation runner share the same validator; the
  runner never touches the live working tree.
- **The mutation corpus lists edits that must be caught.**
  [tools/mutation_corpus.toml](tools/mutation_corpus.toml) pairs each deliberate edit with
  the specific violation code it must produce — not merely a non-zero exit. It currently
  contains one mutation (`CERTIFIED_TEXT_HASH_MISMATCH`).
- **Claim text is hash-separated from certification.** Each claim stores a
  `claim_text_hash` binding its `statement_ja` and `conclusion`, plus a
  `certified_text_hash` recording the text the certification was granted against. Weakening
  a claim's prose to match what was actually proved now breaks the hash comparison.
- **A failure-mode registry with stable IDs.**
  [specs/verification-failure-modes.toml](specs/verification-failure-modes.toml) records 4
  observed modes (caller-supplied proof booleans, opaque callbacks identified from finite
  samples, circular oracles, ungated falsification conditions), each with its evidence logs.
- **A ratchet on the falsification debt.** `tools/verify/ratchet_check.jl --base-ref <commit>`
  compares the working tree's `falsification_pending_max` against the same field at an
  explicitly named base commit and requires it not to have increased. The base ref must be
  supplied by the caller; when git is unavailable the check reports `UNVERIFIED` rather
  than passing green.

### Current state (2026-08-31)

| | Value |
|---|---|
| v1 verification points | 61, all `certified` |
| v1 `coverage_audit` | 10 `complete`, 51 `unreviewed` |
| v1 `legacy_coverage` audit | 10 entries; contracts cover 7 atomic claims, do not cover 85 |
| v2 atomic claims | 91 |
| v2 `spec_status` | 86 `frozen`, 5 `draft` |
| v2 `proof_status` | 68 `proved`, 22 `not_applicable`, 1 `unproved` |
| v2 `implementation_status` | 57 `tested`, 34 `not_applicable` |
| v2 `certification_status` | 38 `certified`, 53 `uncertified` |
| Falsification conditions written | 0 of 91 |

Read the third row carefully: across the 10 audited legacy entries, only 7 of the properties
their prose asserts are backed by a machine check; the remaining 85 lie outside the contract.

### What is not automated

There is **no CI** in this repository — no `.github/workflows`, no `.gitlab-ci.yml`, no
`Makefile`. Every gate is run locally and its log committed.

The runnable [category pipeline](bin/eriec-category-pipeline.jl) is an impact-recheck gate
runner, not a status-progression driver: it reads schema v1 only, never v2, and writes no
ledger status. The status-advancing driver described in
[the orchestration specification](specs/loop-orchestration-spec.md) remains an unimplemented,
deferred design; its need will be reconsidered when order-10b creates the first two
non-terminal verification points. See the
[read-only ledger audit](logs/ledger-design-audit-20260814.log) for the supporting evidence.

## Repository layout

| Path | Contents |
|---|---|
| [formal/ERIEC/](formal/ERIEC/) | Lean 4 formalization (71 modules: adjunction, closure, hinge, DC, world, invariance, lineage, richness, generation, temporal DC, wager, meta-selection, …) |
| [specs/statements/](specs/statements/) | 108 frozen Lean statement files, sha256-bound from the v2 ledger |
| [src/](src/) | Julia reference implementation (`ERIEC.jl` package, 65 files) |
| [test/](test/) | Julia tests (63 files), including the Lean–Julia contract test and the ledger, manifest, cert-scope, and packet-review integrity tests |
| [tools/verify/](tools/verify/) | Path-injectable validators, mutation runner, ratchet check |
| [bin/](bin/) | Category pipeline, model evaluation, Lenia and TRM experiment runners |
| [specs/](specs/) | Both ledgers, the checker semantic manifest, the cert-scope registry, the failure-mode registry, and implementation packets |
| [category/](category/) | Category-theoretic working documents |
| [docs/](docs/) | Theory overview, requirements, design documents |
| [adapters/](adapters/) | External-framework adapters (PCI) |
| [logs/gates/](logs/gates/) | Gate evidence logs (build/test output backing every `certified` status) |

Most working documents in `docs/` and `category/` are written in Japanese; the Lean
and Julia sources are the language-independent core.

## Reproducing the verification

The license below grants: reading, compiling, and independently
reproducing the stated results.

```bash
# Lean proofs (toolchain pinned in ./lean-toolchain)
lake build

# Julia implementation, Lean–Julia contract tests, and all ledger integrity tests
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

Individual integrity checks can be run on their own:

```bash
# Ledger, manifest, cert-scope, and packet-review integrity
julia --project=. test/test_claim_ledger.jl
julia --project=. test/test_checker_semantic_manifest.jl
julia --project=. test/test_cert_scope.jl
julia --project=. test/test_packet_review.jl

# Impact recheck against the category-theoretic baseline (reads v1, writes no status)
julia --project=. bin/eriec-category-pipeline.jl check

# Mutation and ratchet checks (G3V); --base-ref must be named explicitly
tools/quiet-verify.sh logs/gates/<batch>/G3V-<timestamp>.log --base-ref <commit>
```

## License — not open source

This repository is published under the **Bridge Protocol Restricted Source-Available
License v1.0** ([LICENSE.md](LICENSE.md)). It is a *source-available* license,
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
