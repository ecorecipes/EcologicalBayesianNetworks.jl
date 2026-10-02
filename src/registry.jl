# The model registry: one `ModelSpec` per `models/<name>/metadata.toml`, built at
# precompile time from the manifests on disk (the ArkModelZoo.jl pattern, with TOML
# manifests as the source of truth instead of a Julia table).
#
# The upstream repositories are cited from the docstrings below with the keys of the
# shared bibliography (`docs/references.bib`): Scutari2010 (bnlearn), BNMA (the
# Bayesian Network Model Archive) and Leonelli2025 (bnRep).

"""
    MODELS_DIR

Absolute path of the `models/` directory that holds one manifest per model.
"""
const MODELS_DIR = normpath(joinpath(@__DIR__, "..", "models"))

"""
    MODEL_CATEGORY_ORDER

The allowed `category` values, in catalogue display order.
"""
const MODEL_CATEGORY_ORDER = ("reference", "habitat", "population", "water", "risk",
                              "biosecurity", "decision", "benchmark")

const MODEL_CATEGORY_INDEX = Dict(c => i for (i, c) in enumerate(MODEL_CATEGORY_ORDER))

"""
    MODEL_FORMATS

The allowed `format` values: the file formats read by BayesianNetworkFormats.jl, the binary
Netica `neta` (fetch-only, not readable), `julia` for models built in code, and `package`
for a data or code archive from which a network can be reconstructed but which is not
itself a network file (`redistribution = "reconstruction"`).
"""
const MODEL_FORMATS = ("dne", "xdsl", "net", "bif", "dsc", "uai", "neta", "julia",
                       "package")

"""
    REDISTRIBUTION_KINDS

The allowed `redistribution` values: `verbatim` (the original file is committed),
`fetch-only` (metadata only; the file goes to the cache), `builtin` (Julia-built) and
`reconstruction` (a catalogue record for a Dryad, Zenodo, figshare or source-repository
package: metadata and URLs only, nothing to load).
"""
const REDISTRIBUTION_KINDS = ("verbatim", "fetch-only", "builtin", "reconstruction")

const REQUIRED_MANIFEST_KEYS = ("name", "title", "category", "domain_tags", "format",
                                "source_url", "download_url", "fetch_instructions",
                                "citation", "doi", "licence", "redistribution",
                                "has_decisions", "has_utilities", "n_nodes", "n_arcs",
                                "retrieved", "sha256", "notes")

"""
    ModelSpec

Metadata of one zoo model, mirroring its `metadata.toml` (see `models/README.md` for the
meaning of every field). `directory` is the manifest directory relative to
[`MODELS_DIR`](@ref); `file` is empty for fetch-only and Julia-built models; `constructor`
names the function of this module that builds a `format = "julia"` model;
`parser_options` are the `strict`, `atol`, `renormalize`, `allow_missing_tables`,
`max_states` and `max_table_cells` keywords applied by [`model_ir`](@ref);
`known_parse_issue` is non-empty when the current readers
cannot parse the file (empty for every current model); `aliases` are extra lookup keys for
[`model_info`](@ref), used for the repository record numbers of models from the
Bayesian Network Model Archive [BNMA](@cite) (`"BNMA 126"` finds
`koalas`).
"""
Base.@kwdef struct ModelSpec
    name::String
    title::String
    category::String
    domain_tags::Vector{String} = String[]
    format::String
    file::String = ""
    constructor::String = ""
    source_url::String = ""
    download_url::String = ""
    fetch_instructions::String = ""
    citation::String = ""
    doi::String = ""
    licence::String = ""
    redistribution::String
    has_decisions::Bool = false
    has_utilities::Bool = false
    n_nodes::Int = 0
    n_arcs::Int = 0
    retrieved::String = ""
    sha256::String = ""
    known_parse_issue::String = ""
    notes::String = ""
    parser_options::Dict{Symbol,Any} = Dict{Symbol,Any}()
    aliases::Vector{String} = String[]
    directory::String
end

function Base.show(io::IO, spec::ModelSpec)
    return print(io, "ModelSpec(", repr(spec.name), ", ", spec.format, ", ",
                 spec.redistribution,
                 ")")
end

# Field-wise equality (the default compares Vector and Dict fields by identity).
function Base.:(==)(a::ModelSpec, b::ModelSpec)
    return all(getfield(a, f) == getfield(b, f) for f in fieldnames(ModelSpec))
end
function Base.hash(spec::ModelSpec, h::UInt)
    for f in fieldnames(ModelSpec)
        h = hash(getfield(spec, f), h)
    end
    return h
end

"""
    is_verbatim(spec) -> Bool

`true` when the original file is committed (`redistribution = "verbatim"`).
"""
is_verbatim(spec::ModelSpec) = spec.redistribution == "verbatim"

"""
    is_fetch_only(spec) -> Bool

`true` when only metadata is committed and the file lives in the cache
(`redistribution = "fetch-only"`).
"""
is_fetch_only(spec::ModelSpec) = spec.redistribution == "fetch-only"

"""
    is_builtin(spec) -> Bool

`true` for models built in Julia (`redistribution = "builtin"`, `format = "julia"`).
"""
is_builtin(spec::ModelSpec) = spec.redistribution == "builtin"

"""
    is_reconstruction(spec) -> Bool

`true` for a catalogue record of a data or code archive rather than a runnable network
(`redistribution = "reconstruction"`, `format = "package"`): the Dryad, Zenodo, figshare
and source-repository packages from the source catalogue. These entries carry the source
URL, licence, citation and a note on what the archive holds; they have no file, no
checksum and no node counts, and [`model_path`](@ref), [`model_ir`](@ref) and
[`load_model`](@ref) raise [`ReconstructionOnlyError`](@ref) for them.
"""
is_reconstruction(spec::ModelSpec) = spec.redistribution == "reconstruction"

"""
    is_redistributable(spec) -> Bool

`true` for verbatim and built-in models, whose files (or code) ship with the package.
Fetch-only models and reconstruction packages are not: nothing of them is committed.
"""
is_redistributable(spec::ModelSpec) = is_verbatim(spec) || is_builtin(spec)

"""
    is_influence_diagram(spec) -> Bool

`true` when the model has decision or utility nodes.
"""
is_influence_diagram(spec::ModelSpec) = spec.has_decisions || spec.has_utilities

"""
    model_dir(spec) -> String

Absolute path of the model's manifest directory.
"""
model_dir(spec::ModelSpec) = joinpath(MODELS_DIR, spec.directory)

"""
    _normalize_model_lookup_key(name) -> String

Lower-case `name` and remove everything that is not a letter or a digit, so that
`"Song Sparrow BDN"`, `:song_sparrow_bdn` and `"song-sparrow-bdn"` all find the same
model.
"""
function _normalize_model_lookup_key(name::Union{AbstractString,Symbol})
    return replace(lowercase(strip(String(name))), r"[^a-z0-9]+" => "")
end

function _manifest_string(d, key, path)
    v = get(d, key, "")
    v isa AbstractString ||
        throw(InvalidManifestError(path, "key $(key) must be a string, got $(typeof(v))"))
    return String(v)
end

function _manifest_bool(d, key, path)
    v = get(d, key, false)
    v isa Bool || throw(InvalidManifestError(path, "key $(key) must be true or false"))
    return v
end

function _manifest_int(d, key, path)
    v = get(d, key, 0)
    v isa Integer || throw(InvalidManifestError(path, "key $(key) must be an integer"))
    return Int(v)
end

function _manifest_strings(d, key, path)
    v = get(d, key, String[])
    (v isa AbstractVector && all(x -> x isa AbstractString, v)) ||
        throw(InvalidManifestError(path, "key $(key) must be an array of strings"))
    return String.(v)
end

# Every parser option a manifest or a keyword may set; loading.jl says where each goes.
const _OPTION_KEYS = (:strict, :atol, :renormalize, :allow_missing_tables, :max_states,
                      :max_table_cells)

# One `[parser_options]` entry: a key `model_ir` accepts (`_OPTION_KEYS`, loading.jl) with
# a value of the right type, checked when the manifest is read rather than when the model
# is first loaded (ADR 0015).
function _manifest_option(k::Symbol, v, path)
    k in _OPTION_KEYS ||
        throw(InvalidManifestError(path,
                                   "unknown parser option \"$k\"; allowed: $(join(_OPTION_KEYS, ", "))"))
    if k === :atol
        v isa Real && !(v isa Bool) && isfinite(v) && v >= 0 ||
            throw(InvalidManifestError(path,
                                       "parser option atol must be a finite nonnegative number, got $(repr(v))"))
    elseif k in (:max_states, :max_table_cells)
        # the size limits of BayesianNetworkFormats' readers, which take positive integers
        v isa Integer && !(v isa Bool) && v >= 1 ||
            throw(InvalidManifestError(path,
                                       "parser option $k must be a positive integer, got $(repr(v))"))
    else
        v isa Bool ||
            throw(InvalidManifestError(path,
                                       "parser option $k must be true or false, got $(repr(v))"))
    end
    return v
end

"""
    read_manifest(path) -> ModelSpec

Parse and validate one `metadata.toml`. Every key in `REQUIRED_MANIFEST_KEYS` must be
present; `category`, `format` and `redistribution` must take allowed values; verbatim
models need an existing `file`; Julia-built models need a `constructor` and
`format = "julia"`; fetch-only models must not have a `file`; `[parser_options]` may
hold only `strict`, `atol`, `renormalize`, `allow_missing_tables`, `max_states` and
`max_table_cells`, with boolean values, a finite nonnegative `atol`, and positive integers
for the two size limits of BayesianNetworkFormats' readers. The `name` must equal the
directory name. Throws [`InvalidManifestError`](@ref).
"""
function read_manifest(path::AbstractString)
    isfile(path) || throw(InvalidManifestError(path, "manifest file not found"))
    d = try
        TOML.parsefile(path)
    catch e
        # Only the parser's own error is about the manifest's content (ADR 0015); the file
        # was checked above, and anything else propagates.
        e isa TOML.ParserError || rethrow()
        throw(InvalidManifestError(path, "TOML parse error: " * sprint(showerror, e)))
    end
    dir = basename(dirname(path))
    missing_keys = [k for k in REQUIRED_MANIFEST_KEYS if !haskey(d, k)]
    isempty(missing_keys) ||
        throw(InvalidManifestError(path,
                                   "missing required keys: " * join(missing_keys, ", ")))
    name = _manifest_string(d, "name", path)
    name == dir ||
        throw(InvalidManifestError(path,
                                   "name $(repr(name)) does not match the directory $(repr(dir))"))
    category = _manifest_string(d, "category", path)
    category in MODEL_CATEGORY_ORDER ||
        throw(InvalidManifestError(path,
                                   "category $(repr(category)) is not one of $(join(MODEL_CATEGORY_ORDER, ", "))"))
    format = _manifest_string(d, "format", path)
    format in MODEL_FORMATS ||
        throw(InvalidManifestError(path,
                                   "format $(repr(format)) is not one of $(join(MODEL_FORMATS, ", "))"))
    redistribution = _manifest_string(d, "redistribution", path)
    redistribution in REDISTRIBUTION_KINDS ||
        throw(InvalidManifestError(path,
                                   "redistribution $(repr(redistribution)) is not one of $(join(REDISTRIBUTION_KINDS, ", "))"))
    file = _manifest_string(d, "file", path)
    constructor = _manifest_string(d, "constructor", path)
    if redistribution == "verbatim"
        isempty(file) && throw(InvalidManifestError(path, "verbatim models need a file"))
        isfile(joinpath(dirname(path), file)) ||
            throw(InvalidManifestError(path, "committed file $(file) not found"))
    elseif redistribution == "fetch-only"
        isempty(file) ||
            throw(InvalidManifestError(path,
                                       "fetch-only models must not have a committed file"))
    elseif redistribution == "reconstruction"
        format == "package" ||
            throw(InvalidManifestError(path,
                                       "reconstruction records must have format = \"package\""))
        isempty(file) ||
            throw(InvalidManifestError(path,
                                       "reconstruction records must not have a committed file"))
        isempty(_manifest_string(d, "source_url", path)) &&
            throw(InvalidManifestError(path,
                                       "reconstruction records need a source_url: the record is the only thing they carry"))
    else
        format == "julia" ||
            throw(InvalidManifestError(path, "builtin models must have format = \"julia\""))
    end
    if format == "package"
        redistribution == "reconstruction" ||
            throw(InvalidManifestError(path,
                                       "format = \"package\" requires redistribution = \"reconstruction\""))
    end
    if format == "julia"
        redistribution == "builtin" ||
            throw(InvalidManifestError(path,
                                       "format = \"julia\" requires redistribution = \"builtin\""))
        isempty(constructor) &&
            throw(InvalidManifestError(path, "Julia-built models need a constructor"))
    end
    popts = Dict{Symbol,Any}()
    if haskey(d, "parser_options")
        po = d["parser_options"]
        po isa AbstractDict ||
            throw(InvalidManifestError(path, "parser_options must be a table"))
        for (k, v) in po
            popts[Symbol(k)] = _manifest_option(Symbol(k), v, path)
        end
    end
    return ModelSpec(; name, title=_manifest_string(d, "title", path), category,
                     domain_tags=_manifest_strings(d, "domain_tags", path), format, file,
                     constructor, source_url=_manifest_string(d, "source_url", path),
                     download_url=_manifest_string(d, "download_url", path),
                     fetch_instructions=_manifest_string(d, "fetch_instructions", path),
                     citation=_manifest_string(d, "citation", path),
                     doi=_manifest_string(d, "doi", path),
                     licence=_manifest_string(d, "licence", path), redistribution,
                     has_decisions=_manifest_bool(d, "has_decisions", path),
                     has_utilities=_manifest_bool(d, "has_utilities", path),
                     n_nodes=_manifest_int(d, "n_nodes", path),
                     n_arcs=_manifest_int(d, "n_arcs", path),
                     retrieved=_manifest_string(d, "retrieved", path),
                     sha256=lowercase(_manifest_string(d, "sha256", path)),
                     known_parse_issue=_manifest_string(d, "known_parse_issue", path),
                     notes=_manifest_string(d, "notes", path), parser_options=popts,
                     aliases=_manifest_strings(d, "aliases", path), directory=dir)
end

_spec_sort_key(spec::ModelSpec) = (MODEL_CATEGORY_INDEX[spec.category], spec.name)

"""
    load_model_specs(dir = MODELS_DIR) -> Vector{ModelSpec}

Read every `<dir>/*/metadata.toml`, sorted by category (in `MODEL_CATEGORY_ORDER`) then
name. Used once at precompile time to build [`MODEL_SPECS`](@ref); scripts call it to
re-read manifests they have just edited.
"""
function load_model_specs(dir::AbstractString=MODELS_DIR)
    specs = ModelSpec[]
    isdir(dir) || return specs
    for d in sort(readdir(dir))
        path = joinpath(dir, d, "metadata.toml")
        isfile(path) || continue
        # Editing a manifest must invalidate the precompile cache that holds MODEL_SPECS.
        dir == MODELS_DIR && include_dependency(path)
        push!(specs, read_manifest(path))
    end
    sort!(specs; by=_spec_sort_key)
    return specs
end

include_dependency(MODELS_DIR)

"""
    MODEL_SPECS

Every registered model, loaded from the manifests at precompile time and sorted by
category then name.

The models come from the published ecological literature and from four public
collections: the Bayesian Network Model Archive [BNMA](@cite), the
bnlearn network repository of [Scutari2010](@cite), the bnRep collection of
[Leonelli2025](@cite), and the supplementary material of individual papers. Every
manifest records the citation, the DOI, the licence and the retrieval date of its
model; nothing is redistributed whose licence does not allow it (see
[`is_redistributable`](@ref)).
"""
const MODEL_SPECS = load_model_specs()

function _build_lookup(specs)
    lookup = Dict{String,ModelSpec}()
    for spec in specs
        lookup[_normalize_model_lookup_key(spec.name)] = spec
        for alias in spec.aliases
            lookup[_normalize_model_lookup_key(alias)] = spec
        end
    end
    for spec in specs
        # Secondary keys (title, file name) must not shadow a canonical name.
        for extra in (spec.title, spec.file)
            isempty(extra) && continue
            key = _normalize_model_lookup_key(extra)
            haskey(lookup, key) || (lookup[key] = spec)
        end
    end
    return lookup
end

const MODEL_SPEC_LOOKUP = _build_lookup(MODEL_SPECS)

"""
    model_info(name) -> ModelSpec

Look up a model by name, alias, title or file name, ignoring case, spaces and
punctuation. Throws [`UnknownModelError`](@ref).

The Song Sparrow belief decision network of [Kotalik2026](@cite), for example, is
registered as `song_sparrow_bdn` and found by any of those spellings.

```julia
model_info("water").licence            # "CC BY-SA 3.0"
model_info("Song Sparrow BDN").doi     # "10.59381/ofwegrfqyo"
```
"""
function model_info(name::Union{AbstractString,Symbol})
    spec = get(MODEL_SPEC_LOOKUP, _normalize_model_lookup_key(name), nothing)
    spec === nothing && throw(UnknownModelError(String(name)))
    return spec
end
model_info(spec::ModelSpec) = spec

"""
    n_models() -> Int

Number of registered models.
"""
n_models() = length(MODEL_SPECS)

"""
    model_categories() -> Vector{String}

The categories in catalogue order, restricted to those that have at least one model.
"""
function model_categories()
    present = Set(spec.category for spec in MODEL_SPECS)
    return [c for c in MODEL_CATEGORY_ORDER if c in present]
end

function _matches(spec::ModelSpec; category, kind, redistributable, format, licence)
    category === nothing || spec.category == String(category) || return false
    if kind != :any
        kind in (:bn, :id, :package) ||
            throw(ArgumentError("kind must be :any, :bn, :id or :package, got $(repr(kind))"))
        if kind == :package
            is_reconstruction(spec) || return false
        else
            is_reconstruction(spec) && return false
            (kind == :id) == is_influence_diagram(spec) || return false
        end
    end
    redistributable === nothing || is_redistributable(spec) == redistributable ||
        return false
    format === nothing || spec.format == String(format) || return false
    licence === nothing || occursin(lowercase(licence), lowercase(spec.licence)) ||
        return false
    return true
end

"""
    ModelCatalog

A filtered view of the registry returned by [`model_catalog`](@ref): iterable over
`ModelSpec`s and printed as a plain-text table.
"""
struct ModelCatalog
    specs::Vector{ModelSpec}
end
Base.length(c::ModelCatalog) = length(c.specs)
Base.iterate(c::ModelCatalog, state...) = iterate(c.specs, state...)
Base.getindex(c::ModelCatalog, i) = c.specs[i]
Base.eltype(::Type{ModelCatalog}) = ModelSpec
Base.collect(c::ModelCatalog) = copy(c.specs)

"""
    model_catalog(; category=nothing, kind=:any, redistributable=nothing, format=nothing, licence=nothing) -> ModelCatalog

The registry filtered by `category`, by `kind` (`:bn` for chance-only networks, `:id`
for models with decision or utility nodes, `:package` for reconstruction records, `:any`), by whether the file ships with the
package (`redistributable = true` for verbatim and built-in models, `false` for
fetch-only), by `format`, or by a substring of the `licence`. Printing the result gives a
text table; iterate it for the `ModelSpec`s.
"""
function model_catalog(; category=nothing, kind::Symbol=:any, redistributable=nothing,
                       format=nothing, licence=nothing)
    return ModelCatalog([spec
                         for spec in MODEL_SPECS
                         if _matches(spec; category, kind, redistributable, format,
                                     licence)])
end

"""
    available_models(; category=nothing, kind=:any, redistributable=nothing) -> Vector{String}

Sorted names of the registered models, filtered as in [`model_catalog`](@ref).
"""
function available_models(; category=nothing, kind::Symbol=:any, redistributable=nothing)
    return sort!([spec.name for spec in model_catalog(; category, kind, redistributable)])
end

const CATALOG_COLUMNS = ("name", "category", "format", "licence", "redistribution",
                         "nodes", "arcs", "kind")

function _catalog_row(spec::ModelSpec)
    return (spec.name, spec.category, spec.format, spec.licence, spec.redistribution,
            string(spec.n_nodes), string(spec.n_arcs),
            is_reconstruction(spec) ? "package" : is_influence_diagram(spec) ? "ID" : "BN")
end

"""
    catalog_table(io, specs; markdown=false)

Print `specs` as a plain-text (or, with `markdown = true`, GitHub-flavoured Markdown)
table with the columns name, category, format, licence, redistribution, nodes, arcs and
kind (`BN`, `ID` or `package`).
"""
function catalog_table(io::IO, specs; markdown::Bool=false)
    rows = [_catalog_row(spec) for spec in specs]
    widths = [maximum(length, (CATALOG_COLUMNS[j], (r[j] for r in rows)...))
              for j in eachindex(CATALOG_COLUMNS)]
    function fmt(cells)
        return join((rpad(c, w) for (c, w) in zip(cells, widths)),
                    markdown ? " | " : "  ")
    end
    if markdown
        println(io, "| ", fmt(CATALOG_COLUMNS), " |")
        println(io, "| ", join(("-"^w for w in widths), " | "), " |")
        foreach(r -> println(io, "| ", fmt(r), " |"), rows)
    else
        println(io, fmt(CATALOG_COLUMNS))
        println(io, join(("-"^w for w in widths), "  "))
        foreach(r -> println(io, fmt(r)), rows)
    end
    return nothing
end

function Base.show(io::IO, ::MIME"text/plain", c::ModelCatalog)
    n = length(c)
    println(io, "ModelCatalog with ", n, " model", n == 1 ? "" : "s")
    n == 0 || catalog_table(io, c.specs)
    return nothing
end
Base.show(io::IO, c::ModelCatalog) = print(io, "ModelCatalog(", length(c), " models)")

function Base.show(io::IO, ::MIME"text/plain", spec::ModelSpec)
    println(io, "ModelSpec ", spec.name)
    for (label, value) in (("title", spec.title), ("category", spec.category),
                           ("tags", join(spec.domain_tags, ", ")),
                           ("format", spec.format),
                           ("file", isempty(spec.file) ? "(none)" : spec.file),
                           ("constructor", spec.constructor),
                           ("licence", spec.licence),
                           ("redistribution", spec.redistribution),
                           ("nodes / arcs", "$(spec.n_nodes) / $(spec.n_arcs)"),
                           ("kind",
                            is_reconstruction(spec) ? "reconstruction package" :
                            is_influence_diagram(spec) ? "influence diagram" :
                            "Bayesian network"),
                           ("source", spec.source_url), ("download", spec.download_url),
                           ("doi", spec.doi), ("citation", spec.citation),
                           ("retrieved", spec.retrieved), ("sha256", spec.sha256),
                           ("parser options",
                            join(("$k = $v" for (k, v) in spec.parser_options), ", ")),
                           ("known parse issue", spec.known_parse_issue),
                           ("fetch instructions", spec.fetch_instructions),
                           ("notes", spec.notes))
        isempty(value) && continue
        println(io, "  ", rpad(label, 19), value)
    end
    return nothing
end
