struct TRMTopology
    nodes::Vector{Symbol}
    edges::Vector{Tuple{Symbol,Symbol}}

    function TRMTopology(nodes, edges)
        copied_nodes = Symbol.(collect(nodes))
        copied_edges = [(Symbol(src), Symbol(dst)) for (src, dst) in edges]
        new(copied_nodes, copied_edges)
    end
end

const DEFAULT_TRM_NODES = [:World, :Boundary, :Viability, :Action]

function topology_catalog()
    (
        feedforward=TRMTopology(
            DEFAULT_TRM_NODES,
            [(:World, :Boundary), (:Boundary, :Viability), (:Viability, :Action)],
        ),
        recurrent=TRMTopology(
            DEFAULT_TRM_NODES,
            [
                (:World, :Boundary),
                (:Boundary, :Viability),
                (:Viability, :Action),
                (:Action, :World),
            ],
        ),
        integrated=TRMTopology(
            DEFAULT_TRM_NODES,
            [
                (:World, :Boundary),
                (:Boundary, :World),
                (:Boundary, :Viability),
                (:Viability, :Boundary),
                (:Viability, :Action),
                (:Action, :World),
            ],
        ),
    )
end

function validate_topology(
    topology::TRMTopology;
    required_nodes=DEFAULT_TRM_NODES,
)
    node_set = Set(topology.nodes)
    all(node -> node in node_set, required_nodes) || return false
    all(edge -> first(edge) in node_set && last(edge) in node_set, topology.edges)
end

function topology_adjacency(topology::TRMTopology)
    validate_topology(topology) || throw(ArgumentError("topology contains unknown or missing nodes"))
    index = Dict(node => i for (i, node) in enumerate(topology.nodes))
    adjacency = falses(length(topology.nodes), length(topology.nodes))
    for (src, dst) in topology.edges
        adjacency[index[src], index[dst]] = true
    end
    adjacency
end

function classify_topology(topology::TRMTopology)
    validate_topology(topology) || return :invalid
    edge_set = Set(topology.edges)
    has_action_feedback = (:Action, :World) in edge_set || (:Action, :Boundary) in edge_set
    has_bidirectional = any(edge -> (last(edge), first(edge)) in edge_set, topology.edges)
    if has_action_feedback && has_bidirectional
        return :integrated
    elseif has_action_feedback
        return :recurrent
    end
    :feedforward
end

struct TRMProgram{P}
    topology::TRMTopology
    processors::P
end

struct TRMConsumer{P}
    program::TRMProgram{P}
    steps::Int
end

struct TRMClosedRolloutStep{I,P,F,A}
    input_action::I
    pipeline::P
    feedback_action::F
    next_adapter::A
end

struct TRMClosedRolloutResult{I,C,S,A,F}
    initial_action::I
    consumer::C
    steps::S
    final_adapter::A
    final_action::F
end

struct TRMRolloutSample{O,A,T,M}
    observation::O
    action::A
    target_action::T
    weight::Float64
    metadata::M
end

struct TRMRolloutDataset{R,S}
    rollout::R
    samples::Vector{S}
end

struct TRMLossWeights
    action::Float64
    world::Float64
    reachability::Float64
    slowing::Float64
end

struct TRMLinearActionModel{W,B}
    weights::W
    bias::B
    ridge::Float64
    training_loss::Float64
end

struct TRMTrainingStepResult{D,M,P,S}
    dataset::D
    model::M
    predictions::P
    summary::S
end

struct TRMTrainingRunResult{D,C,M,S}
    dataset::D
    checkpoints::C
    final_model::M
    summary::S
end

struct TRMNeuralOptimizerState{M,L,E,S}
    model::M
    loss_trace::L
    epoch_trace::E
    summary::S
end

struct TRMNeuralActionModel{W1,B1,W2,B2}
    input_weights::W1
    hidden_bias::B1
    output_weights::W2
    output_bias::B2
    activation::Symbol
    learning_rate::Float64
    epochs::Int
    training_loss::Float64
end

function _trm_activation(activation::Symbol, value)
    activation == :tanh || throw(ArgumentError("unsupported TRM neural activation: $activation"))
    tanh.(value)
end

function _trm_activation_derivative(activation::Symbol, activated_value)
    activation == :tanh || throw(ArgumentError("unsupported TRM neural activation: $activation"))
    1.0 .- activated_value .^ 2
end

TRMLossWeights(;
    action::Real=1.0,
    world::Real=0.0,
    reachability::Real=0.0,
    slowing::Real=0.0,
) = TRMLossWeights(
    Float64(action),
    Float64(world),
    Float64(reachability),
    Float64(slowing),
)

TRMConsumer(program::TRMProgram; steps::Integer=1) =
    TRMConsumer(program, Int(steps))

function _trm_inputs(topology::TRMTopology, state)
    inputs = Dict(node => Any[] for node in topology.nodes)
    for (src, dst) in topology.edges
        push!(inputs[dst], state[src])
    end
    inputs
end

function run_trm_program(program::TRMProgram, initial_state; steps::Integer=1)
    validate_topology(program.topology) ||
        throw(ArgumentError("invalid TRM topology"))
    steps >= 0 || throw(ArgumentError("steps must be non-negative"))
    state = Dict(Symbol(key) => value for (key, value) in pairs(initial_state))
    all(node -> haskey(state, node), program.topology.nodes) ||
        throw(ArgumentError("initial_state must contain all topology nodes"))

    for _ in 1:steps
        inputs = _trm_inputs(program.topology, state)
        next_state = copy(state)
        for node in program.topology.nodes
            processor = get(program.processors, node, nothing)
            processor === nothing && continue
            next_state[node] = processor(state[node], inputs[node], state)
        end
        state = next_state
    end
    state
end

function trm_initial_state(payload; policy::MinimalPolicy=MinimalPolicy())
    wld_result = payload.wld_result
    (
        World=world_projection(wld_result),
        Boundary=payload,
        Viability=payload.weights,
        Action=consume(policy, payload),
    )
end

function default_trm_processors(; policy::MinimalPolicy=MinimalPolicy())
    Dict{Symbol,Function}(
        :World => (current, _inputs, _state) -> current,
        :Boundary => (current, _inputs, _state) -> current,
        :Viability => (current, _inputs, _state) -> current,
        :Action => (_current, _inputs, state) -> consume(policy, (
            weighted_tensor=state[:Viability] isa AbstractVector ?
                weighted_sensitivity(state[:Boundary].tensor, state[:Viability]) :
                state[:Boundary].tensor,
            wld_result=state[:Boundary].wld_result,
        )),
    )
end

function default_trm_program(
    topology::TRMTopology=topology_catalog().recurrent;
    policy::MinimalPolicy=MinimalPolicy(),
)
    TRMProgram(topology, default_trm_processors(; policy=policy))
end

function consume(consumer::TRMConsumer, payload)
    state = run_trm_program(
        consumer.program,
        trm_initial_state(payload);
        steps=consumer.steps,
    )
    state[:Action]
end

function trm_closed_rollout_step(
    adapter::SigmaSystemAdapter,
    action::AbstractVector,
    dc_result::DCResult,
    consumer::TRMConsumer;
    normalize_pipeline::Bool=false,
    weights::Union{AbstractVector,Nothing}=nothing,
    direction::Union{AbstractVector,Nothing}=nothing,
    target::Real=1.0,
    eig_tol::Real=1e-6,
    fixed_tol::Real=1e-6,
    reachable_directions=nothing,
    action_index::Union{Integer,Nothing}=nothing,
    fm1_with_action::Union{Bool,Nothing}=nothing,
    fm1_without_action::Union{Bool,Nothing}=nothing,
    interoceptive_signal=nothing,
)
    pipeline_adapter = normalize_pipeline ?
        normalized_system_adapter(adapter, action; target=target) :
        adapter
    pipeline = run_system_pipeline(
        pipeline_adapter,
        action,
        dc_result;
        weights=weights,
        direction=direction,
        target=target,
        eig_tol=eig_tol,
        fixed_tol=fixed_tol,
        reachable_directions=reachable_directions,
        action_index=action_index,
        fm1_with_action=fm1_with_action,
        fm1_without_action=fm1_without_action,
        interoceptive_signal=interoceptive_signal,
    )
    feedback_action = collect(consume(consumer, pipeline))
    next_adapter = advance_system_adapter(adapter, feedback_action)
    TRMClosedRolloutStep(copy(action), pipeline, feedback_action, next_adapter)
end

function run_trm_closed_rollout(
    adapter::SigmaSystemAdapter,
    initial_action::AbstractVector,
    dc_result::DCResult;
    consumer::TRMConsumer=TRMConsumer(default_trm_program()),
    steps::Integer=1,
    kwargs...,
)
    steps >= 0 || throw(ArgumentError("steps must be non-negative"))
    current_adapter = adapter
    current_action = copy(initial_action)
    rollout_steps = TRMClosedRolloutStep[]

    for _ in 1:steps
        step = trm_closed_rollout_step(
            current_adapter,
            current_action,
            dc_result,
            consumer;
            kwargs...,
        )
        push!(rollout_steps, step)
        current_adapter = step.next_adapter
        current_action = step.feedback_action
    end

    TRMClosedRolloutResult(
        copy(initial_action),
        consumer,
        rollout_steps,
        current_adapter,
        copy(current_action),
    )
end

function summarize_trm_closed_rollout(result::TRMClosedRolloutResult)
    (
        steps=length(result.steps),
        initial_action=result.initial_action,
        feedback_actions=[step.feedback_action for step in result.steps],
        final_action=result.final_action,
        final_state=result.final_adapter.state,
        world_nontrivial=[
            world_nontrivial(step.pipeline.wld_result)
            for step in result.steps
        ],
        classifications=[
            step.pipeline.classification
            for step in result.steps
        ],
        slowing_scores=[
            step.pipeline.slowing_score
            for step in result.steps
        ],
    )
end

function trm_learning_observation(step::TRMClosedRolloutStep)
    pipeline = step.pipeline
    (
        input_action=step.input_action,
        sensory=pipeline.sensory,
        weighted_tensor=pipeline.weighted_tensor,
        world_projection=world_projection(pipeline.wld_result),
        viability_weights=pipeline.weights,
        slowing_score=pipeline.slowing_score,
        classification=pipeline.classification,
    )
end

trm_learning_target(step::TRMClosedRolloutStep) = copy(step.feedback_action)

function trm_rollout_sample(
    step::TRMClosedRolloutStep,
    index::Integer;
    observation_fn=trm_learning_observation,
    target_fn=trm_learning_target,
    weight_fn=(_step, _index) -> 1.0,
)
    pipeline = step.pipeline
    reachable = pipeline.reachability === nothing ? nothing : pipeline.reachability.reachable
    metadata = (
        index=Int(index),
        world_nontrivial=world_nontrivial(pipeline.wld_result),
        reachable=reachable,
        slowing_score=pipeline.slowing_score,
        classification=pipeline.classification,
    )
    TRMRolloutSample(
        observation_fn(step),
        copy(step.input_action),
        collect(target_fn(step)),
        Float64(weight_fn(step, index)),
        metadata,
    )
end

function trm_rollout_dataset(
    rollout::TRMClosedRolloutResult;
    observation_fn=trm_learning_observation,
    target_fn=trm_learning_target,
    weight_fn=(_step, _index) -> 1.0,
)
    samples = [
        trm_rollout_sample(
            step,
            index;
            observation_fn=observation_fn,
            target_fn=target_fn,
            weight_fn=weight_fn,
        )
        for (index, step) in enumerate(rollout.steps)
    ]
    TRMRolloutDataset(rollout, samples)
end

function trm_rollout_dataset(
    rollouts::AbstractVector;
    observation_fn=trm_learning_observation,
    target_fn=trm_learning_target,
    weight_fn=(_step, _index) -> 1.0,
)
    samples = TRMRolloutSample[]
    for rollout in rollouts
        append!(
            samples,
            trm_rollout_dataset(
                rollout;
                observation_fn=observation_fn,
                target_fn=target_fn,
                weight_fn=weight_fn,
            ).samples,
        )
    end
    TRMRolloutDataset(rollouts, samples)
end

function check_trm_rollout_dataset(dataset::TRMRolloutDataset)
    isempty(dataset.samples) && return false
    action_dim = length(first(dataset.samples).target_action)
    all(sample -> length(sample.action) == action_dim &&
        length(sample.target_action) == action_dim &&
        sample.weight >= 0, dataset.samples)
end

function trm_action_mse(predicted_action::AbstractVector, target_action::AbstractVector)
    length(predicted_action) == length(target_action) ||
        throw(DimensionMismatch("predicted and target actions must have the same length"))
    isempty(target_action) && throw(ArgumentError("target action must be non-empty"))
    sum(abs2, predicted_action .- target_action) / length(target_action)
end

function _trm_static_penalty(sample::TRMRolloutSample, weights::TRMLossWeights)
    world_penalty = sample.metadata.world_nontrivial ? 0.0 : 1.0
    reachability_penalty = sample.metadata.reachable === false ? 1.0 : 0.0
    slowing_penalty = abs(Float64(sample.metadata.slowing_score))
    weights.world * world_penalty +
        weights.reachability * reachability_penalty +
        weights.slowing * slowing_penalty
end

function trm_sample_loss(
    predicted_action::AbstractVector,
    sample::TRMRolloutSample;
    weights::TRMLossWeights=TRMLossWeights(),
)
    action_loss = trm_action_mse(predicted_action, sample.target_action)
    sample.weight * (weights.action * action_loss + _trm_static_penalty(sample, weights))
end

function trm_dataset_loss(
    predictions::AbstractVector,
    dataset::TRMRolloutDataset;
    weights::TRMLossWeights=TRMLossWeights(),
)
    length(predictions) == length(dataset.samples) ||
        throw(DimensionMismatch("prediction count must match dataset sample count"))
    isempty(dataset.samples) && throw(ArgumentError("dataset must be non-empty"))
    total_weight = sum(sample.weight for sample in dataset.samples)
    total_weight > 0 || throw(ArgumentError("dataset total weight must be positive"))
    sum(
        trm_sample_loss(prediction, sample; weights=weights)
        for (prediction, sample) in zip(predictions, dataset.samples)
    ) / total_weight
end

function trm_dataset_loss(
    predictor,
    dataset::TRMRolloutDataset;
    weights::TRMLossWeights=TRMLossWeights(),
)
    trm_dataset_loss(
        [predictor(sample.observation) for sample in dataset.samples],
        dataset;
        weights=weights,
    )
end

function _append_trm_numeric!(values::Vector{Float64}, value)
    if value isa Real
        push!(values, Float64(value))
    elseif value isa AbstractArray
        append!(values, Float64.(vec(value)))
    elseif value isa Tuple || value isa NamedTuple
        for item in value
            _append_trm_numeric!(values, item)
        end
    end
    values
end

function trm_learning_feature_vector(observation)
    values = Float64[]
    for field in (:input_action, :sensory, :weighted_tensor, :world_projection,
        :viability_weights, :slowing_score)
        hasproperty(observation, field) || continue
        _append_trm_numeric!(values, getproperty(observation, field))
    end
    isempty(values) && throw(ArgumentError("observation exposes no numeric TRM learning features"))
    values
end

function trm_predict_action(model::TRMLinearActionModel, observation)
    features = trm_learning_feature_vector(observation)
    length(features) == size(model.weights, 2) ||
        throw(DimensionMismatch("feature dimension does not match TRM linear action model"))
    model.weights * features .+ model.bias
end

function trm_predict_action(model::TRMNeuralActionModel, observation)
    features = trm_learning_feature_vector(observation)
    length(features) == size(model.input_weights, 2) ||
        throw(DimensionMismatch("feature dimension does not match TRM neural action model"))
    hidden = _trm_activation(model.activation, model.input_weights * features .+ model.hidden_bias)
    model.output_weights * hidden .+ model.output_bias
end

function fit_trm_linear_action_model(
    dataset::TRMRolloutDataset;
    ridge::Real=1e-6,
    weights::TRMLossWeights=TRMLossWeights(),
)
    check_trm_rollout_dataset(dataset) ||
        throw(ArgumentError("dataset must satisfy TRM rollout dataset checks"))
    ridge >= 0 || throw(ArgumentError("ridge must be non-negative"))
    features = [trm_learning_feature_vector(sample.observation) for sample in dataset.samples]
    feature_dim = length(first(features))
    all(feature -> length(feature) == feature_dim, features) ||
        throw(DimensionMismatch("all TRM learning feature vectors must have the same length"))
    action_dim = length(first(dataset.samples).target_action)
    sample_count = length(dataset.samples)
    x = ones(Float64, sample_count, feature_dim + 1)
    y = zeros(Float64, sample_count, action_dim)
    for (index, feature) in enumerate(features)
        x[index, 2:end] .= feature
        y[index, :] .= dataset.samples[index].target_action
    end
    penalty = Matrix{Float64}(I, feature_dim + 1, feature_dim + 1)
    penalty[1, 1] = 0.0
    coeff = pinv(x' * x + Float64(ridge) * penalty) * (x' * y)
    bias = vec(coeff[1, :])
    model_weights = Matrix(coeff[2:end, :]')
    model = TRMLinearActionModel(
        model_weights,
        bias,
        Float64(ridge),
        0.0,
    )
    loss = trm_dataset_loss(observation -> trm_predict_action(model, observation), dataset; weights=weights)
    TRMLinearActionModel(model.weights, model.bias, model.ridge, loss)
end

function trm_linear_training_step(
    dataset::TRMRolloutDataset;
    ridge::Real=1e-6,
    weights::TRMLossWeights=TRMLossWeights(),
    improvement_tol::Real=1e-10,
)
    check_trm_rollout_dataset(dataset) ||
        throw(ArgumentError("dataset must satisfy TRM rollout dataset checks"))
    action_dim = length(first(dataset.samples).target_action)
    baseline_predictions = [zeros(Float64, action_dim) for _ in dataset.samples]
    baseline_loss = trm_dataset_loss(baseline_predictions, dataset; weights=weights)
    model = fit_trm_linear_action_model(dataset; ridge=ridge, weights=weights)
    predictions = [trm_predict_action(model, sample.observation) for sample in dataset.samples]
    model_loss = trm_dataset_loss(predictions, dataset; weights=weights)
    improvement = baseline_loss - model_loss
    summary = (
        accepted=model_loss <= baseline_loss + Float64(improvement_tol),
        baseline_loss=baseline_loss,
        model_loss=model_loss,
        improvement=improvement,
        ridge=model.ridge,
        sample_count=length(dataset.samples),
        action_dim=action_dim,
    )
    TRMTrainingStepResult(dataset, model, predictions, summary)
end

function _initial_trm_neural_weights(hidden_dim::Integer, feature_dim::Integer, action_dim::Integer)
    hidden_dim > 0 || throw(ArgumentError("hidden_dim must be positive"))
    input_weights = [
        0.05 * sin(0.37 * i + 0.19 * j)
        for i in 1:hidden_dim, j in 1:feature_dim
    ]
    hidden_bias = zeros(Float64, hidden_dim)
    output_weights = [
        0.05 * cos(0.23 * i + 0.41 * j)
        for i in 1:action_dim, j in 1:hidden_dim
    ]
    output_bias = zeros(Float64, action_dim)
    input_weights, hidden_bias, output_weights, output_bias
end

function fit_trm_neural_action_model(
    dataset::TRMRolloutDataset;
    hidden_dim::Integer=8,
    activation::Symbol=:tanh,
    learning_rate::Real=1e-2,
    epochs::Integer=50,
    weights::TRMLossWeights=TRMLossWeights(),
    initial_model::Union{TRMNeuralActionModel,Nothing}=nothing,
)
    check_trm_rollout_dataset(dataset) ||
        throw(ArgumentError("dataset must satisfy TRM rollout dataset checks"))
    hidden_dim > 0 || throw(ArgumentError("hidden_dim must be positive"))
    activation == :tanh || throw(ArgumentError("unsupported TRM neural activation: $activation"))
    learning_rate > 0 || throw(ArgumentError("learning_rate must be positive"))
    epochs >= 1 || throw(ArgumentError("epochs must be at least 1"))

    features = [trm_learning_feature_vector(sample.observation) for sample in dataset.samples]
    feature_dim = length(first(features))
    all(feature -> length(feature) == feature_dim, features) ||
        throw(DimensionMismatch("all TRM learning feature vectors must have the same length"))
    action_dim = length(first(dataset.samples).target_action)
    start_epochs = 0
    if initial_model === nothing
        input_weights, hidden_bias, output_weights, output_bias =
            _initial_trm_neural_weights(hidden_dim, feature_dim, action_dim)
    else
        initial_model.activation == activation ||
            throw(ArgumentError("initial_model activation does not match requested activation"))
        size(initial_model.input_weights) == (hidden_dim, feature_dim) ||
            throw(DimensionMismatch("initial_model input weights do not match dataset feature dimension"))
        size(initial_model.output_weights) == (action_dim, hidden_dim) ||
            throw(DimensionMismatch("initial_model output weights do not match dataset action dimension"))
        length(initial_model.hidden_bias) == hidden_dim ||
            throw(DimensionMismatch("initial_model hidden bias does not match hidden_dim"))
        length(initial_model.output_bias) == action_dim ||
            throw(DimensionMismatch("initial_model output bias does not match action dimension"))
        input_weights = copy(initial_model.input_weights)
        hidden_bias = copy(initial_model.hidden_bias)
        output_weights = copy(initial_model.output_weights)
        output_bias = copy(initial_model.output_bias)
        start_epochs = initial_model.epochs
    end
    total_weight = sum(sample.weight for sample in dataset.samples)
    total_weight > 0 || throw(ArgumentError("dataset total weight must be positive"))
    action_scale = weights.action <= 0 ? 1.0 : weights.action

    for _ in 1:epochs
        grad_w1 = zeros(Float64, hidden_dim, feature_dim)
        grad_b1 = zeros(Float64, hidden_dim)
        grad_w2 = zeros(Float64, action_dim, hidden_dim)
        grad_b2 = zeros(Float64, action_dim)

        for (feature, sample) in zip(features, dataset.samples)
            hidden_pre = input_weights * feature .+ hidden_bias
            hidden = _trm_activation(activation, hidden_pre)
            prediction = output_weights * hidden .+ output_bias
            error = prediction .- sample.target_action
            sample_scale = action_scale * sample.weight / (total_weight * action_dim)
            grad_output = 2.0 * sample_scale .* error
            grad_w2 .+= grad_output * hidden'
            grad_b2 .+= grad_output
            grad_hidden = (output_weights' * grad_output) .*
                _trm_activation_derivative(activation, hidden)
            grad_w1 .+= grad_hidden * feature'
            grad_b1 .+= grad_hidden
        end

        input_weights .-= Float64(learning_rate) .* grad_w1
        hidden_bias .-= Float64(learning_rate) .* grad_b1
        output_weights .-= Float64(learning_rate) .* grad_w2
        output_bias .-= Float64(learning_rate) .* grad_b2
    end

    model = TRMNeuralActionModel(
        input_weights,
        hidden_bias,
        output_weights,
        output_bias,
        activation,
        Float64(learning_rate),
        start_epochs + Int(epochs),
        0.0,
    )
    loss = trm_dataset_loss(observation -> trm_predict_action(model, observation), dataset; weights=weights)
    TRMNeuralActionModel(
        model.input_weights,
        model.hidden_bias,
        model.output_weights,
        model.output_bias,
        model.activation,
        model.learning_rate,
        model.epochs,
        loss,
    )
end

function trm_neural_training_step(
    dataset::TRMRolloutDataset;
    hidden_dim::Integer=8,
    activation::Symbol=:tanh,
    learning_rate::Real=1e-2,
    epochs::Integer=50,
    weights::TRMLossWeights=TRMLossWeights(),
    improvement_tol::Real=1e-10,
)
    check_trm_rollout_dataset(dataset) ||
        throw(ArgumentError("dataset must satisfy TRM rollout dataset checks"))
    action_dim = length(first(dataset.samples).target_action)
    baseline_predictions = [zeros(Float64, action_dim) for _ in dataset.samples]
    baseline_loss = trm_dataset_loss(baseline_predictions, dataset; weights=weights)
    model = fit_trm_neural_action_model(
        dataset;
        hidden_dim=hidden_dim,
        activation=activation,
        learning_rate=learning_rate,
        epochs=epochs,
        weights=weights,
    )
    predictions = [trm_predict_action(model, sample.observation) for sample in dataset.samples]
    model_loss = trm_dataset_loss(predictions, dataset; weights=weights)
    improvement = baseline_loss - model_loss
    summary = (
        accepted=model_loss <= baseline_loss + Float64(improvement_tol),
        baseline_loss=baseline_loss,
        model_loss=model_loss,
        improvement=improvement,
        hidden_dim=hidden_dim,
        activation=activation,
        learning_rate=model.learning_rate,
        epochs=model.epochs,
        sample_count=length(dataset.samples),
        action_dim=action_dim,
    )
    TRMTrainingStepResult(dataset, model, predictions, summary)
end

function trm_neural_training_run(
    dataset::TRMRolloutDataset;
    hidden_dim::Integer=8,
    activation::Symbol=:tanh,
    learning_rate::Real=1e-2,
    checkpoint_count::Integer=3,
    epochs_per_checkpoint::Integer=10,
    weights::TRMLossWeights=TRMLossWeights(),
    improvement_tol::Real=1e-10,
    initial_model::Union{TRMNeuralActionModel,Nothing}=nothing,
)
    check_trm_rollout_dataset(dataset) ||
        throw(ArgumentError("dataset must satisfy TRM rollout dataset checks"))
    checkpoint_count >= 1 || throw(ArgumentError("checkpoint_count must be at least 1"))
    epochs_per_checkpoint >= 1 || throw(ArgumentError("epochs_per_checkpoint must be at least 1"))
    action_dim = length(first(dataset.samples).target_action)
    baseline_predictions = [zeros(Float64, action_dim) for _ in dataset.samples]
    baseline_loss = trm_dataset_loss(baseline_predictions, dataset; weights=weights)
    checkpoints = TRMTrainingStepResult[]
    model = initial_model

    for checkpoint_index in 1:checkpoint_count
        model = fit_trm_neural_action_model(
            dataset;
            hidden_dim=hidden_dim,
            activation=activation,
            learning_rate=learning_rate,
            epochs=epochs_per_checkpoint,
            weights=weights,
            initial_model=model,
        )
        predictions = [trm_predict_action(model, sample.observation) for sample in dataset.samples]
        model_loss = trm_dataset_loss(predictions, dataset; weights=weights)
        improvement = baseline_loss - model_loss
        summary = (
            accepted=model_loss <= baseline_loss + Float64(improvement_tol),
            checkpoint_index=checkpoint_index,
            baseline_loss=baseline_loss,
            model_loss=model_loss,
            improvement=improvement,
            hidden_dim=hidden_dim,
            activation=activation,
            learning_rate=model.learning_rate,
            epochs_per_checkpoint=Int(epochs_per_checkpoint),
            cumulative_epochs=model.epochs,
            sample_count=length(dataset.samples),
            action_dim=action_dim,
        )
        push!(checkpoints, TRMTrainingStepResult(dataset, model, predictions, summary))
    end

    losses = [checkpoint.summary.model_loss for checkpoint in checkpoints]
    summary = (
        accepted=all(checkpoint.summary.accepted for checkpoint in checkpoints),
        checkpoint_count=length(checkpoints),
        epochs_per_checkpoint=Int(epochs_per_checkpoint),
        cumulative_epochs=last(checkpoints).summary.cumulative_epochs,
        baseline_loss=baseline_loss,
        initial_loss=first(losses),
        final_loss=last(losses),
        improvement=baseline_loss - last(losses),
        hidden_dim=hidden_dim,
        activation=activation,
        learning_rate=Float64(learning_rate),
        sample_count=length(dataset.samples),
        action_dim=action_dim,
    )
    TRMTrainingRunResult(dataset, checkpoints, last(checkpoints).model, summary)
end

function trm_neural_optimizer_state(run::TRMTrainingRunResult)
    !isempty(run.checkpoints) ||
        throw(ArgumentError("TRM neural training run must contain at least one checkpoint"))
    run.final_model isa TRMNeuralActionModel ||
        throw(ArgumentError("TRM neural optimizer state requires a neural final model"))
    loss_trace = [checkpoint.summary.model_loss for checkpoint in run.checkpoints]
    epoch_trace = [checkpoint.summary.cumulative_epochs for checkpoint in run.checkpoints]
    summary = (
        checkpoint_count=length(run.checkpoints),
        activation=run.summary.activation,
        learning_rate=run.summary.learning_rate,
        cumulative_epochs=run.summary.cumulative_epochs,
        final_loss=run.summary.final_loss,
        hidden_dim=run.summary.hidden_dim,
        action_dim=run.summary.action_dim,
        sample_count=run.summary.sample_count,
    )
    TRMNeuralOptimizerState(run.final_model, loss_trace, epoch_trace, summary)
end
