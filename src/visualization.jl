function _html_escape(value)
    replace(
        string(value),
        "&" => "&amp;",
        "<" => "&lt;",
        ">" => "&gt;",
        "\"" => "&quot;",
        "'" => "&#39;",
    )
end

function _svg_polyline(values; width::Int=720, height::Int=180)
    numeric = Float64.(values)
    isempty(numeric) && return ""
    finite = filter(isfinite, numeric)
    isempty(finite) && return ""
    lower, upper = extrema(finite)
    span = upper == lower ? 1.0 : upper - lower
    x(index) = length(numeric) == 1 ? width / 2 : (index - 1) * width / (length(numeric) - 1)
    y(value) = height - 12 - (value - lower) * (height - 24) / span
    join(
        (
            isfinite(value) ? "$(round(x(index); digits=2)),$(round(y(value); digits=2))" : ""
            for (index, value) in enumerate(numeric)
        ),
        " ",
    )
end

function _metric_chart(title, values; color="#176b4d", formatter=string)
    numeric = Float64.(values)
    points = _svg_polyline(numeric)
    latest = isempty(numeric) ? "n/a" : formatter(last(numeric))
    """
    <section class="chart-panel">
      <div class="chart-heading"><h2>$(_html_escape(title))</h2><strong>$(_html_escape(latest))</strong></div>
      <svg viewBox="0 0 720 180" role="img" aria-label="$(_html_escape(title))">
        <line x1="0" y1="168" x2="720" y2="168" class="axis" />
        <polyline points="$points" fill="none" stroke="$color" stroke-width="3" vector-effect="non-scaling-stroke" />
      </svg>
    </section>
    """
end

function _matrix_heatmap(title, matrix::AbstractMatrix; cell_size::Int=18)
    rows, cols = size(matrix)
    values = Float64.(matrix)
    scale = isempty(values) ? 1.0 : max(maximum(abs, values), eps(Float64))
    cells = join((
        begin
            normalized = clamp(values[row, col] / scale, -1.0, 1.0)
            color = normalized >= 0 ?
                "rgba(23,107,77,$(0.12 + 0.78 * normalized))" :
                "rgba(161,43,43,$(0.12 + 0.78 * abs(normalized)))"
            "<rect x=\"$((col - 1) * cell_size)\" y=\"$((row - 1) * cell_size)\" " *
            "width=\"$cell_size\" height=\"$cell_size\" fill=\"$color\"><title>" *
            "$row,$col: $(_html_escape(round(values[row, col]; digits=6)))</title></rect>"
        end
        for row in 1:rows for col in 1:cols
    ))
    width = max(cols * cell_size, 1)
    height = max(rows * cell_size, 1)
    """
    <section class="chart-panel">
      <div class="chart-heading"><h2>$(_html_escape(title))</h2><strong>$(rows)x$(cols)</strong></div>
      <svg viewBox="0 0 $width $height" role="img" aria-label="$(_html_escape(title))" class="heatmap">$cells</svg>
    </section>
    """
end

function _dashboard_document(title, subtitle, body)
    """<!doctype html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>$(_html_escape(title))</title>
      <style>
        :root { color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }
        * { box-sizing: border-box; }
        body { margin: 0; color: #202421; background: #f4f6f3; }
        header { padding: 24px max(20px, calc((100vw - 1180px) / 2)); background: #fff; border-bottom: 1px solid #d9ded9; }
        h1 { margin: 0; font-size: 28px; font-weight: 700; }
        h2 { margin: 0; font-size: 15px; font-weight: 650; }
        p { margin: 6px 0 0; color: #59615b; }
        main { width: min(1180px, calc(100% - 32px)); margin: 20px auto 40px; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 10px; margin-bottom: 14px; }
        .metric, .chart-panel, .table-panel { background: #fff; border: 1px solid #d9ded9; border-radius: 6px; }
        .metric { padding: 14px; }
        .metric span { display: block; color: #687069; font-size: 12px; }
        .metric strong { display: block; margin-top: 5px; font-size: 22px; }
        .charts { display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 420px), 1fr)); gap: 12px; }
        .chart-panel { padding: 14px; min-width: 0; }
        .chart-heading { display: flex; justify-content: space-between; gap: 12px; align-items: baseline; }
        svg { display: block; width: 100%; height: auto; margin-top: 8px; background: #fafbfa; }
        .heatmap { max-height: 320px; image-rendering: pixelated; }
        .axis { stroke: #c9cec9; stroke-width: 1; }
        .table-panel { margin-top: 12px; overflow-x: auto; }
        table { width: 100%; border-collapse: collapse; font-size: 13px; }
        th, td { padding: 10px 12px; border-bottom: 1px solid #e4e8e4; text-align: left; white-space: nowrap; }
        th { color: #59615b; background: #fafbfa; font-weight: 600; }
        .ok { color: #176b4d; font-weight: 650; }
        .warn { color: #9a4e00; font-weight: 650; }
        .bad { color: #a12b2b; font-weight: 650; }
        @media (max-width: 620px) { header { padding: 18px 16px; } h1 { font-size: 22px; } main { width: calc(100% - 20px); margin-top: 10px; } }
      </style>
    </head>
    <body>
      <header><h1>$(_html_escape(title))</h1><p>$(_html_escape(subtitle))</p></header>
      <main>$body</main>
    </body>
    </html>
    """
end

function observation_series_dashboard_html(reports)
    collected = collect(reports)
    isempty(collected) || all(report -> report isa ObservationStructureReport, collected) ||
        throw(ArgumentError("reports must contain ObservationStructureReport values"))
    tensor_norms = [norm(report.pipeline.tensor) for report in collected]
    viability_mass = [sum(report.pipeline.weights) for report in collected]
    weighted_norms = [norm(report.pipeline.weighted_tensor) for report in collected]
    world_dimensions = [size(report.pipeline.wld_result.basis, 2) for report in collected]
    classifications = [report.pipeline.classification for report in collected]
    rows = join((
        "<tr><td>$index</td><td>$(round(tensor_norms[index]; digits=6))</td>" *
        "<td>$(round(viability_mass[index]; digits=6))</td>" *
        "<td>$(round(weighted_norms[index]; digits=6))</td>" *
        "<td>$(world_dimensions[index])</td><td>$(_html_escape(classifications[index]))</td></tr>"
        for index in eachindex(collected)
    ))
    latest_heatmaps = isempty(collected) ? "" : begin
        latest = last(collected).pipeline
        _matrix_heatmap("Latest sensitivity tensor T", latest.tensor) *
        _matrix_heatmap("Latest viability tensor V", reshape(latest.weights, 1, :)) *
        _matrix_heatmap("Latest weighted tensor O_hat", latest.weighted_tensor)
    end
    body = """
    <div class="metrics">
      <div class="metric"><span>Frames</span><strong>$(length(collected))</strong></div>
      <div class="metric"><span>Latest Wld dimension</span><strong>$(isempty(world_dimensions) ? "n/a" : last(world_dimensions))</strong></div>
      <div class="metric"><span>Latest classification</span><strong>$(_html_escape(isempty(classifications) ? "n/a" : last(classifications)))</strong></div>
    </div>
    <div class="charts">
      $(_metric_chart("Sensitivity norm ||T||", tensor_norms; formatter=value -> string(round(value; digits=6))))
      $(_metric_chart("Viability mass sum(V)", viability_mass; color="#2d5f9a", formatter=value -> string(round(value; digits=6))))
      $(_metric_chart("Weighted norm ||O_hat||", weighted_norms; color="#9a4e00", formatter=value -> string(round(value; digits=6))))
      $(_metric_chart("Wld dimension", world_dimensions; color="#6b5b2a", formatter=value -> string(round(Int, value))))
      $latest_heatmaps
    </div>
    <section class="table-panel"><table>
      <thead><tr><th>Frame</th><th>||T||</th><th>sum(V)</th><th>||O_hat||</th><th>Wld dimension</th><th>Classification</th></tr></thead>
      <tbody>$rows</tbody>
    </table></section>
    """
    _dashboard_document(
        "ERIE observation tensor series",
        "Sensitivity, viability, weighted observation, and enacted-world diagnostics",
        body,
    )
end

function write_observation_series_dashboard(path::AbstractString, reports)
    open(path, "w") do io
        write(io, observation_series_dashboard_html(reports))
    end
    path
end

function collapse_trace_dashboard_html(
    trace::CollapseTraceResult;
    title::AbstractString="Wld contraction trace",
)
    collapsed = trace.collapsed_at === nothing ? "not observed" : string(trace.collapsed_at)
    rows = join((
        "<tr><td>$index</td><td>$(round(trace.eigenvalues[index]; digits=6))</td>" *
        "<td>$(trace.dimensions[index])</td><td>$(round(trace.slowing_scores[index]; digits=6))</td></tr>"
        for index in eachindex(trace.eigenvalues)
    ))
    body = """
    <div class="metrics">
      <div class="metric"><span>Samples</span><strong>$(length(trace.eigenvalues))</strong></div>
      <div class="metric"><span>Collapsed at</span><strong>$(_html_escape(collapsed))</strong></div>
      <div class="metric"><span>Final Wld dimension</span><strong>$(isempty(trace.dimensions) ? "n/a" : last(trace.dimensions))</strong></div>
    </div>
    <div class="charts">
      $(_metric_chart("Dominant eigenvalue", trace.eigenvalues; formatter=value -> string(round(value; digits=6))))
      $(_metric_chart("Wld dimension", trace.dimensions; color="#2d5f9a", formatter=value -> string(round(Int, value))))
      $(_metric_chart("Critical slowing score", trace.slowing_scores; color="#9a4e00", formatter=value -> string(round(value; digits=4))))
    </div>
    <section class="table-panel"><table>
      <thead><tr><th>Step</th><th>Dominant eigenvalue</th><th>Wld dimension</th><th>Slowing score</th></tr></thead>
      <tbody>$rows</tbody>
    </table></section>
    """
    _dashboard_document(title, "Collapse and critical-slowing diagnostics", body)
end

function lenia_experiment_dashboard_html(report::NamedTuple)
    entries = report.entries
    invalid_artifact_count = hasproperty(report, :invalid_artifact_count) ?
        report.invalid_artifact_count : 0
    invalid_certificate_count = hasproperty(report, :invalid_certificate_count) ?
        report.invalid_certificate_count : 0
    invalid_summary_count = hasproperty(report, :invalid_summary_count) ?
        report.invalid_summary_count : 0
    eigenvalues = [entry.dominant_eigenvalue for entry in entries if hasproperty(entry, :dominant_eigenvalue)]
    deviations = [entry.max_relative_deviation for entry in entries if hasproperty(entry, :max_relative_deviation)]
    rows = join((
        begin
            accepted = hasproperty(entry, :accepted) && entry.accepted
            status = hasproperty(entry, :status) ? entry.status : :incomplete
            class_name = accepted ? "ok" : (status == :architecture_warn ? "warn" : "bad")
            artifact_status = if hasproperty(entry, :artifact_valid) && entry.artifact_valid
                :valid
            elseif hasproperty(entry, :artifact_exists) && entry.artifact_exists
                :invalid
            elseif hasproperty(entry, :artifact_exists)
                :missing
            else
                :unknown
            end
            artifact_class = artifact_status == :valid ? "ok" :
                (artifact_status == :unknown ? "warn" : "bad")
            certificate_status = if hasproperty(entry, :certified) && !entry.certified
                :not_requested
            elseif hasproperty(entry, :certificate_valid) && entry.certificate_valid === true
                :valid
            elseif hasproperty(entry, :certificate_exists) && entry.certificate_exists
                :invalid
            elseif hasproperty(entry, :certificate_exists)
                :missing
            else
                :unknown
            end
            certificate_class = certificate_status in (:valid, :not_requested) ? "ok" :
                (certificate_status == :unknown ? "warn" : "bad")
            "<tr><td>$(entry.index)</td><td>$(hasproperty(entry, :tau_step) ? entry.tau_step : "n/a")</td>" *
            "<td>$(hasproperty(entry, :feature_count) ? entry.feature_count : "n/a")</td>" *
            "<td>$(hasproperty(entry, :dominant_eigenvalue) ? round(entry.dominant_eigenvalue; digits=6) : "n/a")</td>" *
            "<td>$(hasproperty(entry, :max_relative_deviation) ? round(entry.max_relative_deviation; digits=6) : "n/a")</td>" *
            "<td class=\"$class_name\">$(_html_escape(status))</td>" *
            "<td class=\"$(accepted ? "ok" : "bad")\">$(accepted ? "accepted" : "rejected")</td>" *
            "<td class=\"$artifact_class\">$artifact_status</td>" *
            "<td class=\"$certificate_class\">$certificate_status</td></tr>"
        end
        for entry in entries
    ))
    body = """
    <div class="metrics">
      <div class="metric"><span>Conditions</span><strong>$(report.run_count)</strong></div>
      <div class="metric"><span>Accepted</span><strong>$(report.accepted_count)</strong></div>
      <div class="metric"><span>Complete artifacts</span><strong>$(report.artifact_complete_count)</strong></div>
      <div class="metric"><span>Missing artifacts</span><strong>$(report.missing_artifact_count)</strong></div>
      <div class="metric"><span>Invalid artifacts</span><strong>$invalid_artifact_count</strong></div>
      <div class="metric"><span>Invalid certificates</span><strong>$invalid_certificate_count</strong></div>
      <div class="metric"><span>Invalid summaries</span><strong>$invalid_summary_count</strong></div>
    </div>
    <div class="charts">
      $(_metric_chart("Dominant Wld eigenvalue by run", eigenvalues; formatter=value -> string(round(value; digits=6))))
      $(_metric_chart("Reproducibility deviation by run", deviations; color="#9a4e00", formatter=value -> string(round(value; digits=6))))
    </div>
    <section class="table-panel"><table>
      <thead><tr><th>Run</th><th>Tau</th><th>Features</th><th>Dominant eigenvalue</th><th>Max relative deviation</th><th>Status</th><th>Acceptance</th><th>Artifact</th><th>Certificate</th></tr></thead>
      <tbody>$rows</tbody>
    </table></section>
    """
    _dashboard_document(
        "Lenia experiment dashboard",
        "Persisted sweep status and Wld diagnostics",
        body,
    )
end

lenia_experiment_dashboard_html(sweep::LeniaExperimentSweepResult) =
    lenia_experiment_dashboard_html(lenia_experiment_sweep_report(sweep))

lenia_experiment_dashboard_html(output_dir::AbstractString) =
    lenia_experiment_dashboard_html(lenia_experiment_sweep_report(output_dir))

function write_lenia_experiment_dashboard(path::AbstractString, report_or_sweep)
    open(path, "w") do io
        write(io, lenia_experiment_dashboard_html(report_or_sweep))
    end
    path
end

function write_collapse_trace_dashboard(
    path::AbstractString,
    trace::CollapseTraceResult;
    title::AbstractString="Wld contraction trace",
)
    open(path, "w") do io
        write(io, collapse_trace_dashboard_html(trace; title=title))
    end
    path
end
