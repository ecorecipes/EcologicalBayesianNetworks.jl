# Fill the derived fields of a manifest from its model file.
#
#   julia --project scripts/add_model.jl models/<name> [path/to/downloaded/file]
#
# Reads models/<name>/metadata.toml, locates the file (the committed `file` for verbatim
# models, the cached file for fetch-only models, or the optional second argument, which is
# imported into the cache first), parses it with BayesianNetworkFormats.jl using the
# manifest's [parser_options], and rewrites n_nodes, n_arcs, has_decisions,
# has_utilities, sha256 and retrieved in place. Other keys are left untouched. For Julia
# models the constructor is used instead of a file; for unreadable formats (.neta) only
# sha256 and retrieved are filled.
using EcologicalBayesianNetworks
using BayesianNetworkFormats: DecisionNode, UtilityNode
using Dates: today

length(ARGS) >= 1 || (println("usage: add_model.jl models/<name> [file]"); exit(2))
dir = abspath(ARGS[1])
manifest = joinpath(dir, "metadata.toml")
spec = read_manifest(manifest)   # validates the hand-written keys first

function set_key!(lines, key, value)
    rendered = value isa AbstractString ? "$(key) = \"$(value)\"" : "$(key) = $(value)"
    for (i, line) in enumerate(lines)
        if occursin(Regex("^" * key * "\\s*="), line)
            lines[i] = rendered
            return lines
        end
    end
    # Insert before [parser_options] (or at the end) so the table stays last.
    idx = findfirst(l -> startswith(l, "[parser_options]"), lines)
    idx === nothing ? push!(lines, rendered) : insert!(lines, idx, rendered)
    return lines
end

updates = Pair{String,Any}[]
if is_builtin(spec)
    ir = model_ir(spec)
    push!(updates, "n_nodes" => length(ir.variables))
    push!(updates, "n_arcs" => sum(length(v.parents) for v in ir.variables; init=0))
    push!(updates, "has_decisions" => any(v -> v.kind == DecisionNode, ir.variables))
    push!(updates, "has_utilities" => any(v -> v.kind == UtilityNode, ir.variables))
else
    if length(ARGS) >= 2
        path = ARGS[2]
        # A manifest without a checksum yet: compute it before importing so that the
        # import does not warn or, worse, reject a stale value.
        isempty(spec.sha256) || println("checking $(path) against the recorded sha256")
        path = is_verbatim(spec) ? path :
               (isempty(spec.sha256) ?
                (mkpath(dirname(cached_path(spec)));
                 cp(path, cached_path(spec); force=true);
                 cached_path(spec)) :
                import_model(spec.name, path))
    else
        path = model_path(spec)
    end
    push!(updates, "sha256" => sha256_file(path))
    push!(updates, "retrieved" => string(today()))
    if spec.format == "neta"
        println("binary .neta file: node counts left as they are")
    else
        try
            local ir = read_model_file(spec, path)
            push!(updates, "n_nodes" => length(ir.variables))
            push!(updates,
                  "n_arcs" => sum(length(v.parents) for v in ir.variables; init=0))
            push!(updates,
                  "has_decisions" => any(v -> v.kind == DecisionNode, ir.variables))
            push!(updates,
                  "has_utilities" => any(v -> v.kind == UtilityNode, ir.variables))
        catch e
            println("could not parse $(path): ", sprint(showerror, e))
            println("record the reason in known_parse_issue and fill n_nodes / n_arcs by hand")
        end
    end
end

lines = readlines(manifest)
for (k, v) in updates
    set_key!(lines, k, v)
    println(rpad(k, 14), v)
end
write(manifest, join(lines, "\n") * "\n")
read_manifest(manifest)   # re-validate what we wrote
println("updated ", manifest)
