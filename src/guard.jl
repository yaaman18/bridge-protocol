function check_terminal_guard(objects, reaches)
    !any(terminal -> all(source -> reaches(source, terminal), objects), objects)
end

function check_trace_safe(protect, mutation, systems)
    all(system -> protect(mutation(system)) == protect(system), systems)
end
