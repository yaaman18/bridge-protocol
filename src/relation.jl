abstract type Relation{X,Y} end

struct DiscreteRelation{X,Y} <: Relation{X,Y}
    fn::Function
end

DiscreteRelation(fn::Function) = DiscreteRelation{Any,Any}(fn)

apply(r::DiscreteRelation, x) = r.fn(x)
apply(f::Function, x) = f(x)

sensitivity(::DiscreteRelation, _) = nothing
update!(r::DiscreteRelation, _) = r
