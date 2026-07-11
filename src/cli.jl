struct LeniaReportCLIOptions
    preset::Union{Symbol,Nothing}
    preset_file::Union{String,Nothing}
    shape::Tuple{Int,Int}
    action_count::Int
    feature_count::Int
    feature_counts::Vector{Int}
    kernel_size::Int
    tau_steps::Vector{Int}
    output::Union{String,Nothing}
    output_dir::Union{String,Nothing}
    eig_tol::Float64
    fixed_tol::Float64
    seed::Int
    repeats::Int
    relative_tolerance::Float64
    lambda_threshold::Float64
    initial_mode::Symbol
    initial_baseline::Float64
    initial_amplitude::Float64
    initial_width::Float64
    resume::Bool
    certified::Bool
    run_indices::Union{Vector{Int},Nothing}
    dry_run::Bool
    help::Bool
end

struct TRMNeuralExperimentCLIOptions
    preset::Symbol
    preset_file::Union{String,Nothing}
    system::Symbol
    shape::Tuple{Int,Int}
    action_count::Int
    feature_count::Int
    kernel_size::Int
    rollout_steps::Int
    hidden_dims::Vector{Int}
    learning_rates::Vector{Float64}
    checkpoint_counts::Vector{Int}
    epochs_per_checkpoint_values::Vector{Int}
    output_dir::Union{String,Nothing}
    resume::Bool
    continue_from_optimizer::Bool
    certified::Bool
    eig_tol::Float64
    fixed_tol::Float64
    help::Bool
end

function lenia_report_usage()
    """
    Usage: eriec-lenia-report [options]

    Options:
      --preset smoke|short|long  Run a managed named experiment preset.
      --preset-file PATH       Load a managed key=value or TSV preset.
      --shape ROWSxCOLS        Field shape (default: 5x5)
      --action-count N         Number of action basis fields (default: 16)
      --feature-count N        Number of Lenia features: 6, 32, or 64 (default: 32)
      --feature-counts LIST    Comma-separated feature counts for grid sweep, e.g. 6,32
      --kernel-size N          Odd Lenia kernel size (default: 5)
      --tau-steps LIST         Comma-separated tau steps, e.g. 1 or 1,2,4 (default: 1)
      --output PATH            Write artifact JSON to PATH. Use - or omit for stdout.
      --output-dir DIR         Write artifact.json and summary.json under DIR.
      --eig-tol X              Eigenvalue tolerance (default: 1e-6)
      --fixed-tol X            Fixed-direction tolerance (default: 1e-5)
      --seed N                 Reproducibility seed (default: 42)
      --repeats N              Runs per condition, at least 2 (default: 3)
      --relative-tolerance X   Maximum relative deviation (default: 0.01)
      --lambda-threshold X     Critical slowing threshold (default: 0.95)
      --initial-mode MODE      zeros, uniform_noise, or gaussian_blob (default: zeros)
      --initial-baseline X     Initial field baseline (default: 0.0)
      --initial-amplitude X    Initial field amplitude (default: 0.1)
      --initial-width X        Gaussian blob width (default: 0.25)
      --resume                 Reuse matching completed preset run directories.
      --certified              Attach Lean-verified certificate envelopes.
      --run-indices LIST       Run only selected stable condition indices.
      --dry-run                Print the managed experiment plan without running.
      --help                   Show this message
    """
end

function trm_neural_experiment_usage()
    """
    Usage: eriec-trm-neural-experiment [options]

    Options:
      --system toy|lenia            Adapter system preset (default: toy)
      --preset smoke|short|long      Named experiment preset (default: smoke)
      --preset-file PATH            Load key=value or TSV preset file.
      --shape ROWSxCOLS             Lenia field shape (default: 3x3)
      --action-count N              Action dimension (default: 2)
      --feature-count N             Lenia features: 6, 32, or 64 (default: 6)
      --kernel-size N               Odd Lenia kernel size (default: 3)
      --rollout-steps N             Closed rollout steps per run (default: 2)
      --hidden-dims LIST            Comma-separated hidden dims (default: 4)
      --learning-rates LIST         Comma-separated learning rates (default: 0.05)
      --checkpoint-counts LIST      Comma-separated checkpoint counts (default: 2)
      --epochs-per-checkpoint LIST  Comma-separated epoch counts (default: 5)
      --output-dir DIR              Write run artifacts and summary under DIR.
      --resume                      Reuse completed matching run directories.
      --continue                    Continue incomplete runs from optimizer-state.tsv.
      --certified                   Attach certified JSON artifacts where available.
      --eig-tol X                   Eigenvalue tolerance (default: 1e-10)
      --fixed-tol X                 Fixed-direction tolerance (default: 1e-6)
      --help                        Show this message
    """
end

function _parse_cli_shape(value::AbstractString)
    parts = split(replace(value, "x" => ",", "X" => ","), ",")
    length(parts) == 2 ||
        throw(ArgumentError("shape must be ROWSxCOLS or ROWS,COLS"))
    rows, cols = parse.(Int, parts)
    rows > 0 && cols > 0 ||
        throw(ArgumentError("shape dimensions must be positive"))
    (rows, cols)
end

function _parse_cli_int(value::AbstractString, name::AbstractString)
    parsed = parse(Int, value)
    parsed > 0 || throw(ArgumentError("$name must be positive"))
    parsed
end

function _parse_tau_steps(value::AbstractString)
    steps = [_parse_cli_int(strip(part), "tau step") for part in split(value, ",")]
    isempty(steps) && throw(ArgumentError("tau steps must be non-empty"))
    steps
end

function _parse_cli_int_list(value::AbstractString, name::AbstractString)
    parsed = [_parse_cli_int(strip(part), name) for part in split(value, ",")]
    isempty(parsed) && throw(ArgumentError("$name list must be non-empty"))
    parsed
end

function _parse_cli_float(value::AbstractString, name::AbstractString)
    parsed = Float64(parse(Float64, value))
    parsed > 0 || throw(ArgumentError("$name must be positive"))
    parsed
end

function _parse_cli_float_list(value::AbstractString, name::AbstractString)
    parsed = [_parse_cli_float(strip(part), name) for part in split(value, ",")]
    isempty(parsed) && throw(ArgumentError("$name list must be non-empty"))
    parsed
end

function _parse_feature_counts(value::AbstractString)
    counts = [_parse_cli_int(strip(part), "feature count") for part in split(value, ",")]
    isempty(counts) && throw(ArgumentError("feature counts must be non-empty"))
    all(count -> count in (6, 32, 64), counts) ||
        throw(ArgumentError("feature-counts must contain only 6, 32, or 64"))
    counts
end

function parse_lenia_report_args(args=ARGS)
    preset = nothing
    preset_file = nothing
    shape = (5, 5)
    action_count = 16
    feature_count = 32
    feature_counts = nothing
    kernel_size = 5
    tau_steps = [1]
    output = nothing
    output_dir = nothing
    eig_tol = 1e-6
    fixed_tol = 1e-5
    seed = DEFAULT_EXPERIMENT_SEED
    repeats = DEFAULT_REPRODUCIBILITY_REPEATS
    relative_tolerance = DEFAULT_REPRODUCIBILITY_REL_TOL
    lambda_threshold = DEFAULT_CRITICAL_SLOWING_THRESHOLD
    initial_mode = :zeros
    initial_baseline = 0.0
    initial_amplitude = 0.1
    initial_width = 0.25
    resume = false
    certified = false
    run_indices = nothing
    dry_run = false
    help = false

    index = 1
    while index <= length(args)
        arg = args[index]
        if arg == "--help" || arg == "-h"
            help = true
            index += 1
        elseif arg == "--preset"
            index += 1
            index <= length(args) || throw(ArgumentError("--preset requires a value"))
            preset = Symbol(args[index])
            preset_file = nothing
            selected = lenia_experiment_preset(preset)
            shape = selected.shape
            action_count = selected.action_count
            feature_count = first(selected.feature_counts)
            feature_counts = copy(selected.feature_counts)
            kernel_size = selected.kernel_size
            tau_steps = copy(selected.tau_steps)
            seed = selected.acceptance.seed
            repeats = selected.acceptance.repeats
            relative_tolerance = selected.acceptance.relative_tolerance
            lambda_threshold = selected.acceptance.lambda_threshold
            eig_tol = selected.acceptance.eig_tol
            initial_mode = selected.initial_condition.mode
            initial_baseline = selected.initial_condition.baseline
            initial_amplitude = selected.initial_condition.amplitude
            initial_width = selected.initial_condition.width
            index += 1
        elseif arg == "--preset-file"
            index += 1
            index <= length(args) || throw(ArgumentError("--preset-file requires a value"))
            preset_file = args[index]
            selected = read_lenia_experiment_preset(preset_file)
            preset = selected.name
            shape = selected.shape
            action_count = selected.action_count
            feature_count = first(selected.feature_counts)
            feature_counts = copy(selected.feature_counts)
            kernel_size = selected.kernel_size
            tau_steps = copy(selected.tau_steps)
            seed = selected.acceptance.seed
            repeats = selected.acceptance.repeats
            relative_tolerance = selected.acceptance.relative_tolerance
            lambda_threshold = selected.acceptance.lambda_threshold
            eig_tol = selected.acceptance.eig_tol
            initial_mode = selected.initial_condition.mode
            initial_baseline = selected.initial_condition.baseline
            initial_amplitude = selected.initial_condition.amplitude
            initial_width = selected.initial_condition.width
            index += 1
        elseif arg == "--shape"
            index += 1
            index <= length(args) || throw(ArgumentError("--shape requires a value"))
            shape = _parse_cli_shape(args[index])
            index += 1
        elseif arg == "--action-count"
            index += 1
            index <= length(args) || throw(ArgumentError("--action-count requires a value"))
            action_count = _parse_cli_int(args[index], "action-count")
            index += 1
        elseif arg == "--feature-count"
            index += 1
            index <= length(args) || throw(ArgumentError("--feature-count requires a value"))
            feature_count = _parse_cli_int(args[index], "feature-count")
            feature_counts = nothing
            index += 1
        elseif arg == "--feature-counts"
            index += 1
            index <= length(args) || throw(ArgumentError("--feature-counts requires a value"))
            feature_counts = _parse_feature_counts(args[index])
            feature_count = first(feature_counts)
            index += 1
        elseif arg == "--kernel-size"
            index += 1
            index <= length(args) || throw(ArgumentError("--kernel-size requires a value"))
            kernel_size = _parse_cli_int(args[index], "kernel-size")
            index += 1
        elseif arg == "--tau-steps"
            index += 1
            index <= length(args) || throw(ArgumentError("--tau-steps requires a value"))
            tau_steps = _parse_tau_steps(args[index])
            index += 1
        elseif arg == "--output"
            index += 1
            index <= length(args) || throw(ArgumentError("--output requires a value"))
            output = args[index]
            index += 1
        elseif arg == "--output-dir"
            index += 1
            index <= length(args) || throw(ArgumentError("--output-dir requires a value"))
            output_dir = args[index]
            index += 1
        elseif arg == "--eig-tol"
            index += 1
            index <= length(args) || throw(ArgumentError("--eig-tol requires a value"))
            eig_tol = Float64(parse(Float64, args[index]))
            index += 1
        elseif arg == "--fixed-tol"
            index += 1
            index <= length(args) || throw(ArgumentError("--fixed-tol requires a value"))
            fixed_tol = Float64(parse(Float64, args[index]))
            index += 1
        elseif arg == "--seed"
            index += 1
            index <= length(args) || throw(ArgumentError("--seed requires a value"))
            seed = parse(Int, args[index])
            index += 1
        elseif arg == "--repeats"
            index += 1
            index <= length(args) || throw(ArgumentError("--repeats requires a value"))
            repeats = _parse_cli_int(args[index], "repeats")
            index += 1
        elseif arg == "--relative-tolerance"
            index += 1
            index <= length(args) ||
                throw(ArgumentError("--relative-tolerance requires a value"))
            relative_tolerance = Float64(parse(Float64, args[index]))
            index += 1
        elseif arg == "--lambda-threshold"
            index += 1
            index <= length(args) ||
                throw(ArgumentError("--lambda-threshold requires a value"))
            lambda_threshold = Float64(parse(Float64, args[index]))
            index += 1
        elseif arg == "--initial-mode"
            index += 1
            index <= length(args) || throw(ArgumentError("--initial-mode requires a value"))
            initial_mode = Symbol(args[index])
            index += 1
        elseif arg == "--initial-baseline"
            index += 1
            index <= length(args) ||
                throw(ArgumentError("--initial-baseline requires a value"))
            initial_baseline = Float64(parse(Float64, args[index]))
            index += 1
        elseif arg == "--initial-amplitude"
            index += 1
            index <= length(args) ||
                throw(ArgumentError("--initial-amplitude requires a value"))
            initial_amplitude = Float64(parse(Float64, args[index]))
            index += 1
        elseif arg == "--initial-width"
            index += 1
            index <= length(args) || throw(ArgumentError("--initial-width requires a value"))
            initial_width = Float64(parse(Float64, args[index]))
            index += 1
        elseif arg == "--resume"
            resume = true
            index += 1
        elseif arg == "--certified"
            certified = true
            index += 1
        elseif arg == "--run-indices"
            index += 1
            index <= length(args) || throw(ArgumentError("--run-indices requires a value"))
            run_indices = _parse_cli_int_list(args[index], "run index")
            index += 1
        elseif arg == "--dry-run"
            dry_run = true
            index += 1
        else
            throw(ArgumentError("unknown option: $arg"))
        end
    end

    isodd(kernel_size) || throw(ArgumentError("kernel-size must be odd"))
    feature_count in (6, 32, 64) ||
        throw(ArgumentError("feature-count must be one of 6, 32, or 64"))
    selected_feature_counts = feature_counts === nothing ? [feature_count] : feature_counts
    eig_tol > 0 || throw(ArgumentError("eig-tol must be positive"))
    fixed_tol > 0 || throw(ArgumentError("fixed-tol must be positive"))
    repeats >= 2 || throw(ArgumentError("repeats must be at least 2"))
    isfinite(relative_tolerance) && relative_tolerance >= 0 ||
        throw(ArgumentError("relative-tolerance must be nonnegative and finite"))
    0 <= lambda_threshold <= 1 ||
        throw(ArgumentError("lambda-threshold must be between 0 and 1"))
    resume && output_dir === nothing &&
        throw(ArgumentError("--resume requires --output-dir"))
    (run_indices !== nothing || dry_run) && preset === nothing &&
        throw(ArgumentError("--run-indices and --dry-run require a managed preset"))
    resume && dry_run && throw(ArgumentError("--resume cannot be combined with --dry-run"))
    LeniaInitialConditionConfig(
        mode=initial_mode,
        seed=seed,
        baseline=initial_baseline,
        amplitude=initial_amplitude,
        width=initial_width,
    )

    LeniaReportCLIOptions(
        preset,
        preset_file,
        shape,
        action_count,
        feature_count,
        selected_feature_counts,
        kernel_size,
        tau_steps,
        output,
        output_dir,
        eig_tol,
        fixed_tol,
        seed,
        repeats,
        relative_tolerance,
        lambda_threshold,
        initial_mode,
        initial_baseline,
        initial_amplitude,
        initial_width,
        resume,
        certified,
        run_indices,
        dry_run,
        help,
    )
end

function parse_trm_neural_experiment_args(args=ARGS)
    preset = :smoke
    preset_file = nothing
    selected_preset = trm_neural_experiment_preset(preset)
    system = selected_preset.system
    shape = (3, 3)
    action_count = 2
    feature_count = 6
    kernel_size = 3
    rollout_steps = selected_preset.rollout_steps
    hidden_dims = copy(selected_preset.hidden_dims)
    learning_rates = copy(selected_preset.learning_rates)
    checkpoint_counts = copy(selected_preset.checkpoint_counts)
    epochs_per_checkpoint_values = copy(selected_preset.epochs_per_checkpoint_values)
    output_dir = nothing
    resume = false
    continue_from_optimizer = false
    certified = selected_preset.certified
    eig_tol = 1e-10
    fixed_tol = 1e-6
    help = false

    index = 1
    while index <= length(args)
        arg = args[index]
        if arg == "--help" || arg == "-h"
            help = true
            index += 1
        elseif arg == "--system"
            index += 1
            index <= length(args) || throw(ArgumentError("--system requires a value"))
            system = Symbol(args[index])
            index += 1
        elseif arg == "--preset"
            index += 1
            index <= length(args) || throw(ArgumentError("--preset requires a value"))
            preset = Symbol(args[index])
            preset_file = nothing
            selected_preset = trm_neural_experiment_preset(preset)
            system = selected_preset.system
            rollout_steps = selected_preset.rollout_steps
            hidden_dims = copy(selected_preset.hidden_dims)
            learning_rates = copy(selected_preset.learning_rates)
            checkpoint_counts = copy(selected_preset.checkpoint_counts)
            epochs_per_checkpoint_values = copy(selected_preset.epochs_per_checkpoint_values)
            certified = selected_preset.certified
            index += 1
        elseif arg == "--preset-file"
            index += 1
            index <= length(args) || throw(ArgumentError("--preset-file requires a value"))
            preset_file = args[index]
            selected_preset = read_trm_neural_experiment_preset(preset_file)
            preset = selected_preset.name
            system = selected_preset.system
            rollout_steps = selected_preset.rollout_steps
            hidden_dims = copy(selected_preset.hidden_dims)
            learning_rates = copy(selected_preset.learning_rates)
            checkpoint_counts = copy(selected_preset.checkpoint_counts)
            epochs_per_checkpoint_values = copy(selected_preset.epochs_per_checkpoint_values)
            certified = selected_preset.certified
            index += 1
        elseif arg == "--shape"
            index += 1
            index <= length(args) || throw(ArgumentError("--shape requires a value"))
            shape = _parse_cli_shape(args[index])
            index += 1
        elseif arg == "--action-count"
            index += 1
            index <= length(args) || throw(ArgumentError("--action-count requires a value"))
            action_count = _parse_cli_int(args[index], "action-count")
            index += 1
        elseif arg == "--feature-count"
            index += 1
            index <= length(args) || throw(ArgumentError("--feature-count requires a value"))
            feature_count = _parse_cli_int(args[index], "feature-count")
            index += 1
        elseif arg == "--kernel-size"
            index += 1
            index <= length(args) || throw(ArgumentError("--kernel-size requires a value"))
            kernel_size = _parse_cli_int(args[index], "kernel-size")
            index += 1
        elseif arg == "--rollout-steps"
            index += 1
            index <= length(args) || throw(ArgumentError("--rollout-steps requires a value"))
            rollout_steps = _parse_cli_int(args[index], "rollout-steps")
            index += 1
        elseif arg == "--hidden-dims"
            index += 1
            index <= length(args) || throw(ArgumentError("--hidden-dims requires a value"))
            hidden_dims = _parse_cli_int_list(args[index], "hidden dim")
            index += 1
        elseif arg == "--learning-rates"
            index += 1
            index <= length(args) || throw(ArgumentError("--learning-rates requires a value"))
            learning_rates = _parse_cli_float_list(args[index], "learning rate")
            index += 1
        elseif arg == "--checkpoint-counts"
            index += 1
            index <= length(args) || throw(ArgumentError("--checkpoint-counts requires a value"))
            checkpoint_counts = _parse_cli_int_list(args[index], "checkpoint count")
            index += 1
        elseif arg == "--epochs-per-checkpoint"
            index += 1
            index <= length(args) ||
                throw(ArgumentError("--epochs-per-checkpoint requires a value"))
            epochs_per_checkpoint_values = _parse_cli_int_list(
                args[index],
                "epochs per checkpoint",
            )
            index += 1
        elseif arg == "--output-dir"
            index += 1
            index <= length(args) || throw(ArgumentError("--output-dir requires a value"))
            output_dir = args[index]
            index += 1
        elseif arg == "--resume"
            resume = true
            index += 1
        elseif arg == "--continue"
            continue_from_optimizer = true
            index += 1
        elseif arg == "--certified"
            certified = true
            index += 1
        elseif arg == "--eig-tol"
            index += 1
            index <= length(args) || throw(ArgumentError("--eig-tol requires a value"))
            eig_tol = _parse_cli_float(args[index], "eig-tol")
            index += 1
        elseif arg == "--fixed-tol"
            index += 1
            index <= length(args) || throw(ArgumentError("--fixed-tol requires a value"))
            fixed_tol = _parse_cli_float(args[index], "fixed-tol")
            index += 1
        else
            throw(ArgumentError("unknown option: $arg"))
        end
    end

    system in (:toy, :lenia) || throw(ArgumentError("system must be toy or lenia"))
    isodd(kernel_size) || throw(ArgumentError("kernel-size must be odd"))
    feature_count in (6, 32, 64) ||
        throw(ArgumentError("feature-count must be one of 6, 32, or 64"))

    TRMNeuralExperimentCLIOptions(
        preset,
        preset_file,
        system,
        shape,
        action_count,
        feature_count,
        kernel_size,
        rollout_steps,
        hidden_dims,
        learning_rates,
        checkpoint_counts,
        epochs_per_checkpoint_values,
        output_dir,
        resume,
        continue_from_optimizer,
        certified,
        eig_tol,
        fixed_tol,
        help,
    )
end

function _write_cli_artifact(io::IO, output::Union{String,Nothing}, artifact_json::String)
    if output === nothing || output == "-"
        write(io, artifact_json)
        write(io, "\n")
        return nothing
    end
    open(output, "w") do file
        write(file, artifact_json)
        write(file, "\n")
    end
    output
end

function _write_cli_output_dir(
    output_dir::AbstractString,
    artifact_json::String,
    summary::NamedTuple,
)
    mkpath(output_dir)
    artifact_path = joinpath(output_dir, "artifact.json")
    summary_path = joinpath(output_dir, "summary.json")
    enriched_summary = merge(summary, (
        output_dir=String(output_dir),
        output=artifact_path,
        summary_path=summary_path,
    ))
    open(artifact_path, "w") do file
        write(file, artifact_json)
        write(file, "\n")
    end
    open(summary_path, "w") do file
        write(file, _json_value(enriched_summary))
        write(file, "\n")
    end
    enriched_summary
end

function _lenia_cli_summary(mode, output, result)
    (
        mode=mode,
        output=output,
        status=string(result.status.code),
        harness_accepted=result.harness.accepted,
        reachable=result.reachability.reachability.reachable,
        slowing_warning=result.slowing_assessment.warning,
        classification=result.report.pipeline.classification,
    )
end

function run_lenia_report_cli(args=ARGS; stdout::IO=Base.stdout, stderr::IO=Base.stderr)
    options = try
        parse_lenia_report_args(args)
    catch err
        err isa ArgumentError || rethrow()
        write(stderr, "error: $(err.msg)\n\n")
        write(stderr, lenia_report_usage())
        return 2
    end

    if options.help
        write(stdout, lenia_report_usage())
        return 0
    end

    acceptance_config = ExperimentAcceptanceConfig(
        lambda_threshold=options.lambda_threshold,
        eig_tol=options.eig_tol,
        seed=options.seed,
        repeats=options.repeats,
        relative_tolerance=options.relative_tolerance,
    )
    initial_condition = LeniaInitialConditionConfig(
        mode=options.initial_mode,
        seed=options.seed,
        baseline=options.initial_baseline,
        amplitude=options.initial_amplitude,
        width=options.initial_width,
    )
    if options.preset !== nothing
        base_preset = options.preset_file === nothing ?
            lenia_experiment_preset(options.preset) :
            read_lenia_experiment_preset(options.preset_file)
        preset = LeniaExperimentPreset(
            base_preset.name,
            options.shape,
            options.action_count,
            options.feature_counts,
            options.kernel_size,
            options.tau_steps,
            acceptance_config,
            initial_condition,
            base_preset.description,
        )
        plan = lenia_experiment_plan(
            preset;
            acceptance_config=acceptance_config,
            initial_condition=initial_condition,
            run_indices=options.run_indices,
        )
        if options.dry_run
            plan_json = _json_value(plan)
            if options.output_dir !== nothing
                mkpath(options.output_dir)
                plan_path = joinpath(options.output_dir, "plan.json")
                open(plan_path, "w") do io
                    write(io, plan_json)
                    write(io, "\n")
                end
                write(stdout, _json_value((
                    mode=:experiment_plan,
                    preset=options.preset,
                    plan_path=plan_path,
                    selected_condition_count=plan.selected_condition_count,
                    selected_architecture_runs=plan.selected_architecture_runs,
                )) * "\n")
                return 0
            end
            written = _write_cli_artifact(stdout, options.output, plan_json)
            written === nothing || write(stdout, _json_value((
                mode=:experiment_plan,
                preset=options.preset,
                output=written,
            )) * "\n")
            return 0
        end
        certificate_check = options.certified ? verify_lean_certified_artifact() : nothing
        sweep = run_lenia_experiment_sweep(
            preset;
            output_dir=options.output_dir,
            resume=options.resume,
            acceptance_config=acceptance_config,
            certificate_check=certificate_check,
            initial_condition=initial_condition,
            run_indices=options.run_indices,
            eig_tol=options.eig_tol,
            fixed_tol=options.fixed_tol,
        )
        summary = (
            mode=:experiment_sweep,
            preset=options.preset,
            run_count=sweep.summary.run_count,
            accepted_count=sweep.summary.accepted_count,
            resumed_count=sweep.summary.resumed_count,
            selected_run_indices=sweep.summary.selected_run_indices,
            output_dir=options.output_dir,
        )
        if options.output_dir !== nothing
            write(stdout, _json_value(merge(summary, sweep.artifact_paths)) * "\n")
            return 0
        end
        written = _write_cli_artifact(stdout, options.output, _json_value(sweep.summary))
        written === nothing || write(stdout, _json_value(merge(summary, (output=written,))) * "\n")
        return 0
    end

    certificate_check = options.certified ? verify_lean_certified_artifact() : nothing

    if length(options.tau_steps) == 1 && length(options.feature_counts) == 1
        series = compare_lenia_tau_steps(
            options.tau_steps;
            shape=options.shape,
            action_count=options.action_count,
            feature_count=first(options.feature_counts),
            kernel_size=options.kernel_size,
            eig_tol=options.eig_tol,
            fixed_tol=options.fixed_tol,
            acceptance_config=acceptance_config,
            certificate_check=certificate_check,
            initial_condition=initial_condition,
        )
        result = first(series.results)
        summary = merge(
            _lenia_cli_summary(:single, nothing, result),
            (reproducibility=first(series.reproducibility),),
        )
        if options.output_dir !== nothing
            written_summary =
                _write_cli_output_dir(options.output_dir, series.artifact_json, summary)
            write(stdout, _json_value(written_summary) * "\n")
            return 0
        end
        written = _write_cli_artifact(stdout, options.output, series.artifact_json)
        written === nothing || write(stdout, _json_value(merge(summary, (output=written,))) * "\n")
        return 0
    end

    series = if length(options.feature_counts) == 1
        compare_lenia_tau_steps(
            options.tau_steps;
            shape=options.shape,
            action_count=options.action_count,
            feature_count=first(options.feature_counts),
            kernel_size=options.kernel_size,
            eig_tol=options.eig_tol,
            fixed_tol=options.fixed_tol,
            acceptance_config=acceptance_config,
            certificate_check=certificate_check,
            initial_condition=initial_condition,
        )
    else
        compare_lenia_parameter_grid(
            options.tau_steps,
            options.feature_counts;
            shape=options.shape,
            action_count=options.action_count,
            kernel_size=options.kernel_size,
            eig_tol=options.eig_tol,
            fixed_tol=options.fixed_tol,
            acceptance_config=acceptance_config,
            certificate_check=certificate_check,
            initial_condition=initial_condition,
        )
    end
    summary = (
        mode=length(options.feature_counts) == 1 ? :series : :parameter_grid,
        output=nothing,
        tau_steps=options.tau_steps,
        feature_counts=options.feature_counts,
        summary=series.summary,
    )
    if options.output_dir !== nothing
        written_summary = _write_cli_output_dir(options.output_dir, series.artifact_json, summary)
        write(stdout, _json_value(written_summary) * "\n")
        return 0
    end
    written = _write_cli_artifact(stdout, options.output, series.artifact_json)
    summary = merge(summary, (output=written,))
    written === nothing || write(stdout, _json_value(summary) * "\n")
    0
end

function _trm_cli_adapter(options::TRMNeuralExperimentCLIOptions)
    if options.system == :toy
        return SigmaSystemAdapter(
            zeros(options.action_count),
            (_state, action) -> action,
            state -> state,
        )
    end
    system = default_lenia_system(
        options.shape;
        action_count=options.action_count,
        feature_count=options.feature_count,
        kernel_size=options.kernel_size,
    )
    lenia_system_adapter(system, zeros(options.shape))
end

function _trm_cli_is_sweep(options::TRMNeuralExperimentCLIOptions)
    length(options.hidden_dims) *
        length(options.learning_rates) *
        length(options.checkpoint_counts) *
        length(options.epochs_per_checkpoint_values) > 1
end

function run_trm_neural_experiment_cli(
    args=ARGS;
    stdout::IO=Base.stdout,
    stderr::IO=Base.stderr,
)
    options = try
        parse_trm_neural_experiment_args(args)
    catch err
        err isa ArgumentError || rethrow()
        write(stderr, "error: $(err.msg)\n\n")
        write(stderr, trm_neural_experiment_usage())
        return 2
    end

    if options.help
        write(stdout, trm_neural_experiment_usage())
        return 0
    end

    adapter = _trm_cli_adapter(options)
    dc_result = DCResult(true, true, true, true, Set([:trm_cli_act]))
    certificate_check = options.certified ? verify_lean_certified_artifact() : nothing

    if _trm_cli_is_sweep(options)
        sweep = run_trm_neural_training_experiment_sweep(
            adapter,
            zeros(options.action_count),
            dc_result;
            rollout_steps=options.rollout_steps,
            hidden_dims=options.hidden_dims,
            learning_rates=options.learning_rates,
            checkpoint_counts=options.checkpoint_counts,
            epochs_per_checkpoint_values=options.epochs_per_checkpoint_values,
            output_dir=options.output_dir,
            resume=options.resume,
            continue_from_optimizer=options.continue_from_optimizer,
            certificate_check=certificate_check,
            eig_tol=options.eig_tol,
            fixed_tol=options.fixed_tol,
        )
        write(stdout, _json_value(merge(sweep.summary, (
            mode=:sweep,
            preset=options.preset,
            preset_file=options.preset_file,
            system=options.system,
            artifact_paths=sweep.artifact_paths,
        ))) * "\n")
        return 0
    end

    experiment = run_trm_neural_training_experiment(
        adapter,
        zeros(options.action_count),
        dc_result;
        rollout_steps=options.rollout_steps,
        hidden_dim=first(options.hidden_dims),
        learning_rate=first(options.learning_rates),
        checkpoint_count=first(options.checkpoint_counts),
        epochs_per_checkpoint=first(options.epochs_per_checkpoint_values),
        output_dir=options.output_dir,
        continue_from_optimizer=options.continue_from_optimizer,
        certificate_check=certificate_check,
        eig_tol=options.eig_tol,
        fixed_tol=options.fixed_tol,
    )
    write(stdout, _json_value(merge(experiment.summary, (
        mode=:single,
        preset=options.preset,
        preset_file=options.preset_file,
        system=options.system,
        artifact_paths=experiment.artifact_paths,
    ))) * "\n")
    0
end
