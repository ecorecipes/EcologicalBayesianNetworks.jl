# An external witness for the CPT axis convention (ADR 0002).
#
# Netica writes, beside every row of a `probs` block, a `// <parent state labels>` comment
# naming that row's parent configuration. The comment is written by Netica, not by us, so
# checking each annotated row against the table our reader builds tests the parent-axis
# order against an outside authority rather than against our own assumption. The zoo's
# seven Netica-written files have 2-5 parents of differing cardinalities, which is what
# makes the check able to fail: with binary parents alone a transposition is invisible.
#
# Rows whose labels cannot be resolved are counted and reported, never silently dropped.
# They are the continuous interval nodes, where Netica renders a bin as `0 to <1` or `>=1`
# while the reader derives `0 to 1` and `1 to 2` from the declared levels; the two namings
# cannot be matched by string. `MIN_ASSERTIONS` keeps the test from going vacuous if a
# future change to either side stops the labels resolving.

const MIN_ASSERTIONS = 50_000

_collapse_ws(x::AbstractString) = strip(replace(x, r"\s+" => " "))

# Consume the comment greedily against each parent's declared states, longest name first,
# and require the whole comment to be consumed: state names may contain spaces, so they
# cannot be split on whitespace.
function _match_row_labels(txt::AbstractString, pstates::Vector{Vector{String}})
    s = _collapse_ws(txt)
    idx = Int[]
    for states in pstates
        hit = 0
        for k in sortperm(states; by=length, rev=true)
            st = _collapse_ws(states[k])
            startswith(s, st) || continue
            rest = SubString(s, 1 + ncodeunits(st))
            if isempty(strip(rest)) || isspace(first(rest))
                hit = k
                s = strip(rest)
                break
            end
        end
        hit == 0 && return nothing
        push!(idx, hit)
    end
    return isempty(strip(s)) ? idx : nothing
end

# A row may wrap over several lines; the comment marks its end.
function _netica_row_witnesses(path)
    out = Tuple{String,String,Vector{Float64}}[]
    node = ""
    inblock = false
    buf = Float64[]
    for raw in split(read(path, String), '\n')
        m = match(r"^\s*node\s+(\w+)", raw)
        m === nothing || (node = String(m.captures[1]))
        if occursin(r"^\s*probs\s*=", raw)
            inblock = true
            empty!(buf)
            continue
        end
        inblock || continue
        for numstr in eachmatch(r"-?\d+\.?\d*(?:[eE][-+]?\d+)?", split(raw, "//")[1])
            push!(buf, parse(Float64, numstr.match))
        end
        if occursin("//", raw)
            comment = strip(replace(split(raw, "//"; limit=2)[2], r";\s*$" => ""))
            if !isempty(comment) && !isempty(buf)
                push!(out, (node, String(comment), copy(buf)))
                empty!(buf)
            end
        end
        occursin(";", raw) && (inblock = false)
    end
    return out
end

@testset "Netica row comments witness the CPT axis convention" begin
    paths = sort(filter(p -> endswith(p, ".dne"),
                        [joinpath(root, f)
                         for (root, _, files) in
                             walkdir(joinpath(@__DIR__, "..", "models"))
                         for f in files]))
    @test length(paths) == 7

    assertions = 0
    rows = 0
    unresolved = 0
    # Every annotated entry is compared; the assertion is per file so that the suite reports
    # one result per external witness rather than one per table cell.
    for path in paths
        ir = read_network(path)
        byid = Dict(v.id => v for v in ir.variables)
        mismatches = Tuple{String,String,Int,Float64,Float64}[]
        for (node, comment, row) in _netica_row_witnesses(path)
            var = get(byid, Symbol(node), nothing)
            if var === nothing || var.table === nothing || isempty(var.parents) ||
               length(row) != length(var.states)
                continue
            end
            pstates = Vector{String}[byid[p].states for p in var.parents]
            idx = _match_row_labels(comment, pstates)
            if idx === nothing
                unresolved += 1
                continue
            end
            for (j, val) in enumerate(row)
                assertions += 1
                got = var.table[idx..., j]
                isapprox(got, val; atol=1e-9) ||
                    push!(mismatches, (node, comment, j, got, val))
            end
            rows += 1
        end
        @test isempty(mismatches)
        isempty(mismatches) || @info "axis mismatches" path first(mismatches, 5)
    end
    @info "Netica axis oracle" rows assertions unresolved
    @test assertions >= MIN_ASSERTIONS
end
