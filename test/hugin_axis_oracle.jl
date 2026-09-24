# A second external witness for the CPT axis convention (ADR 0002), independent of the
# Netica one in `netica_axis_oracle.jl`.
#
# A HUGIN `.net` potential writes its table as nested parentheses:
#
#     potential (Child | P1 P2) { data = ( ( ... ) ( ... ) ) ... ; }
#
# one nesting level per parent, outermost first, with the child's states in the innermost
# list. The nesting is therefore the file's own statement of the parent order, written by
# bnlearn rather than by us. The parser below walks that structure directly and is a
# separate implementation from the reader's, so a reshape or `permutedims` error in the
# reader shows up as a mismatch rather than cancelling out.
#
# The four bnlearn networks are the useful witnesses because their parents have differing
# cardinalities; with binary parents alone a transposition is invisible.

const HUGIN_MIN_ASSERTIONS = 600_000

function _parse_nested(s::AbstractString, i::Int)
    n = lastindex(s)
    while i <= n && isspace(s[i])
        i = nextind(s, i)
    end
    if s[i] == '('
        items = Any[]
        i = nextind(s, i)
        while true
            while i <= n && (isspace(s[i]) || s[i] == ',')
                i = nextind(s, i)
            end
            s[i] == ')' && return items, nextind(s, i)
            item, i = _parse_nested(s, i)
            push!(items, item)
        end
    end
    j = i
    while j <= n && !isspace(s[j]) && s[j] != ')' && s[j] != ','
        j = nextind(s, j)
    end
    return parse(Float64, s[i:prevind(s, j)]), j
end

function _hugin_potentials(text)
    out = Tuple{String,Vector{String},Any}[]
    for m in
        eachmatch(r"potential\s*\(\s*([^\)\|]+?)\s*(?:\|\s*([^\)]*?))?\s*\)\s*\{(.*?)\}"s,
                  text)
        child = String(strip(m.captures[1]))
        parents = m.captures[2] === nothing ? String[] :
                  String.(split(strip(m.captures[2])))
        d = match(r"data\s*=\s*(.*?);"s, m.captures[3])
        d === nothing && continue
        tree, _ = _parse_nested(String(d.captures[1]), 1)
        push!(out, (child, parents, tree))
    end
    return out
end

function _walk_nested!(tree, var, idx, state)
    if all(x -> x isa Number, tree)
        for (j, val) in enumerate(tree)
            state.assertions += 1
            got = var.table[idx..., j]
            isapprox(got, val; atol=1e-9) ||
                push!(state.mismatches, (var.id, copy(idx), j, got, val))
        end
    else
        for (i, sub) in enumerate(tree)
            _walk_nested!(sub, var, [idx; i], state)
        end
    end
    return state
end

mutable struct _AxisState
    assertions::Int
    mismatches::Vector{Any}
end

@testset "HUGIN data nesting witnesses the CPT axis convention" begin
    paths = sort([joinpath(root, f)
                  for (root, _, files) in walkdir(joinpath(@__DIR__, "..", "models"))
                  for f in files if endswith(f, ".net.gz")])
    @test length(paths) == 4

    total = 0
    potentials = 0
    skipped = 0
    for path in paths
        text = String(transcode(GzipDecompressor, read(path)))
        tmp = joinpath(mktempdir(), "network.net")
        write(tmp, text)
        ir = read_network(tmp)
        byid = Dict(String(v.id) => v for v in ir.variables)
        state = _AxisState(0, Any[])
        for (child, parents, tree) in _hugin_potentials(text)
            var = get(byid, child, nothing)
            if var === nothing || var.table === nothing ||
               String.(var.parents) != parents
                skipped += 1
                continue
            end
            potentials += 1
            _walk_nested!(tree, var, Int[], state)
        end
        @test isempty(state.mismatches)
        isempty(state.mismatches) ||
            @info "axis mismatches" path first(state.mismatches, 5)
        total += state.assertions
    end
    @info "HUGIN axis oracle" potentials assertions = total skipped
    @test skipped == 0
    @test total >= HUGIN_MIN_ASSERTIONS
end
