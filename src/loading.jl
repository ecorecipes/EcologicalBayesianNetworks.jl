# Reading zoo models into the BayesianNetworkFormats `NetworkIR` and into `BayesModel`s.

# Which manifest / keyword options go where: the readers take `strict`, `atol` and
# `renormalize`; the validation step of `model_ir` takes `atol`, `renormalize` and
# `allow_missing_tables`; `BayesModel(ir)` takes `atol` and `renormalize`.
const _READ_KEYS = (:strict, :atol, :renormalize)
const _VALIDATE_KEYS = (:atol, :renormalize, :allow_missing_tables)
const _BUILD_KEYS = (:atol, :renormalize)
# `_OPTION_KEYS`, every option, is in registry.jl: `read_manifest` checks manifests with it
# at precompile time, before this file is included.

function _split_options(spec::ModelSpec, kw)
    opts = merge(spec.parser_options, Dict{Symbol,Any}(pairs(kw)))
    unknown = setdiff(keys(opts), _OPTION_KEYS)
    isempty(unknown) ||
        throw(ArgumentError("unknown parser option(s) $(join(unknown, ", ")) for model $(spec.name); allowed: $(join(_OPTION_KEYS, ", "))"))
    pick(ks) = (; (k => opts[k] for k in ks if haskey(opts, k))...)
    return pick(_READ_KEYS), pick(_VALIDATE_KEYS), pick(_BUILD_KEYS)
end

"""
    read_model_file(spec, path; kw...) -> NetworkIR

Read a model file with `BayesianNetworkFormats.read_network`, decompressing `.gz`
files in memory (the readers do not handle gzip) and detecting the format from the
uncompressed name. The manifest `[parser_options]` are applied first and overridden by
`kw` (`strict`, `atol`, `renormalize`; `allow_missing_tables` is accepted and ignored,
since the readers always tolerate missing tables). No validation beyond the reader's
own: use [`model_ir`](@ref) for the validated IR.
"""
function read_model_file(spec::ModelSpec, path::AbstractString; kw...)
    read_opts, _, _ = _split_options(spec, kw)
    spec.format == "neta" &&
        throw(NotAModelFileError(spec.name,
                                 "$(path) is a binary Netica .neta file, which BayesianNetworkFormats.jl cannot read; save it as .dne from Netica and import_model the result"))
    if endswith(lowercase(path), ".gz")
        fmt = detect_format(path[1:(end - 3)])
        bytes = open(io -> read(GzipDecompressorStream(io)), path)
        return read_network(IOBuffer(bytes), fmt; file=path, read_opts...)
    end
    return read_network(path; read_opts...)
end

function _constructor(spec::ModelSpec)
    isdefined(@__MODULE__, Symbol(spec.constructor)) ||
        throw(InvalidManifestError(joinpath(model_dir(spec), "metadata.toml"),
                                   "constructor $(spec.constructor) is not defined in EcologicalBayesianNetworks"))
    f = getfield(@__MODULE__, Symbol(spec.constructor))
    # A manifest naming something that cannot build a model is the manifest's error, not
    # a `MethodError` at load time (ADR 0015).
    applicable(f) ||
        throw(InvalidManifestError(joinpath(model_dir(spec), "metadata.toml"),
                                   "constructor $(spec.constructor) cannot be called without arguments"))
    return f
end

function _builtin_object(spec::ModelSpec)
    return _constructor(spec)()
end

# Julia-built models are constructed, not parsed, so some keywords have nothing to act on.
# Silently ignoring one would hide a real mistake (`load_model(name; atol)` looking as
# though it had loosened a tolerance), so an explicitly passed keyword is rejected by name.
# Manifest `[parser_options]` are not rejected: they describe a file, and a `format =
# "julia"` manifest has none.
function _reject_builtin_options(spec::ModelSpec, kw, applicable, why)
    ignored = intersect(keys(NamedTuple(kw)), applicable)
    isempty(ignored) && return nothing
    return throw(ArgumentError("option(s) $(join(sort(string.(collect(ignored))), ", ")) do not apply to the Julia-built model $(spec.name): $(why)"))
end

"""
    model_ir(name; kw...) -> NetworkIR

The `NetworkIR` of a model: read from the committed or cached file (gunzipped on the fly,
with the manifest `[parser_options]` overridden by `kw`), or built for Julia models
(`NetworkIR(model)` for a `BayesModel`, the constructor result when it already is an IR).
The IR is then checked with `BayesianNetworkFormats.validate(ir; atol, renormalize,
allow_missing_tables)`, so by default every chance node must carry a table. Netica
files often hold finding or equation nodes with `evidence` but no `probs`; their
manifests set `allow_missing_tables = true` (and [`model_summary`](@ref) reports how
many chance nodes lack a table), and `model_ir(name; allow_missing_tables=true)` does
the same for any model. Throws [`ModelNotFetchedError`](@ref) when a fetch-only model
is not cached.

For a Julia-built model (`format = "julia"`) there is no file, so `strict` has nothing
to parse: passing it raises an `ArgumentError` naming the model rather than being
ignored. `atol`, `renormalize` and `allow_missing_tables` still reach the validation
step and are honoured.

```julia
ir = model_ir("water")
length(ir.variables)     # 32
```
"""
function model_ir(name; kw...)
    spec = model_info(name)
    is_reconstruction(spec) &&
        throw(ReconstructionOnlyError(spec.name, spec.source_url, spec.licence))
    _, validate_opts, _ = _split_options(spec, kw)
    if is_builtin(spec)
        _reject_builtin_options(spec, kw, (:strict,),
                                "there is no file to parse strictly")
        ir = NetworkIR(_builtin_object(spec); name=spec.name)
    else
        ir = read_model_file(spec, model_path(spec); kw...)
    end
    return BayesianNetworkFormats.validate(ir; validate_opts...)
end

"""
    load_model(name; kw...) -> BayesModel or InfluenceDiagramModel

Load a model with its tables bound: a chance-only model as a
`BayesianNetworks.BayesModel` (`BayesModel(model_ir(name))`), a model with decision or
utility nodes as an `InfluenceDiagrams.InfluenceDiagramModel`
(`InfluenceDiagramModel(model_ir(name))`, chance kernels and tabular utilities bound,
information sets from the decision nodes' parents), and the Julia-built object for
reference models. `kw` are `strict`, `atol`, `renormalize` and `allow_missing_tables`
as for [`model_ir`](@ref); a chance node without a table leaves its mechanism unbound
(`BayesianNetworks.missing_kernels`), which `optimize` and `validate(m; semantics =
true)` report.

A Julia-built model is returned by its constructor with its kernels already bound, so
none of the parser or build keywords apply; passing `atol` or `renormalize` for one
raises an `ArgumentError` naming the model instead of being silently dropped. Use
`model_ir(name)` and build the model by hand if those tolerances matter.

```julia
m = load_model("native_fish_v1")
marginal(m, :FishAbundance)
id = load_model("waterhole_fence")
optimize(id).expected_utility
```
"""
function load_model(name; kw...)
    spec = model_info(name)
    is_reconstruction(spec) &&
        throw(ReconstructionOnlyError(spec.name, spec.source_url, spec.licence))
    _, _, build_opts = _split_options(spec, kw)
    if is_builtin(spec)
        _reject_builtin_options(spec, kw, _BUILD_KEYS,
                                "its constructor returns a model with its kernels already bound")
        return _builtin_object(spec)
    end
    return _build_model(model_ir(spec; kw...); build_opts...)
end

function _is_influence_diagram(ir::NetworkIR)
    return any(v -> v.kind in (DecisionNode, UtilityNode),
               ir.variables)
end

function _build_model(ir::NetworkIR; kw...)
    return _is_influence_diagram(ir) ? InfluenceDiagramModel(ir; kw...) :
           BayesModel(ir; kw...)
end

"""
    ModelSummary

Structural summary of a model returned by [`model_summary`](@ref): node counts by kind,
arcs, state-space sizes, skipped nodes, chance nodes without a table
(`n_missing_tables`) and whether [`load_model`](@ref) produces a `BayesModel`
(`loadable`, chance-only models) rather than an `InfluenceDiagramModel`.
"""
struct ModelSummary
    name::String
    title::String
    format::String
    licence::String
    redistribution::String
    n_nodes::Int
    n_arcs::Int
    n_chance::Int
    n_decision::Int
    n_utility::Int
    n_skipped::Int
    n_missing_tables::Int
    max_states::Int
    max_in_degree::Int
    has_decisions::Bool
    has_utilities::Bool
    loadable::Bool
end

"""
    model_summary(name; kw...) -> ModelSummary

Parse the model and count its nodes by kind, its arcs, the largest state space and
in-degree, the nodes skipped by a non-strict read and the chance nodes that have no
table (Netica finding or equation nodes; their mechanisms stay unbound in a
`BayesModel`). `loadable` is `true` when the model is chance-only, so that
[`load_model`](@ref) returns a `BayesModel`; for models with decision or utility nodes
it returns an `InfluenceDiagramModel` instead.
"""
function model_summary(name; kw...)
    spec = model_info(name)
    ir = model_ir(spec; kw...)
    n_chance = count(v -> v.kind == ChanceNode, ir.variables)
    n_decision = count(v -> v.kind == DecisionNode, ir.variables)
    n_utility = count(v -> v.kind == UtilityNode, ir.variables)
    n_arcs = sum(length(v.parents) for v in ir.variables; init=0)
    skipped = get(ir.extras, :skipped, nothing)
    n_skipped = skipped === nothing ? 0 : length(skipped)
    n_missing = count(v -> v.kind == ChanceNode && v.table === nothing, ir.variables)
    max_states = maximum((length(v.states) for v in ir.variables); init=0)
    max_in = maximum((length(v.parents) for v in ir.variables); init=0)
    return ModelSummary(spec.name, spec.title, spec.format, spec.licence,
                        spec.redistribution, length(ir.variables), n_arcs, n_chance,
                        n_decision, n_utility, n_skipped, n_missing, max_states, max_in,
                        n_decision > 0, n_utility > 0, n_decision == 0 && n_utility == 0)
end

function Base.show(io::IO, ::MIME"text/plain", s::ModelSummary)
    println(io, "ModelSummary ", s.name, " (", s.title, ")")
    println(io, "  format / licence     ", s.format, " / ", s.licence, " (",
            s.redistribution, ")")
    println(io, "  nodes                ", s.n_nodes, " (", s.n_chance, " chance, ",
            s.n_decision, " decision, ", s.n_utility, " utility)")
    println(io, "  arcs                 ", s.n_arcs)
    println(io, "  largest state space  ", s.max_states)
    println(io, "  largest in-degree    ", s.max_in_degree)
    s.n_skipped == 0 || println(io, "  skipped nodes        ", s.n_skipped)
    s.n_missing_tables == 0 ||
        println(io, "  nodes without a CPT  ", s.n_missing_tables)
    kind = s.loadable ? "BayesModel" : "InfluenceDiagramModel"
    print(io, "  load_model           ", kind,
          s.n_missing_tables == 0 ? "" :
          " ($(s.n_missing_tables) mechanism$(s.n_missing_tables == 1 ? "" : "s") unbound)")
    return nothing
end
function Base.show(io::IO, s::ModelSummary)
    return print(io, "ModelSummary(", repr(s.name), ", ", s.n_nodes, " nodes, ", s.n_arcs,
                 " arcs)")
end
