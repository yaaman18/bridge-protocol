include("parallel_test_plan.jl")

function configured_test_jobs()
    parallel_file_count = count(entry -> first(entry) ∉ ERIEC_EXCLUSIVE_TEST_FILES, ERIEC_TEST_PLAN)
    default_jobs = min(4, Sys.CPU_THREADS, parallel_file_count)
    jobs = tryparse(Int, get(ENV, "ERIEC_TEST_JOBS", string(default_jobs)))
    jobs === nothing && throw(ArgumentError("ERIEC_TEST_JOBS must be an integer"))
    1 <= jobs <= parallel_file_count ||
        throw(ArgumentError("ERIEC_TEST_JOBS must be between 1 and $parallel_file_count"))
    jobs
end

function worker_command(files)
    active_project = Base.active_project()
    active_project === nothing && error("parallel tests require an active Julia project")
    worker = joinpath(@__DIR__, "parallel_test_worker.jl")
    `$(Base.julia_cmd()) --project=$(dirname(active_project)) $worker $files`
end

function run_parallel_test_groups(groups, estimated_loads; phase="parallel")
    workers = NamedTuple[]
    for (index, files) in enumerate(groups)
        log_path, log_io = mktemp()
        command = addenv(
            worker_command(files),
            "JULIA_NUM_THREADS" => "1",
            "OPENBLAS_NUM_THREADS" => "1",
            "OMP_NUM_THREADS" => "1",
        )
        process = run(pipeline(command; stdout=log_io, stderr=log_io); wait=false)
        close(log_io)
        push!(workers, (; index, files, log_path, process))
    end

    failed = Int[]
    for worker in workers
        wait(worker.process)
        output = read(worker.log_path, String)
        rm(worker.log_path; force=true)
        println("\n===== ERIEC $phase test group $(worker.index)/$(length(groups)) " *
                "(estimated $(round(estimated_loads[worker.index]; digits=1))s) =====")
        print(output)
        if !success(worker.process)
            push!(failed, worker.index)
        end
    end

    isempty(failed) || error("ERIEC test groups failed: $(join(failed, ", "))")
end

function run_eriec_tests()
    files = first.(ERIEC_TEST_PLAN)
    length(files) == length(unique(files)) || error("ERIEC test plan contains duplicate files")
    missing = filter(file -> !isfile(joinpath(@__DIR__, file)), files)
    isempty(missing) || error("ERIEC test plan contains missing files: $(join(missing, ", "))")

    jobs = configured_test_jobs()
    if jobs == 1
        println("Running $(length(files)) ERIEC test files in one isolated process")
        estimated_load = sum(last, ERIEC_TEST_PLAN)
        run_parallel_test_groups([files], [estimated_load])
        return
    end

    groups, estimated_loads = eriec_test_groups(jobs)
    exclusive_plan = filter(entry -> first(entry) in ERIEC_EXCLUSIVE_TEST_FILES, ERIEC_TEST_PLAN)
    exclusive_files = first.(exclusive_plan)
    exclusive_loads = [sum(last, exclusive_plan)]
    println("Running $(length(files) - length(exclusive_files)) ERIEC test files " *
            "in $jobs isolated processes, then $(length(exclusive_files)) exclusive file(s)")
    run_parallel_test_groups(groups, estimated_loads)
    run_parallel_test_groups([exclusive_files], exclusive_loads; phase="exclusive")
end
