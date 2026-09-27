# The gitignored scratch cache for fetch-only models, checksum verification, download and
# manual import.

"""
    USER_AGENT

The `User-Agent` header sent by [`fetch_model`](@ref). Some hosts (Plexus) reject bare
browser strings while accepting descriptive ones.
"""
const USER_AGENT = "EcologicalBayesianNetworks.jl (Julia $(VERSION); https://github.com/ecorecipes/EcologicalBayesianNetworks.jl)"

# Set by `with_cache_dir`; takes precedence over ENV["ECOLOGICAL_BN_CACHE"] and over the
# Scratch.jl space so that a test suite or a vignette never touches the user's real cache.
const _CACHE_OVERRIDE = Ref{Union{Nothing,String}}(nothing)

"""
    CACHE_ENV_VAR

Name of the environment variable that overrides [`cache_dir`](@ref):
`ECOLOGICAL_BN_CACHE`.
"""
const CACHE_ENV_VAR = "ECOLOGICAL_BN_CACHE"

"""
    cache_dir() -> String

The directory that holds fetched and imported model files, one subdirectory per model.
It is, in order of precedence, the directory of an enclosing [`with_cache_dir`](@ref)
block, the value of the `ECOLOGICAL_BN_CACHE` environment variable
([`CACHE_ENV_VAR`](@ref)), or the package's Scratch.jl space (gitignored, per Julia
depot). The directory is created if it does not exist.

Overriding the root keeps a test suite or a rendered vignette from deleting a user's
downloaded models: the package's own suite runs entirely inside an `mktempdir()`.
"""
function cache_dir()
    override = _CACHE_OVERRIDE[]
    override === nothing || return _ensure_dir(override)
    env = get(ENV, CACHE_ENV_VAR, "")
    isempty(env) || return _ensure_dir(env)
    return @get_scratch!("models")
end

function _ensure_dir(dir::AbstractString)
    path = abspath(expanduser(String(dir)))
    isdir(path) || mkpath(path)
    return path
end

"""
    with_cache_dir(f, dir)

Run `f()` with [`cache_dir`](@ref) pointing at `dir` (created if needed), restoring the
previous root afterwards, and return `f()`'s value. Use it to keep tests, scripts and
vignettes away from the user's real cache.

```julia
mktempdir() do tmp
    with_cache_dir(tmp) do
        fetch_model("animals")
    end
end
```
"""
function with_cache_dir(f, dir::AbstractString)
    previous = _CACHE_OVERRIDE[]
    _CACHE_OVERRIDE[] = _ensure_dir(dir)
    try
        return f()
    finally
        _CACHE_OVERRIDE[] = previous
    end
end

"""
    cached_file_name(spec) -> String

File name used in the cache for a fetch-only model: `<name>.<format>`, plus `.gz` when
the download URL is gzipped.
"""
function cached_file_name(spec::ModelSpec)
    gz = endswith(lowercase(spec.download_url), ".gz") ? ".gz" : ""
    return spec.name * "." * spec.format * gz
end

"""
    cached_path(spec) -> String

Where the file of a fetch-only model lives once fetched or imported (whether or not it
exists yet).
"""
cached_path(spec::ModelSpec) = joinpath(cache_dir(), spec.name, cached_file_name(spec))

"""
    sha256_file(path) -> String

Lower-case hexadecimal SHA-256 of a file.
"""
sha256_file(path::AbstractString) = open(io -> bytes2hex(sha256(io)), path)

"""
    model_path(name) -> String

Path of the model file: the committed file for verbatim models, the cached file for
fetch-only models that have been fetched or imported. Throws
[`ModelNotFetchedError`](@ref) (with the fetch instructions) when a fetch-only model is
not in the cache and [`NoModelFileError`](@ref) for Julia-built models.
"""
function model_path(name)
    spec = model_info(name)
    is_reconstruction(spec) &&
        throw(ReconstructionOnlyError(spec.name, spec.source_url, spec.licence))
    is_builtin(spec) && throw(NoModelFileError(spec.name))
    is_verbatim(spec) && return joinpath(model_dir(spec), spec.file)
    path = cached_path(spec)
    isfile(path) && return path
    return throw(ModelNotFetchedError(spec.name, spec.fetch_instructions,
                                      spec.download_url))
end

"""
    is_available(name) -> Bool

`true` when the model can be loaded without a network call: verbatim and built-in models
always, fetch-only models once their file is in the cache, never for reconstruction packages
(which have no file at all).
"""
function is_available(name)
    spec = model_info(name)
    is_reconstruction(spec) && return false
    is_fetch_only(spec) || return true
    return isfile(cached_path(spec))
end

"""
    is_fetchable(name) -> Bool

`true` for fetch-only models that have a direct `download_url`.
"""
function is_fetchable(name)
    spec = model_info(name)
    return is_fetch_only(spec) && !isempty(spec.download_url)
end

"""
    fetchable_models() -> Vector{String}

Names of the fetch-only models that [`fetch_model`](@ref) can download directly.
"""
fetchable_models() = [spec.name for spec in MODEL_SPECS if is_fetchable(spec)]

const _HTML_MARKERS = ("<!doctype html", "<html", "<head>", "<body")

"""
    check_model_file(spec, path)

Reject files that are plainly not model files: empty files and HTML pages (a login page
or an error page returned instead of the download). Throws [`NotAModelFileError`](@ref).
"""
function check_model_file(spec::ModelSpec, path::AbstractString)
    isfile(path) || throw(NotAModelFileError(spec.name, "no file at $(path)"))
    filesize(path) == 0 && throw(NotAModelFileError(spec.name, "$(path) is empty"))
    raw = open(io -> read(io, 1024), path)
    # Binary content (gzip, .neta) cannot be an HTML page; only inspect valid text.
    head = isvalid(String, raw) ? lowercase(String(raw)) : ""
    any(m -> occursin(m, head), _HTML_MARKERS) &&
        throw(NotAModelFileError(spec.name,
                                 "$(path) looks like an HTML page rather than a $(spec.format) file; the server may have returned an error or login page"))
    return nothing
end

function _verify_checksum(spec::ModelSpec, path::AbstractString)
    actual = sha256_file(path)
    if isempty(spec.sha256)
        @warn "model $(spec.name) has no sha256 in its manifest; record $(actual) in $(joinpath(model_dir(spec), "metadata.toml"))" maxlog = 1
    elseif actual != spec.sha256
        throw(ChecksumMismatchError(spec.name, String(path), spec.sha256, actual))
    end
    return actual
end

"""
    fetch_model(name; force=false, verbose=true) -> String

Download a fetch-only model into the cache and return its path: the file is downloaded
to a temporary file beside its destination, checked to be a model file, checked against
the manifest `sha256` ([`ChecksumMismatchError`](@ref); a warning when the manifest has
no checksum) and renamed into [`cache_dir`](@ref). Already cached files are returned
without a download unless `force = true`. For verbatim models this is a no-op returning
the committed path; models without a `download_url` raise [`NoDownloadURLError`](@ref)
and must go through [`import_model`](@ref); Julia-built models raise
[`NoModelFileError`](@ref). Transport failures (no network, HTTP status, TLS) are
wrapped in a [`FetchError`](@ref) naming the model and the URL, with the underlying
`Downloads.RequestError` as its `cause`.

The temporary file is created inside the destination directory rather than in the
system temporary directory, so the final rename stays on one filesystem; a depot on a
volume separate from `/tmp` (Docker, CI runners) would otherwise fail with
`IOError: rename: cross-device link`.
"""
function fetch_model(name; force::Bool=false, verbose::Bool=true)
    spec = model_info(name)
    is_fetch_only(spec) || return model_path(spec)
    dest = cached_path(spec)
    isfile(dest) && !force && return dest
    isempty(spec.download_url) &&
        throw(NoDownloadURLError(spec.name, spec.fetch_instructions))
    verbose && @info "fetching $(spec.name) from $(spec.download_url)"
    mkpath(dirname(dest))
    tmp, io = mktemp(dirname(dest))
    close(io)
    try
        try
            Downloads.download(spec.download_url, tmp;
                               headers=["User-Agent" => USER_AGENT])
        catch e
            e isa InterruptException && rethrow()
            throw(FetchError(spec.name, spec.download_url, e))
        end
        check_model_file(spec, tmp)
        _verify_checksum(spec, tmp)
        _move_into_place(tmp, dest)
    finally
        isfile(tmp) && rm(tmp; force=true)
    end
    return dest
end

# `mv` is a plain `rename`, which fails across filesystems. `tmp` is created beside
# `dest`, so the rename normally succeeds; fall back to copy + remove for the cases where
# the cache root is itself a mount point or a bind mount.
function _move_into_place(tmp::AbstractString, dest::AbstractString)
    try
        mv(tmp, dest; force=true)
    catch e
        e isa Base.IOError || rethrow()
        cp(tmp, dest; force=true)
        rm(tmp; force=true)
    end
    return dest
end

"""
    import_model(name, path) -> String

Copy a manually downloaded file into the cache for a fetch-only model, after checking
that it is a model file and that its SHA-256 matches the manifest (a warning when the
manifest has no checksum). Returns the cached path. For a verbatim model the file is
only checked against the committed one and the committed path is returned.

A path with no file, an empty file or an HTML page raises [`NotAModelFileError`](@ref)
(see [`check_model_file`](@ref)), and a file whose SHA-256 differs from the manifest
raises [`ChecksumMismatchError`](@ref).
"""
function import_model(name, path::AbstractString)
    spec = model_info(name)
    is_reconstruction(spec) &&
        throw(ReconstructionOnlyError(spec.name, spec.source_url, spec.licence))
    is_builtin(spec) && throw(NoModelFileError(spec.name))
    check_model_file(spec, path)
    _verify_checksum(spec, path)
    is_verbatim(spec) && return model_path(spec)
    dest = cached_path(spec)
    mkpath(dirname(dest))
    cp(path, dest; force=true)
    return dest
end

"""
    clear_cache(; name=nothing)

Delete every cached model file under [`cache_dir`](@ref), or only the cache entry of
model `name`. This removes files the user downloaded: call it inside
[`with_cache_dir`](@ref) (as the test suite does) whenever the real cache must be left
alone.
"""
function clear_cache(; name=nothing)
    if name === nothing
        dir = cache_dir()
        for entry in readdir(dir)
            rm(joinpath(dir, entry); recursive=true, force=true)
        end
    else
        spec = model_info(name)
        rm(joinpath(cache_dir(), spec.name); recursive=true, force=true)
    end
    return nothing
end

"""
    verify_checksums(; include_cache=false, verbose=false, collect_mismatches=false)

Recompute the SHA-256 of every committed model file (and, with `include_cache = true`,
of every cached fetch-only file) and compare it with the manifest.

By default the first bad file stops the run with a [`ChecksumMismatchError`](@ref) and
the names of the models checked are returned as a `Vector{String}`. With
`collect_mismatches = true` every file is checked and the result is the named tuple
`(checked, mismatches)`, `mismatches` holding one `ChecksumMismatchError` per bad file,
so that a zoo-wide audit reports all of them in a single pass.

```julia
result = verify_checksums(; include_cache = true, collect_mismatches = true)
isempty(result.mismatches) || foreach(e -> println(sprint(showerror, e)), result.mismatches)
```
"""
function verify_checksums(; include_cache::Bool=false, verbose::Bool=false,
                          collect_mismatches::Bool=false)
    checked = String[]
    mismatches = ChecksumMismatchError[]
    for spec in MODEL_SPECS
        if is_verbatim(spec)
            path = model_path(spec)
        elseif include_cache && is_fetch_only(spec) && isfile(cached_path(spec))
            path = cached_path(spec)
        else
            continue
        end
        if collect_mismatches
            try
                actual = _verify_checksum(spec, path)
                verbose && println(rpad(spec.name, 30), " ", actual, " ok")
            catch e
                e isa ChecksumMismatchError || rethrow()
                push!(mismatches, e)
                verbose && println(rpad(spec.name, 30), " ", e.actual, " MISMATCH")
            end
        else
            actual = _verify_checksum(spec, path)
            verbose && println(rpad(spec.name, 30), " ", actual, " ok")
        end
        push!(checked, spec.name)
    end
    return collect_mismatches ? (; checked, mismatches) : checked
end

"""
    licence_text(name) -> Union{String,Nothing}

The `LICENSE.txt` shipped next to a verbatim model, or `nothing` when there is none.

Verbatim models carry the licence of the collection they came from -- the Bayesian
Network Model Archive [BNMA](@cite), the bnlearn repository of
[Scutari2010](@cite), the bnRep collection of [Leonelli2025](@cite), or a paper's
supplementary material -- and that text is what is reproduced here. A model whose
licence forbids redistribution is fetch-only and never committed, so `licence_text`
returns `nothing` for it; its terms are in the manifest and at its `source_url`.
"""
function licence_text(name)
    spec = model_info(name)
    path = joinpath(model_dir(spec), "LICENSE.txt")
    return isfile(path) ? read(path, String) : nothing
end
