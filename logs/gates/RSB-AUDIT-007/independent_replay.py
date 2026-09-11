"""Independent exact-integer replay of the measured, adjoint witness corpus.

Run with Python 3.12. This does not call Julia, read the preregistration candidate,
or certify experience. Edge accumulation differs from the Julia target-wise loop.
"""
from pathlib import Path
import tomllib

data = tomllib.loads(Path(__file__).with_name("measured-adjoint-witnesses.toml").read_text())
patterns = {
    "all_four": [True, True, True, True],
    "without_hSelf": [False, True, True, True],
    "without_hSMC": [True, False, True, True],
    "without_hAct": [True, True, False, True],
    "without_hBound": [True, True, True, False],
}
assert len(data["witnesses"]) == 5
assert {w["name"] for w in data["witnesses"]} == set(patterns)
total_branches = 0

for witness in data["witnesses"]:
    c = witness["circuit"]
    units, edges, theta = c["units"], c["edges"], c["thresholds"]
    n, indices = len(units), {u: i for i, u in enumerate(units)}
    assert (c["P"], c["H"], c["L"], c["R"]) == (3, 6, 4, 4)
    M, E = set(c["motors"]), set(c["inputs"])
    assert len(M) == len(E) == 2 and not M & E

    def trace(initial, steps, mask=0):
        states = [list(initial)]
        for _ in range(steps):
            sums = [0] * n
            for source, target, weight in edges:
                if states[-1][source-1] and not mask & (1 << (source-1)):
                    sums[target-1] += weight
            states.append([s >= t for s, t in zip(sums, theta)])
        return states

    def persistent(states, points):
        return {u for i, u in enumerate(units) if all(s[i] for s in states[-points:])}

    prefix = trace(c["initial"], c["P"])
    assert prefix == witness["prefix"]
    assert len(witness["traces"]) == 1 << n
    stored = {t["source_mask"]: t for t in witness["traces"]}
    assert set(stored) == set(range(1 << n))
    traces = {mask: trace(prefix[-1], c["H"], mask) for mask in stored}
    for mask, states in traces.items():
        assert states == stored[mask]["states"], (witness["name"], mask)
    total_branches += len(traces)
    Q = persistent(traces[0], c["R"])
    K = persistent(prefix, c["L"])
    eps = {e for e in E if prefix[-1][indices[e]]}
    losses = {mask: Q - persistent(states, c["R"]) for mask, states in traces.items()}
    assert all(losses[mask] == set(stored[mask]["losses"]) for mask in stored)
    one = lambda u: 1 << indices[u]
    changes = lambda u, targets: {v for v in targets if traces[0][-1][indices[v]] != traces[one(u)][-1][indices[v]]}
    alpha = {m: changes(m, E) for m in M}
    sigma = {e: changes(e, M) for e in E}
    pi = {m: losses[one(m)] for m in M}
    rho = {u: losses[one(u)] & M for u in units}
    neighbors = {u: {units[d-1] for s, d, _ in edges if units[s-1] == u} for u in units}
    image = lambda rel, xs: set().union(*(rel[x] for x in xs))
    enabled = image(rho, K)
    received = image(sigma, eps)
    boundary = {u for u in K if neighbors[u] - K}
    actual = [K <= image(pi, enabled), eps <= image(alpha, received), bool(enabled & received), bool(boundary)]
    assert actual == patterns[witness["name"]] == witness["actual"]
    assert K and K < set(units) and eps
    for name, relation in (("alpha",alpha),("sigma",sigma),("pi",pi),("rho",rho),("neighbors",neighbors)):
        assert relation == {key: set(value) for key, value in witness["model"][name].items()}
    assert K == set(witness["model"]["kappa"]) and eps == set(witness["model"]["epsilon"])

    def subsets(xs):
        ordered = sorted(xs)
        return [{x for i, x in enumerate(ordered) if mask & (1 << i)} for mask in range(1 << len(ordered))]

    assert all((image(alpha, N) <= X) == (N <= image(sigma, X)) for N in subsets(M) for X in subsets(E))
    active = any(units[s-1] in K and units[d-1] not in K and
                 any(traces[0][t][d-1] != traces[1 << (s-1)][t][d-1] for t in range(1,c["H"]+1))
                 for s, d, _ in edges)
    assert active == witness["active_boundary"]
    assert not actual[3] or active
    minima = {}
    for u in units:
        minima[u] = []
        for mask, lost in losses.items():
            if u not in lost:
                continue
            sub = mask
            while sub:
                sub = (sub-1) & mask
                if u in losses[sub]:
                    break
            else:
                minima[u].append(mask)
        assert sorted(minima[u]) == witness["minimal_loss_masks"][u]
    collective = {u for u in units if minima[u] and all(u not in losses[1 << i] for i in range(n))}
    assert collective == set(witness["collective_only_loss"])
    print(f"PASS {witness['name']} DC={actual} M2=True branches={len(traces)}")

print(f"PASS independent replay of {total_branches} complete intervention branches; phenomenal_claim=not_certified")
