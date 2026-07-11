using JSON3

struct CertifiedContract
    id::String
    lean_module::String
    lean_name::String
    lean_kind::String
    julia_symbol::Union{Symbol,Nothing}
    julia_checker::Union{Symbol,Nothing}
end

struct CertifiedArtifact
    version::Int
    artifact_id::String
    contracts::Vector{CertifiedContract}
end

struct CertifiedArtifactCheck
    artifact::CertifiedArtifact
    missing_imports::Vector{String}
    missing_lean::Vector{CertifiedContract}
    missing_julia::Vector{CertifiedContract}
    missing_checkers::Vector{CertifiedContract}
end

certified_artifact_ok(check::CertifiedArtifactCheck) =
    isempty(check.missing_imports) &&
    isempty(check.missing_lean) &&
    isempty(check.missing_julia) &&
    isempty(check.missing_checkers)

const _CERTIFIED_LEAN_KINDS = Set(["structure", "def", "theorem", "inductive", "abbrev"])
const CERTIFIED_ENVELOPE_SCHEMA_VERSION = 1
const JULIA_UNVERIFIED_EXECUTION_LAYER = :julia_unverified
const UNVERIFIED_EXECUTION_BOUNDARY = :unverified_runtime

function _artifact_symbol(value::AbstractString)
    value == "-" && return nothing
    isempty(value) && return nothing
    Symbol(value)
end

function parse_certified_artifact(text::AbstractString)
    lines = [
        strip(line)
        for line in split(text, '\n')
        if !isempty(strip(line)) && !startswith(strip(line), "#")
    ]
    isempty(lines) && throw(ArgumentError("certified artifact is empty"))

    header = split(lines[1], '\t'; keepempty=true)
    length(header) == 3 && header[1] == "ERIEC_CERTIFIED_ARTIFACT" ||
        throw(ArgumentError("invalid certified artifact header"))
    version = tryparse(Int, header[2])
    version === nothing && throw(ArgumentError("invalid certified artifact version"))

    contracts = CertifiedContract[]
    seen_ids = Set{String}()
    for line in lines[2:end]
        fields = split(line, '\t'; keepempty=true)
        length(fields) == 7 && fields[1] == "contract" ||
            throw(ArgumentError("invalid certified artifact contract line: $line"))
        id = fields[2]
        id in seen_ids && throw(ArgumentError("duplicate certified contract id: $id"))
        fields[5] in _CERTIFIED_LEAN_KINDS ||
            throw(ArgumentError("unsupported Lean declaration kind: $(fields[5])"))
        push!(seen_ids, id)
        push!(
            contracts,
            CertifiedContract(
                id,
                fields[3],
                fields[4],
                fields[5],
                _artifact_symbol(fields[6]),
                _artifact_symbol(fields[7]),
            ),
        )
    end

    CertifiedArtifact(version, header[3], contracts)
end

function certified_artifact_contract_ids(artifact::CertifiedArtifact)
    [contract.id for contract in artifact.contracts]
end

function _module_source_path(project_root::AbstractString, lean_module::AbstractString)
    parts = split(lean_module, '.')
    !isempty(parts) && first(parts) == "ERIEC" ||
        throw(ArgumentError("unsupported Lean module outside ERIEC: $lean_module"))
    joinpath(project_root, "formal", joinpath(parts...) * ".lean")
end

function _module_source_paths(project_root::AbstractString, lean_module::AbstractString)
    facade = _module_source_path(project_root, lean_module)
    paths = isfile(facade) ? [facade] : String[]
    module_directory = splitext(facade)[1]
    if isdir(module_directory)
        for (root, _, files) in walkdir(module_directory)
            append!(paths, joinpath.(root, filter(file -> endswith(file, ".lean"), files)))
        end
    end
    sort!(unique!(paths))
end

function _lean_declaration_exists(
    project_root::AbstractString,
    contract::CertifiedContract,
)
    pattern = Regex(
        "(?m)^(?:noncomputable\\s+)?" *
        contract.lean_kind *
        "\\s+" *
        escape_string(contract.lean_name) *
        "\\b",
    )
    any(
        source_path -> occursin(pattern, read(source_path, String)),
        _module_source_paths(project_root, contract.lean_module),
    )
end

function _formal_entry_imports(project_root::AbstractString, lean_module::AbstractString)
    entry_path = joinpath(project_root, "formal", "ERIEC.lean")
    isfile(entry_path) || return false
    occursin("import $lean_module", read(entry_path, String))
end

function verify_certified_artifact(
    artifact::CertifiedArtifact;
    project_root::AbstractString=dirname(@__DIR__),
    julia_module::Module=@__MODULE__,
)
    missing_imports = String[]
    missing_lean = CertifiedContract[]
    missing_julia = CertifiedContract[]
    missing_checkers = CertifiedContract[]

    for lean_module in unique(contract.lean_module for contract in artifact.contracts)
        _formal_entry_imports(project_root, lean_module) ||
            push!(missing_imports, lean_module)
    end

    for contract in artifact.contracts
        _lean_declaration_exists(project_root, contract) || push!(missing_lean, contract)
        if contract.julia_symbol !== nothing &&
                !isdefined(julia_module, contract.julia_symbol)
            push!(missing_julia, contract)
        end
        if contract.julia_checker !== nothing &&
                !isdefined(julia_module, contract.julia_checker)
            push!(missing_checkers, contract)
        end
    end

    CertifiedArtifactCheck(
        artifact,
        missing_imports,
        missing_lean,
        missing_julia,
        missing_checkers,
    )
end

function read_certified_artifact(path::AbstractString)
    parse_certified_artifact(read(path, String))
end

function lean_certified_artifact(; project_root::AbstractString=dirname(@__DIR__))
    text = cd(project_root) do
        read(`lake env lean --run formal/ERIEC/CertifiedArtifact.lean`, String)
    end
    parse_certified_artifact(text)
end

function verify_lean_certified_artifact(;
    project_root::AbstractString=dirname(@__DIR__),
    julia_module::Module=@__MODULE__,
)
    verify_certified_artifact(
        lean_certified_artifact(; project_root=project_root);
        project_root=project_root,
        julia_module=julia_module,
    )
end

function certification_summary(check::CertifiedArtifactCheck)
    (
        schema_version=CERTIFIED_ENVELOPE_SCHEMA_VERSION,
        artifact_id=check.artifact.artifact_id,
        version=check.artifact.version,
        ok=certified_artifact_ok(check),
        contracts=certified_artifact_contract_ids(check.artifact),
        contract_details=[
            (
                id=contract.id,
                lean_module=contract.lean_module,
                lean_name=contract.lean_name,
                lean_kind=contract.lean_kind,
                julia_symbol=contract.julia_symbol,
                julia_checker=contract.julia_checker,
            )
            for contract in check.artifact.contracts
        ],
        missing_imports=copy(check.missing_imports),
        missing_lean=[contract.id for contract in check.missing_lean],
        missing_julia=[contract.id for contract in check.missing_julia],
        missing_checkers=[contract.id for contract in check.missing_checkers],
    )
end

function _payload_lean_contracts(payload)
    hasproperty(payload, :lean_contracts) ? collect(payload.lean_contracts) : String[]
end

function _payload_julia_checkers(payload)
    hasproperty(payload, :julia_checkers) ?
        [String(checker) for checker in payload.julia_checkers] : String[]
end

function _payload_numeric_assumptions(payload)
    hasproperty(payload, :numeric_assumptions) ?
        payload.numeric_assumptions : NamedTuple()
end

function julia_unverified_execution_boundary(;
    note::AbstractString="Julia executes the numerical system; Lean certifies only the declared boundary contracts.",
)
    (
        execution_layer=JULIA_UNVERIFIED_EXECUTION_LAYER,
        execution_certified=false,
        execution_boundary=UNVERIFIED_EXECUTION_BOUNDARY,
        execution_note=String(note),
    )
end

function _payload_execution_layer(payload)
    hasproperty(payload, :execution_layer) ?
        Symbol(String(payload.execution_layer)) : :unspecified
end

function _payload_execution_certified(payload)
    hasproperty(payload, :execution_certified) ? Bool(payload.execution_certified) : false
end

function _payload_execution_boundary(payload)
    hasproperty(payload, :execution_boundary) ?
        Symbol(String(payload.execution_boundary)) :
        (_payload_execution_layer(payload) == JULIA_UNVERIFIED_EXECUTION_LAYER ?
            UNVERIFIED_EXECUTION_BOUNDARY : :unspecified)
end

function _payload_execution_note(payload)
    hasproperty(payload, :execution_note) ? String(payload.execution_note) : ""
end

function assert_julia_unverified_execution(payload)
    layer = _payload_execution_layer(payload)
    certified = _payload_execution_certified(payload)
    if layer == JULIA_UNVERIFIED_EXECUTION_LAYER && certified
        throw(ArgumentError("Julia execution layer cannot be marked execution_certified=true"))
    end
    true
end

function certificate_trust_profile(payload)
    contracts = _payload_lean_contracts(payload)
    checkers = _payload_julia_checkers(payload)
    assumptions = _payload_numeric_assumptions(payload)
    execution_layer = _payload_execution_layer(payload)
    execution_certified = _payload_execution_certified(payload)
    (
        formally_certified=!isempty(contracts),
        runtime_checked=!isempty(checkers),
        numeric_observation=!isempty(keys(assumptions)),
        lean_contract_count=length(contracts),
        julia_checker_count=length(checkers),
        execution_layer=execution_layer,
        execution_certified=execution_certified,
        execution_boundary=_payload_execution_boundary(payload),
        execution_note=_payload_execution_note(payload),
        boundary=:lean_core_julia_shell,
    )
end

function certified_artifact_envelope(payload, check::CertifiedArtifactCheck)
    certified_artifact_ok(check) ||
        throw(ArgumentError("cannot certify payload with a failing artifact check"))
    assert_julia_unverified_execution(payload)
    known_contracts = Set(certified_artifact_contract_ids(check.artifact))
    unknown_contracts = [
        contract for contract in _payload_lean_contracts(payload)
        if !(contract in known_contracts)
    ]
    if !isempty(unknown_contracts)
        message = "payload references unknown Lean contracts: " *
            join(unknown_contracts, ", ")
        throw(ArgumentError(message))
    end
    (
        payload=payload,
        certificate=certification_summary(check),
        trust=certificate_trust_profile(payload),
    )
end

function certificate_dependency_graph(envelope)
    payload = envelope.payload
    contracts = _payload_lean_contracts(payload)
    checkers = _payload_julia_checkers(payload)
    assumptions = _payload_numeric_assumptions(payload)
    kind = hasproperty(payload, :kind) ? payload.kind : :artifact
    contract_details = hasproperty(envelope.certificate, :contract_details) ?
        envelope.certificate.contract_details : NamedTuple[]
    detail_by_id = Dict(String(detail.id) => detail for detail in contract_details)
    lean_dependencies = [
        (
            contract=contract,
            lean_module=detail_by_id[contract].lean_module,
            declaration=detail_by_id[contract].lean_name,
            kind=detail_by_id[contract].lean_kind,
        )
        for contract in contracts
        if haskey(detail_by_id, contract)
    ]
    contract_edges = [
        (from=kind, to=contract, relation=:lean_contract)
        for contract in contracts
    ]
    checker_edges = [
        (from=kind, to=checker, relation=:julia_checker)
        for checker in checkers
    ]
    lean_dependency_edges = [
        (
            from=dependency.contract,
            to="$(dependency.lean_module).$(dependency.declaration)",
            relation=:lean_dependency,
        )
        for dependency in lean_dependencies
    ]
    (
        artifact_id=envelope.certificate.artifact_id,
        payload_kind=kind,
        ok=envelope.certificate.ok,
        lean_contracts=contracts,
        lean_dependencies=lean_dependencies,
        julia_checkers=checkers,
        numeric_assumptions=assumptions,
        trust=envelope.trust,
        edges=vcat(contract_edges, checker_edges, lean_dependency_edges),
    )
end

certified_dependency_graph_json(envelope) =
    _json_value(certificate_dependency_graph(envelope))

function certified_json_artifact_audit(
    path::AbstractString;
    expected_kind::Union{Symbol,Nothing}=nothing,
)
    exists = isfile(path)
    text = exists ? read(path, String) : ""
    parsed = nothing
    parse_error = nothing
    if exists
        try
            parsed = JSON3.read(text)
        catch err
            parse_error = sprint(showerror, err)
        end
    end
    parse_ok = parsed !== nothing
    payload_ok = parse_ok && haskey(parsed, :payload) && parsed.payload !== nothing
    certificate_ok = parse_ok && haskey(parsed, :certificate) &&
        parsed.certificate !== nothing &&
        haskey(parsed.certificate, :artifact_id) &&
        haskey(parsed.certificate, :contracts)
    trust_ok = parse_ok && haskey(parsed, :trust) &&
        parsed.trust !== nothing &&
        haskey(parsed.trust, :boundary) &&
        String(parsed.trust.boundary) == "lean_core_julia_shell"
    schema_ok = certificate_ok && haskey(parsed.certificate, :schema_version) &&
        parsed.certificate.schema_version == CERTIFIED_ENVELOPE_SCHEMA_VERSION
    certificate_result_ok = certificate_ok && haskey(parsed.certificate, :ok) &&
        parsed.certificate.ok === true
    expected_kind_ok = expected_kind === nothing ||
        (payload_ok && haskey(parsed.payload, :kind) &&
            String(parsed.payload.kind) == String(expected_kind))
    ok =
        exists &&
        parse_ok &&
        schema_ok &&
        payload_ok &&
        certificate_ok &&
        trust_ok &&
        certificate_result_ok &&
        expected_kind_ok
    (
        kind=:CertifiedJsonArtifactAudit,
        ok=ok,
        path=String(path),
        expected_kind=expected_kind,
        exists=exists,
        parse_ok=parse_ok,
        parse_error=parse_error,
        schema_version=CERTIFIED_ENVELOPE_SCHEMA_VERSION,
        schema_ok=schema_ok,
        payload_ok=payload_ok,
        certificate_ok=certificate_ok,
        trust_ok=trust_ok,
        certificate_result_ok=certificate_result_ok,
        expected_kind_ok=expected_kind_ok,
    )
end

certified_json_artifact_audit_json(
    path::AbstractString;
    expected_kind::Union{Symbol,Nothing}=nothing,
) = _json_value(certified_json_artifact_audit(path; expected_kind=expected_kind))

function dc_world_bridge_certificate(bridge::DCWorldBridge)
    summary = summarize_worlddc_bridge(bridge)
    ok = check_worlddc_bridge(bridge)
    (
        kind=:DCWorldBridge,
        ok=ok,
        lean_contracts=["worlddc.bridge"],
        julia_checkers=[:check_worlddc_bridge],
        numeric_assumptions=(
            fixed_residual=summary.fixed_residual,
        ),
        claim=summary.claim,
        is_equivalence_claim=summary.is_equivalence_claim,
        is_dc=summary.is_dc,
        has_world_result=summary.has_world_result,
        act_nonempty=summary.act_nonempty,
        fixed_residual=summary.fixed_residual,
    )
end

function certified_dc_world_bridge(bridge::DCWorldBridge, check::CertifiedArtifactCheck)
    instance_certificate = dc_world_bridge_certificate(bridge)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid DCWorldBridge"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_dc_world_bridge_json(bridge::DCWorldBridge, check::CertifiedArtifactCheck) =
    _json_value(certified_dc_world_bridge(bridge, check))

function presheaf_transition_certificate(coproduct::PresheafTransitionCoproduct)
    coproduct_ok = check_presheaf_transition_coproduct(coproduct)
    naturality_ok = check_presheaf_transition_naturality(coproduct)
    (
        kind=:PresheafTransitionCoproduct,
        ok=coproduct_ok && naturality_ok,
        lean_contracts=[
            "graded.presheaf_transition_coproduct",
            "graded.presheaf_transition_naturality",
            "graded.presheaf_transition_output_copair_unique",
        ],
        julia_checkers=[
            :check_presheaf_transition_coproduct,
            :check_presheaf_transition_naturality,
        ],
        numeric_assumptions=NamedTuple(),
        labels=presheaf_transition_labels(coproduct),
        coproduct_ok=coproduct_ok,
        naturality_ok=naturality_ok,
    )
end

function certified_presheaf_transition_coproduct(
    coproduct::PresheafTransitionCoproduct,
    check::CertifiedArtifactCheck,
)
    instance_certificate = presheaf_transition_certificate(coproduct)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid presheaf transition coproduct"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_presheaf_transition_coproduct_json(
    coproduct::PresheafTransitionCoproduct,
    check::CertifiedArtifactCheck,
) = _json_value(certified_presheaf_transition_coproduct(coproduct, check))

function no_terminal_setpoint_certificate(diagram::SetPointDiagram)
    terminals = terminal_setpoints(diagram)
    (
        kind=:NoTerminalSetPoint,
        ok=isempty(terminals),
        lean_contracts=["body.no_terminal_setpoint"],
        julia_checkers=[
            :terminal_setpoints,
            :has_terminal_setpoint,
            :check_m4_no_terminal_setpoint,
        ],
        numeric_assumptions=NamedTuple(),
        object_count=length(diagram.objects),
        terminal_setpoints=terminals,
    )
end

function certified_no_terminal_setpoint(
    diagram::SetPointDiagram,
    check::CertifiedArtifactCheck,
)
    instance_certificate = no_terminal_setpoint_certificate(diagram)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify a diagram with a terminal set point"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_no_terminal_setpoint_json(
    diagram::SetPointDiagram,
    check::CertifiedArtifactCheck,
) = _json_value(certified_no_terminal_setpoint(diagram, check))

function trm_rollout_dataset_certificate(dataset::TRMRolloutDataset)
    ok = check_trm_rollout_dataset(dataset)
    action_dim = isempty(dataset.samples) ? 0 : length(first(dataset.samples).target_action)
    (
        kind=:TRMRolloutDataset,
        ok=ok,
        lean_contracts=String[],
        julia_checkers=[:check_trm_rollout_dataset],
        numeric_assumptions=NamedTuple(),
        sample_count=length(dataset.samples),
        action_dim=action_dim,
        total_weight=sum(sample.weight for sample in dataset.samples; init=0.0),
        all_world_nontrivial=all(sample.metadata.world_nontrivial for sample in dataset.samples),
        reachable_count=count(sample -> sample.metadata.reachable === true, dataset.samples),
        classifications=[sample.metadata.classification for sample in dataset.samples],
    )
end

function certified_trm_rollout_dataset(
    dataset::TRMRolloutDataset,
    check::CertifiedArtifactCheck,
)
    instance_certificate = trm_rollout_dataset_certificate(dataset)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid TRM rollout dataset"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_trm_rollout_dataset_json(
    dataset::TRMRolloutDataset,
    check::CertifiedArtifactCheck,
) = _json_value(certified_trm_rollout_dataset(dataset, check))

function trm_linear_action_model_certificate(
    model::TRMLinearActionModel,
    dataset::TRMRolloutDataset,
)
    dataset_ok = check_trm_rollout_dataset(dataset)
    feature_dim = isempty(dataset.samples) ? 0 :
        length(trm_learning_feature_vector(first(dataset.samples).observation))
    action_dim = isempty(dataset.samples) ? 0 :
        length(first(dataset.samples).target_action)
    dimensions_ok =
        size(model.weights, 1) == action_dim &&
        size(model.weights, 2) == feature_dim &&
        length(model.bias) == action_dim
    loss = dataset_ok && dimensions_ok ?
        trm_dataset_loss(observation -> trm_predict_action(model, observation), dataset) :
        Inf
    (
        kind=:TRMLinearActionModel,
        ok=dataset_ok && dimensions_ok && isfinite(loss),
        lean_contracts=String[],
        julia_checkers=[
            :check_trm_rollout_dataset,
            :trm_learning_feature_vector,
            :trm_dataset_loss,
        ],
        numeric_assumptions=(
            ridge=model.ridge,
            training_loss=model.training_loss,
            recomputed_loss=loss,
        ),
        sample_count=length(dataset.samples),
        feature_dim=feature_dim,
        action_dim=action_dim,
        dimensions_ok=dimensions_ok,
    )
end

function certified_trm_linear_action_model(
    model::TRMLinearActionModel,
    dataset::TRMRolloutDataset,
    check::CertifiedArtifactCheck,
)
    instance_certificate = trm_linear_action_model_certificate(model, dataset)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid TRM linear action model"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_trm_linear_action_model_json(
    model::TRMLinearActionModel,
    dataset::TRMRolloutDataset,
    check::CertifiedArtifactCheck,
) = _json_value(certified_trm_linear_action_model(model, dataset, check))

function _trm_training_model_certificate(model::TRMLinearActionModel, dataset::TRMRolloutDataset)
    (
        certificate=trm_linear_action_model_certificate(model, dataset),
        fit_checker=:fit_trm_linear_action_model,
        kind=:TRMTrainingStep,
    )
end

function _trm_training_model_certificate(model::TRMNeuralActionModel, dataset::TRMRolloutDataset)
    (
        certificate=trm_neural_action_model_certificate(model, dataset),
        fit_checker=:fit_trm_neural_action_model,
        kind=:TRMNeuralTrainingStep,
    )
end

function _trm_training_numeric_assumptions(
    model::TRMLinearActionModel,
    summary,
    recomputed_loss,
)
    (
        ridge=summary.ridge,
        baseline_loss=summary.baseline_loss,
        model_loss=summary.model_loss,
        recomputed_loss=recomputed_loss,
        improvement=summary.improvement,
    )
end

function _trm_training_numeric_assumptions(
    model::TRMNeuralActionModel,
    summary,
    recomputed_loss,
)
    epochs = hasproperty(summary, :epochs) ? summary.epochs : summary.cumulative_epochs
    (
        hidden_dim=summary.hidden_dim,
        activation=summary.activation,
        learning_rate=summary.learning_rate,
        epochs=epochs,
        baseline_loss=summary.baseline_loss,
        model_loss=summary.model_loss,
        recomputed_loss=recomputed_loss,
        improvement=summary.improvement,
    )
end

function trm_training_step_certificate(step::TRMTrainingStepResult)
    dataset_certificate = trm_rollout_dataset_certificate(step.dataset)
    model_info = _trm_training_model_certificate(step.model, step.dataset)
    model_certificate = model_info.certificate
    prediction_count_ok = length(step.predictions) == length(step.dataset.samples)
    prediction_dim_ok = all(
        length(prediction) == length(sample.target_action)
        for (prediction, sample) in zip(step.predictions, step.dataset.samples)
    )
    recomputed_loss = prediction_count_ok && prediction_dim_ok ?
        trm_dataset_loss(step.predictions, step.dataset) : Inf
    (
        kind=model_info.kind,
        ok=dataset_certificate.ok &&
            model_certificate.ok &&
            prediction_count_ok &&
            prediction_dim_ok &&
            isfinite(recomputed_loss) &&
            step.summary.accepted,
        lean_contracts=String[],
        julia_checkers=[
            :check_trm_rollout_dataset,
            model_info.fit_checker,
            :trm_predict_action,
            :trm_dataset_loss,
        ],
        numeric_assumptions=_trm_training_numeric_assumptions(
            step.model,
            step.summary,
            recomputed_loss,
        ),
        sample_count=step.summary.sample_count,
        action_dim=step.summary.action_dim,
        accepted=step.summary.accepted,
        prediction_count_ok=prediction_count_ok,
        prediction_dim_ok=prediction_dim_ok,
    )
end

function trm_neural_training_step_certificate(step::TRMTrainingStepResult)
    step.model isa TRMNeuralActionModel ||
        throw(ArgumentError("step model must be TRMNeuralActionModel"))
    trm_training_step_certificate(step)
end

function certified_trm_training_step(
    step::TRMTrainingStepResult,
    check::CertifiedArtifactCheck,
)
    instance_certificate = trm_training_step_certificate(step)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid TRM training step"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_trm_training_step_json(
    step::TRMTrainingStepResult,
    check::CertifiedArtifactCheck,
) = _json_value(certified_trm_training_step(step, check))

function certified_trm_neural_training_step(
    step::TRMTrainingStepResult,
    check::CertifiedArtifactCheck,
)
    instance_certificate = trm_neural_training_step_certificate(step)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid TRM neural training step"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_trm_neural_training_step_json(
    step::TRMTrainingStepResult,
    check::CertifiedArtifactCheck,
) = _json_value(certified_trm_neural_training_step(step, check))

function trm_neural_training_run_certificate(run::TRMTrainingRunResult)
    dataset_certificate = trm_rollout_dataset_certificate(run.dataset)
    !isempty(run.checkpoints) ||
        throw(ArgumentError("TRM neural training run must contain at least one checkpoint"))
    checkpoint_certificates = [
        trm_neural_training_step_certificate(checkpoint)
        for checkpoint in run.checkpoints
    ]
    losses = [checkpoint.summary.model_loss for checkpoint in run.checkpoints]
    cumulative_epochs = [
        checkpoint.summary.cumulative_epochs for checkpoint in run.checkpoints
    ]
    checkpoints_ok = all(certificate.ok for certificate in checkpoint_certificates)
    dimensions_ok = all(
        checkpoint.summary.action_dim == run.summary.action_dim &&
            checkpoint.summary.hidden_dim == run.summary.hidden_dim
        for checkpoint in run.checkpoints
    )
    (
        kind=:TRMNeuralTrainingRun,
        ok=dataset_certificate.ok &&
            checkpoints_ok &&
            dimensions_ok &&
            run.final_model isa TRMNeuralActionModel &&
            run.final_model.activation == :tanh &&
            run.summary.accepted &&
            isfinite(run.summary.final_loss),
        lean_contracts=String[],
        julia_checkers=[
            :check_trm_rollout_dataset,
            :fit_trm_neural_action_model,
            :trm_neural_training_run,
            :trm_neural_training_step_certificate,
            :trm_dataset_loss,
        ],
        numeric_assumptions=(
            activation=run.summary.activation,
            learning_rate=run.summary.learning_rate,
            checkpoint_count=run.summary.checkpoint_count,
            epochs_per_checkpoint=run.summary.epochs_per_checkpoint,
            cumulative_epochs=run.summary.cumulative_epochs,
            baseline_loss=run.summary.baseline_loss,
            initial_loss=run.summary.initial_loss,
            final_loss=run.summary.final_loss,
            improvement=run.summary.improvement,
        ),
        sample_count=run.summary.sample_count,
        action_dim=run.summary.action_dim,
        hidden_dim=run.summary.hidden_dim,
        checkpoint_losses=losses,
        checkpoint_epochs=cumulative_epochs,
        dimensions_ok=dimensions_ok,
    )
end

function certified_trm_neural_training_run(
    run::TRMTrainingRunResult,
    check::CertifiedArtifactCheck,
)
    instance_certificate = trm_neural_training_run_certificate(run)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid TRM neural training run"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_trm_neural_training_run_json(
    run::TRMTrainingRunResult,
    check::CertifiedArtifactCheck,
) = _json_value(certified_trm_neural_training_run(run, check))

function trm_neural_optimizer_state_artifact(state::TRMNeuralOptimizerState)
    model = state.model
    model isa TRMNeuralActionModel ||
        throw(ArgumentError("optimizer state model must be TRMNeuralActionModel"))
    (
        kind=:TRMNeuralOptimizerState,
        model=(
            input_weights=model.input_weights,
            hidden_bias=model.hidden_bias,
            output_weights=model.output_weights,
            output_bias=model.output_bias,
            activation=model.activation,
            learning_rate=model.learning_rate,
            epochs=model.epochs,
            training_loss=model.training_loss,
        ),
        loss_trace=state.loss_trace,
        epoch_trace=state.epoch_trace,
        summary=state.summary,
    )
end

trm_neural_optimizer_state_json(state::TRMNeuralOptimizerState) =
    _json_value(trm_neural_optimizer_state_artifact(state))

function write_trm_neural_optimizer_state(path::AbstractString, state::TRMNeuralOptimizerState)
    open(path, "w") do io
        write(io, trm_neural_optimizer_state_json(state))
        write(io, "\n")
    end
    path
end

function trm_neural_optimizer_state_certificate(state::TRMNeuralOptimizerState)
    model = state.model
    model isa TRMNeuralActionModel ||
        throw(ArgumentError("optimizer state model must be TRMNeuralActionModel"))
    loss_count_ok = length(state.loss_trace) == state.summary.checkpoint_count
    epoch_count_ok = length(state.epoch_trace) == state.summary.checkpoint_count
    monotone_epochs = all(
        state.epoch_trace[i] <= state.epoch_trace[i + 1]
        for i in 1:(length(state.epoch_trace) - 1)
    )
    final_loss_ok = !isempty(state.loss_trace) &&
        last(state.loss_trace) == state.summary.final_loss &&
        model.training_loss == state.summary.final_loss
    (
        kind=:TRMNeuralOptimizerState,
        ok=loss_count_ok &&
            epoch_count_ok &&
            monotone_epochs &&
            final_loss_ok &&
            model.activation == :tanh &&
            model.learning_rate > 0 &&
            model.epochs == state.summary.cumulative_epochs,
        lean_contracts=String[],
        julia_checkers=[
            :trm_neural_optimizer_state,
            :trm_neural_optimizer_state_artifact,
            :trm_predict_action,
        ],
        numeric_assumptions=(
            activation=state.summary.activation,
            learning_rate=state.summary.learning_rate,
            checkpoint_count=state.summary.checkpoint_count,
            cumulative_epochs=state.summary.cumulative_epochs,
            final_loss=state.summary.final_loss,
        ),
        checkpoint_count=state.summary.checkpoint_count,
        loss_count_ok=loss_count_ok,
        epoch_count_ok=epoch_count_ok,
        monotone_epochs=monotone_epochs,
        final_loss_ok=final_loss_ok,
    )
end

function certified_trm_neural_optimizer_state(
    state::TRMNeuralOptimizerState,
    check::CertifiedArtifactCheck,
)
    instance_certificate = trm_neural_optimizer_state_certificate(state)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid TRM neural optimizer state"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_trm_neural_optimizer_state_json(
    state::TRMNeuralOptimizerState,
    check::CertifiedArtifactCheck,
) = _json_value(certified_trm_neural_optimizer_state(state, check))

function write_certified_trm_neural_optimizer_state(
    path::AbstractString,
    state::TRMNeuralOptimizerState,
    check::CertifiedArtifactCheck,
)
    open(path, "w") do io
        write(io, certified_trm_neural_optimizer_state_json(state, check))
        write(io, "\n")
    end
    path
end

function trm_neural_optimizer_checkpoint_certificate(path::AbstractString)
    state = read_trm_neural_optimizer_state_tsv(path)
    state_certificate = trm_neural_optimizer_state_certificate(state)
    (
        kind=:TRMNeuralOptimizerCheckpoint,
        ok=isfile(path) && state_certificate.ok,
        lean_contracts=String[],
        julia_checkers=[
            :read_trm_neural_optimizer_state_tsv,
            :trm_neural_optimizer_state_certificate,
            :trm_neural_optimizer_state_artifact,
        ],
        numeric_assumptions=(
            checkpoint_count=state.summary.checkpoint_count,
            cumulative_epochs=state.summary.cumulative_epochs,
            final_loss=state.summary.final_loss,
            activation=state.summary.activation,
            learning_rate=state.summary.learning_rate,
        ),
        path=String(path),
        checkpoint_count=state.summary.checkpoint_count,
        cumulative_epochs=state.summary.cumulative_epochs,
        final_loss=state.summary.final_loss,
        restored_state_ok=state_certificate.ok,
        monotone_epochs=state_certificate.monotone_epochs,
        final_loss_ok=state_certificate.final_loss_ok,
    )
end

function certified_trm_neural_optimizer_checkpoint(
    path::AbstractString,
    check::CertifiedArtifactCheck,
)
    instance_certificate = trm_neural_optimizer_checkpoint_certificate(path)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid TRM neural optimizer checkpoint"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_trm_neural_optimizer_checkpoint_json(
    path::AbstractString,
    check::CertifiedArtifactCheck,
) = _json_value(certified_trm_neural_optimizer_checkpoint(path, check))

function write_certified_trm_neural_optimizer_checkpoint(
    output_path::AbstractString,
    checkpoint_path::AbstractString,
    check::CertifiedArtifactCheck,
)
    open(output_path, "w") do io
        write(io, certified_trm_neural_optimizer_checkpoint_json(checkpoint_path, check))
        write(io, "\n")
    end
    output_path
end

function trm_neural_action_model_certificate(
    model::TRMNeuralActionModel,
    dataset::TRMRolloutDataset,
)
    dataset_ok = check_trm_rollout_dataset(dataset)
    feature_dim = isempty(dataset.samples) ? 0 :
        length(trm_learning_feature_vector(first(dataset.samples).observation))
    action_dim = isempty(dataset.samples) ? 0 :
        length(first(dataset.samples).target_action)
    hidden_dim = length(model.hidden_bias)
    dimensions_ok =
        size(model.input_weights) == (hidden_dim, feature_dim) &&
        size(model.output_weights) == (action_dim, hidden_dim) &&
        length(model.output_bias) == action_dim
    loss = dataset_ok && dimensions_ok ?
        trm_dataset_loss(observation -> trm_predict_action(model, observation), dataset) :
        Inf
    (
        kind=:TRMNeuralActionModel,
        ok=dataset_ok &&
            dimensions_ok &&
            isfinite(loss) &&
            model.activation == :tanh &&
            model.learning_rate > 0 &&
            model.epochs >= 1,
        lean_contracts=String[],
        julia_checkers=[
            :check_trm_rollout_dataset,
            :trm_learning_feature_vector,
            :trm_predict_action,
            :trm_dataset_loss,
        ],
        numeric_assumptions=(
            activation=model.activation,
            learning_rate=model.learning_rate,
            epochs=model.epochs,
            training_loss=model.training_loss,
            recomputed_loss=loss,
        ),
        sample_count=length(dataset.samples),
        feature_dim=feature_dim,
        hidden_dim=hidden_dim,
        action_dim=action_dim,
        dimensions_ok=dimensions_ok,
    )
end

function certified_trm_neural_action_model(
    model::TRMNeuralActionModel,
    dataset::TRMRolloutDataset,
    check::CertifiedArtifactCheck,
)
    instance_certificate = trm_neural_action_model_certificate(model, dataset)
    instance_certificate.ok ||
        throw(ArgumentError("cannot certify an invalid TRM neural action model"))
    certified_artifact_envelope(instance_certificate, check)
end

certified_trm_neural_action_model_json(
    model::TRMNeuralActionModel,
    dataset::TRMRolloutDataset,
    check::CertifiedArtifactCheck,
) = _json_value(certified_trm_neural_action_model(model, dataset, check))

certified_observation_artifact(report::ObservationStructureReport, check::CertifiedArtifactCheck) =
    certified_artifact_envelope(observation_artifact(report), check)

certified_observation_artifact_json(
    report::ObservationStructureReport,
    check::CertifiedArtifactCheck,
) = _json_value(certified_observation_artifact(report, check))

function certified_observation_series_artifact(reports, check::CertifiedArtifactCheck)
    certified_artifact_envelope(observation_series_artifact(reports), check)
end

certified_observation_series_artifact_json(reports, check::CertifiedArtifactCheck) =
    _json_value(certified_observation_series_artifact(reports, check))

function write_certified_observation_artifact(
    path::AbstractString,
    report::ObservationStructureReport,
    check::CertifiedArtifactCheck,
)
    open(path, "w") do io
        write(io, certified_observation_artifact_json(report, check))
        write(io, "\n")
    end
    path
end

function write_certified_observation_series_artifact(
    path::AbstractString,
    reports,
    check::CertifiedArtifactCheck,
)
    open(path, "w") do io
        write(io, certified_observation_series_artifact_json(reports, check))
        write(io, "\n")
    end
    path
end
