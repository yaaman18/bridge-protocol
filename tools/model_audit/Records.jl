const AUDIT_STATUSES = (:open, :explained, :conditional, :reformulated,
                        :out_of_scope, :underdetermined, :refuted)
const EMPTY_AUDIT_HEAD = repeat("0", 64)

function _audit_text(x)
    x isa AbstractString && isvalid(x) && !isempty(strip(x)) ||
        throw(ArgumentError("audit text must be nonempty UTF-8"))
    String(x)
end

function _audit_strings(xs)
    xs isa Union{Tuple,AbstractVector} || throw(ArgumentError("expected a string sequence"))
    values = Tuple(_audit_text(x) for x in xs)
    length(unique(values)) == length(values) || throw(ArgumentError("duplicate values"))
    values
end

struct AuditContext
    question_id::String
    question::String
    definition_version::String
    definition::String
    assumptions::Tuple{Vararg{String}}
    observation::String
    subject::String
    function AuditContext(; question_id, question, definition_version, definition,
                          assumptions=(), observation, subject)
        new(_audit_text(question_id), _audit_text(question), _audit_text(definition_version),
            _audit_text(definition), Tuple(sort(collect(_audit_strings(assumptions)))),
            _audit_text(observation), _audit_text(subject))
    end
end

_context_dict(c::AuditContext) = Dict{String,Any}(
    "question_id" => c.question_id, "question" => c.question,
    "definition_version" => c.definition_version, "definition" => c.definition,
    "assumptions" => collect(c.assumptions), "observation" => c.observation,
    "subject" => c.subject,
)

function _exact_keys(data, keys)
    data isa AbstractDict && Set(Base.keys(data)) == Set(keys) ||
        throw(ArgumentError("unexpected or missing audit fields"))
end

function _parse_context(data)
    _exact_keys(data, ("question_id", "question", "definition_version", "definition",
                       "assumptions", "observation", "subject"))
    AuditContext(; (Symbol(k) => v for (k, v) in data)...)
end

function compare_audit_claims(a, b)
    for claim in (a, b)
        claim.context isa AuditContext || throw(ArgumentError("invalid context"))
        _audit_text(claim.proposition)
        claim.verdict in (:affirmed, :denied, :undetermined) ||
            throw(ArgumentError("invalid verdict"))
    end
    differences = Symbol[field for field in fieldnames(AuditContext)
                         if getfield(a.context, field) != getfield(b.context, field)]
    a.proposition == b.proposition || push!(differences, :proposition)
    opposite = Set((a.verdict, b.verdict)) == Set((:affirmed, :denied))
    classification = if :question_id in differences || :question in differences
        :different_question
    elseif any(field -> field != :proposition, differences)
        :different_context
    elseif :proposition in differences
        :different_proposition
    elseif :undetermined in (a.verdict, b.verdict)
        :underdetermined
    elseif opposite
        :conflict_requires_review
    else
        :compatible
    end
    (; classification, differences=Tuple(differences), opposite,
       same_context=all(==(:proposition), differences), phenomenal_claim=:not_certified)
end

struct AuditEvent
    context::AuditContext
    status::Symbol
    reason::String
    evidence::Tuple{Vararg{String}}
    successor::String
    previous::String
    digest::String
end

function _event_dict(event::AuditEvent, sequence; include_digest=true)
    data = Dict{String,Any}(
        "sequence" => sequence, "context" => _context_dict(event.context),
        "status" => String(event.status), "reason" => event.reason,
        "evidence" => collect(event.evidence), "successor" => event.successor,
        "previous" => event.previous,
    )
    include_digest && (data["digest"] = event.digest)
    data
end

function _audit_digest(data)
    io = IOBuffer()
    TOML.print(io, data; sorted=true)
    bytes2hex(sha256(take!(io)))
end

function _validate_event(history, event)
    c = event.context
    event.status in AUDIT_STATUSES || throw(ArgumentError("invalid residual status"))
    _audit_text(event.reason)
    _audit_strings(event.evidence)
    earlier = filter(e -> e.context.question_id == c.question_id, history)
    isempty(earlier) && event.status != :open &&
        throw(ArgumentError("a question must first be recorded as open"))
    all(e -> e.context.question == c.question, earlier) ||
        throw(ArgumentError("original question text is immutable; use a new question ID"))
    event.status != :open && isempty(event.evidence) &&
        throw(ArgumentError("status changes require evidence references"))
    event.status == :conditional && isempty(c.assumptions) &&
        throw(ArgumentError("conditional status requires explicit assumptions"))
    if event.status == :reformulated
        _audit_text(event.successor)
        event.successor != c.question_id || throw(ArgumentError("self reformulation"))
        any(e -> e.context.question_id == event.successor, history) ||
            throw(ArgumentError("record the successor question before linking it"))
    else
        isempty(event.successor) || throw(ArgumentError("successor requires reformulated status"))
    end
    expected_previous = isempty(history) ? EMPTY_AUDIT_HEAD : last(history).digest
    event.previous == expected_previous || throw(ArgumentError("broken audit history chain"))
    event.digest == _audit_digest(_event_dict(event, length(history) + 1; include_digest=false)) ||
        throw(ArgumentError("audit content digest mismatch"))
    true
end

function _validate_history(history::Tuple)
    prefix = ()
    for event in history
        event isa AuditEvent || throw(ArgumentError("invalid audit event"))
        _validate_event(prefix, event)
        prefix = (prefix..., event)
    end
    true
end

function append_audit_event(history::Tuple, context::AuditContext, status::Symbol;
                            reason, evidence=(), successor="")
    _validate_history(history)
    event = AuditEvent(context, status, _audit_text(reason), _audit_strings(evidence),
        String(successor), isempty(history) ? EMPTY_AUDIT_HEAD : last(history).digest, "")
    digest = _audit_digest(_event_dict(event, length(history) + 1; include_digest=false))
    hashed = AuditEvent(event.context, event.status, event.reason, event.evidence,
                        event.successor, event.previous, digest)
    _validate_event(history, hashed)
    (history..., hashed)
end

function audit_receipt(history::Tuple)
    _validate_history(history)
    (count=length(history), head=isempty(history) ? EMPTY_AUDIT_HEAD : last(history).digest)
end

function audit_history_toml(history::Tuple)
    _validate_history(history)
    io = IOBuffer()
    TOML.print(io, Dict("schema_version" => 1, "phenomenal_claim" => "not_certified",
        "events" => [_event_dict(event, i) for (i, event) in enumerate(history)]); sorted=true)
    String(take!(io))
end

function parse_audit_history(text::AbstractString; expected_receipt=nothing)
    data = TOML.parse(text)
    _exact_keys(data, ("schema_version", "phenomenal_claim", "events"))
    typeof(data["schema_version"]) == Int && data["schema_version"] == 1 ||
        throw(ArgumentError("unsupported audit schema"))
    data["phenomenal_claim"] == "not_certified" || throw(ArgumentError("invalid phenomenal marker"))
    data["events"] isa Vector || throw(ArgumentError("events must be an array"))
    history = ()
    for (i, item) in enumerate(data["events"])
        _exact_keys(item, ("sequence", "context", "status", "reason", "evidence",
                           "successor", "previous", "digest"))
        typeof(item["sequence"]) == Int && item["sequence"] == i ||
            throw(ArgumentError("nonsequential audit event"))
        item["status"] isa String && Symbol(item["status"]) in AUDIT_STATUSES ||
            throw(ArgumentError("invalid residual status"))
        all(item[k] isa String for k in ("successor", "previous", "digest")) ||
            throw(ArgumentError("invalid event strings"))
        event = AuditEvent(_parse_context(item["context"]), Symbol(item["status"]),
            _audit_text(item["reason"]), _audit_strings(item["evidence"]),
            item["successor"], item["previous"], item["digest"])
        _validate_event(history, event)
        history = (history..., event)
    end
    expected_receipt === nothing || audit_receipt(history) == expected_receipt ||
        throw(ArgumentError("history differs from trusted receipt (including possible truncation)"))
    history
end

function audit_history_summary(history::Tuple)
    _validate_history(history)
    latest = Dict(event.context.question_id => event.status for event in history)
    counts = Dict(String(status) => count(==(status), values(latest)) for status in AUDIT_STATUSES)
    (; event_count=length(history), question_count=length(latest), counts,
       unresolved_count=counts["open"] + counts["underdetermined"],
       interpretation=:requires_review, phenomenal_claim=:not_certified)
end
