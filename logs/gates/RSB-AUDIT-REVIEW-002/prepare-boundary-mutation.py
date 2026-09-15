"""Create an isolated mutation and reuse the actual boundary regression test."""
from pathlib import Path
import shutil

repo = Path(__file__).resolve().parents[3]
evidence = Path(__file__).resolve().parent
mutation_tools = evidence / "mutation" / "tools"
mutation_tools.mkdir(parents=True, exist_ok=False)
shutil.copy2(repo / "tools/ModelAudit.jl", mutation_tools / "ModelAudit.jl")
shutil.copytree(repo / "tools/model_audit", mutation_tools / "model_audit")
witnesses = mutation_tools / "model_audit/Witnesses.jl"
original = witnesses.read_text()
correct = """boundary = Set(c for c in snapshot.kappa
                   if any(d ∉ snapshot.kappa for d in snapshot.neighbors[c]))"""
assert original.count(correct) == 1
witnesses.write_text(original.replace(correct,
    "boundary = snapshot.kappa == Set(snapshot.C) ? Set{Symbol}() : copy(snapshot.kappa)"))

source = (repo / "test/test_model_audit.jl").read_text()
start = source.index('@testset "DC predicates match direct quantifiers on all tiny encodings"')
end = source.index('@testset "DC witnesses preserve the other conditions"', start)
block = source[start:end].replace('@testset "', '@testset failfast=true "', 1)
runner = evidence / "boundary-mutation-test.jl"
with runner.open("x") as output:
    output.write('using Test\ninclude(joinpath(@__DIR__, "mutation", "tools", "ModelAudit.jl"))\n')
    output.write(block)
print("isolated neighbors-ignoring mutation ready:", runner)
