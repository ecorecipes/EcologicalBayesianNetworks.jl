"""
    ZooError <: Exception

Abstract supertype of every exception raised by EcologicalBayesianNetworks.jl.
"""
abstract type ZooError <: Exception end

"""
    UnknownModelError(name)

Raised when `name` does not match any registered model, even after key normalisation
(case, spaces and punctuation are ignored) and after the aliases, titles and file names.
"""
struct UnknownModelError <: ZooError
    name::String
end
function Base.showerror(io::IO, e::UnknownModelError)
    return print(io, "UnknownModelError: no model named ", repr(e.name),
                 " in the zoo; see available_models() or model_catalog()")
end

"""
    InvalidManifestError(path, message)

Raised at load time when a `models/<name>/metadata.toml` is missing a required key or has
an invalid value.
"""
struct InvalidManifestError <: ZooError
    path::String
    message::String
end
function Base.showerror(io::IO, e::InvalidManifestError)
    return print(io, "InvalidManifestError: ", e.path, ": ", e.message)
end

"""
    ModelNotFetchedError(name, fetch_instructions, download_url)

Raised by [`model_path`](@ref) and [`model_ir`](@ref) for a fetch-only model whose file is
not in the cache. The message carries the manual instructions; `download_url` is empty when
no direct download exists.
"""
struct ModelNotFetchedError <: ZooError
    name::String
    fetch_instructions::String
    download_url::String
end
function Base.showerror(io::IO, e::ModelNotFetchedError)
    print(io, "ModelNotFetchedError: the file of model ", repr(e.name),
          " is not in the cache (", cache_dir(), ").")
    if isempty(e.download_url)
        print(io, " No direct download is available; ")
    else
        print(io, " Run fetch_model(", repr(e.name), ") to download it from ",
              e.download_url, ", or ")
    end
    print(io, "obtain it by hand and call import_model(", repr(e.name), ", path).")
    return isempty(e.fetch_instructions) ||
           print(io, " Instructions: ", e.fetch_instructions)
end

"""
    NoDownloadURLError(name, fetch_instructions)

Raised by [`fetch_model`](@ref) for a fetch-only model without a `download_url`.
"""
struct NoDownloadURLError <: ZooError
    name::String
    fetch_instructions::String
end
function Base.showerror(io::IO, e::NoDownloadURLError)
    print(io, "NoDownloadURLError: model ", repr(e.name),
          " has no direct download URL; obtain the file by hand and call import_model(",
          repr(e.name), ", path).")
    return isempty(e.fetch_instructions) ||
           print(io, " Instructions: ", e.fetch_instructions)
end

"""
    FetchError(name, url, cause)

Raised by [`fetch_model`](@ref) when the download itself fails: no network, an HTTP
status, a TLS failure. `cause` is the underlying exception (normally a
`Downloads.RequestError`), kept so that the transport detail is not lost.
"""
struct FetchError <: ZooError
    name::String
    url::String
    cause::Exception
end
function Base.showerror(io::IO, e::FetchError)
    print(io, "FetchError: could not download model ", repr(e.name), " from ", e.url,
          ": ", sprint(showerror, e.cause))
    return print(io,
                 ". Check the network and the source_url of the record; the file can also be obtained by hand and installed with import_model(",
                 repr(e.name), ", path).")
end

"""
    ChecksumMismatchError(name, path, expected, actual)

Raised when the SHA-256 of a downloaded, imported or committed file differs from the
manifest's `sha256`.
"""
struct ChecksumMismatchError <: ZooError
    name::String
    path::String
    expected::String
    actual::String
end
function Base.showerror(io::IO, e::ChecksumMismatchError)
    return print(io, "ChecksumMismatchError: model ", repr(e.name), " file ", e.path,
                 " has sha256 ", e.actual, " but the manifest records ", e.expected,
                 "; the upstream file may have changed (compare with the record at its source_url) or the download was corrupted")
end

"""
    NotAModelFileError(name, message)

Raised when a download or import is not a model file at all (no file at the path, an
empty file, an HTML error page) or when the file is binary Netica `.neta`, which cannot
be parsed.
"""
struct NotAModelFileError <: ZooError
    name::String
    message::String
end
function Base.showerror(io::IO, e::NotAModelFileError)
    return print(io, "NotAModelFileError: model ", repr(e.name), ": ", e.message)
end

"""
    ReconstructionOnlyError(name, source_url, licence)

Raised by [`model_path`](@ref), [`model_ir`](@ref) and [`load_model`](@ref) for a
catalogue record of a reconstruction package (`redistribution = "reconstruction"`): a
Dryad, Zenodo, figshare or source-repository archive of data or code from which a network
can be rebuilt, but which is not itself a network file.
"""
struct ReconstructionOnlyError <: ZooError
    name::String
    source_url::String
    licence::String
end
function Base.showerror(io::IO, e::ReconstructionOnlyError)
    print(io, "ReconstructionOnlyError: model ", repr(e.name),
          " is a catalogue record for a data or code archive, not a network file, so there is nothing to load.")
    isempty(e.source_url) || print(io, " The archive is at ", e.source_url, ".")
    isempty(e.licence) || print(io, " Licence: ", e.licence, ".")
    return print(io,
                 " Rebuild the network from the archive yourself, then register it as a model of its own with import_model.")
end

"""
    NoModelFileError(name)

Raised by [`model_path`](@ref) for a Julia-built model (`format = "julia"`), which has no
file.
"""
struct NoModelFileError <: ZooError
    name::String
end
function Base.showerror(io::IO, e::NoModelFileError)
    return print(io, "NoModelFileError: model ", repr(e.name),
                 " is built in Julia and has no file; use load_model or model_ir")
end
