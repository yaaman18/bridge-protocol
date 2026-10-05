# Reading a case record (rsb-case-record-v1) as an ERIE structure (RSB-003 §3.2).
#
# Unit i (bit i of every mask, 0-based) is the symbol :u<i>, as in the profile. C is every unit,
# M the declared outputs, E the declared inputs. The record's alpha and sigma are final-state
# changes of every unit; they are restricted here to E and M. rho is already restricted to the
# outputs by the record format.

_unit(i) = Symbol("u", i)
_bits(mask, n) = [i for i in 0:(n - 1) if (mask >> i) & 1 == 1]
_units(mask, n) = Set{Symbol}(_unit(i) for i in _bits(mask, n))
_names(set) = sort!([String(x) for x in set])

"""
    erie_model(record, structure) -> NamedTuple

`(M, E, C, alpha, sigma, pi, rho, kappa, epsilon)` with relations as Dicts of Symbol sets:
alpha : M → Set E, sigma : E → Set M, pi : M → Set C, rho : C → Set M.
"""
function erie_model(record::AbstractDict, structure)
    n = structure[:n]
    I, O = structure[:inputs], structure[:outputs]
    outs, ins = _bits(O, n), _bits(I, n)
    (M=Tuple(_unit(i) for i in outs), E=Tuple(_unit(i) for i in ins), C=Tuple(_unit(i) for i in 0:(n - 1)),
     alpha=Dict(_unit(i) => _units(record["alpha"][i + 1] & I, n) for i in outs),
     sigma=Dict(_unit(i) => _units(record["sigma"][i + 1] & O, n) for i in ins),
     pi=Dict(_unit(i) => _units(record["pi"][i + 1], n) for i in outs),
     rho=Dict(_unit(i) => _units(record["rho"][i + 1] & O, n) for i in 0:(n - 1)),
     kappa=_units(record["kappa"], n), epsilon=_units(record["epsilon"] & I, n))
end
