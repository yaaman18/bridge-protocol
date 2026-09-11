"""Explicit exploratory circuits, all in the P=3/H=6/L=R=4 context.
These are not cases from the P=6 fixed-sequence search or the eight-unit candidate."""
function adjoint_measured_witnesses()
    core = [(1,5,1),(5,1,1),(2,6,1),(6,2,1)]
    configurations = [
        (name="all_four", n=6, edges=vcat(core,[(5,3,1),(6,3,-1)]),
         thresholds=(1,1,1,1,1,1), initial=(true,true,false,false,true,true)),
        (name="without_hSelf", n=6, edges=vcat(core,[(5,3,1),(6,3,1),(5,4,1),(6,4,-1)]),
         thresholds=(1,1,1,1,1,1), initial=(true,true,true,false,true,true)),
        # u3 -> u4 -> u7 -> u5 -> u3 is a gated four-cycle; u6 is the persistent motor.
        (name="without_hSMC", n=7,
         edges=[(6,1,1),(6,2,1),(7,2,1),(5,3,1),(1,3,1),(3,4,1),(4,7,1),(7,5,1),(1,6,1),(7,6,1),(3,6,1)],
         thresholds=(1,2,2,1,1,2,1), initial=(true,false,true,true,false,true,false)),
        # u3 starts with support from u4/u5, then u10/u1 take over via the delayed chain.
        # u8 disables the startup route independently of silencing u10.
        (name="without_hAct", n=11,
         edges=[(10,1,1),(11,2,1),(4,3,1),(5,3,1),(1,3,1),(3,4,1),(8,4,-1),
                (3,6,1),(6,7,1),(7,8,1),(7,10,1),(2,9,1),(9,11,1)],
         thresholds=ntuple(_ -> 1,11), initial=(false,true,true,false,true,false,false,false,false,false,true)),
        (name="without_hBound", n=6, edges=vcat(core,[(3,4,1),(4,3,1)]),
         thresholds=(1,1,1,1,1,1), initial=(true,true,true,false,true,true)),
    ]
    [(name=config.name,expected=expected,
      circuit=ModelAudit.AuditCircuit(units=ntuple(i -> Symbol("u$i"),config.n),
        motors=(Symbol("u$(config.n-1)"),Symbol("u$(config.n)")),inputs=(:u1,:u2),
        edges=config.edges,thresholds=config.thresholds,initial=config.initial,P=3,H=6,L=4,R=4))
      for (config,expected) in zip(configurations,ModelAudit.AUDIT_TARGET_PATTERNS)]
end

function adjoint_measured_witness_report()
    rows = Dict{String,Any}[]
    for witness in adjoint_measured_witnesses()
        measured = ModelAudit.measure_circuit(witness.circuit)
        background = check_adjunction_background(measured.model)
        matched = measured.result.valid && measured.result.nondegenerate &&
                  measured.result.actual == witness.expected && background.holds &&
                  (!witness.expected[4] || measured.active_boundary)
        row = ModelAudit.circuit_measurement_report(measured)
        merge!(row,Dict("name"=>witness.name,"expected"=>collect(witness.expected),
            "adjunction_holds"=>background.holds,"checked_subset_pairs"=>background.checked_pairs,
            "relative_pattern_matched"=>matched,"construction_origin"=>"explicit_P3_construction"))
        push!(rows,row)
    end
    Dict("schema_version"=>1,"phenomenal_claim"=>"not_certified","execution_certified"=>false,
        "context"=>"two_inputs_two_motors_P3_H6_L4_R4",
        "background"=>"finite_relational_galois_connection",
        "all_relative_patterns_matched"=>all(row["relative_pattern_matched"] for row in rows),
        "full_M1_M4"=>"not_established","witnesses"=>rows)
end
