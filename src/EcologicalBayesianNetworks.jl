"""
    EcologicalBayesianNetworks

A curated zoo of downloadable ecological Bayesian belief networks and influence
diagrams: a registry built from `models/*/metadata.toml`, a licence-aware cache
([`fetch_model`](@ref), [`import_model`](@ref)), loaders into the
BayesianNetworkFormats.jl `NetworkIR` ([`model_ir`](@ref)) and into
BayesianNetworks.jl `BayesModel`s and InfluenceDiagrams.jl `InfluenceDiagramModel`s
([`load_model`](@ref)), and the Julia-built reference models
([`reference_habitat_bn`](https://ecorecipes.github.io/BayesianNetworks.jl/api/#BayesianNetworks.reference_habitat_bn),
[`reference_grazing_id`](@ref)).

The zoo exists so that the compositional machinery can be exercised on published
ecological networks rather than on toys. Bayesian belief networks have been a standard
tool of habitat and conservation modelling since [McCannMarcotEllis2006](@cite) and
[Marcot2006](@cite), whose life-cycle guidelines (elicit, build, test, evaluate,
update) the ecosystem follows; [ChenPollino2012](@cite) sets out the good-practice
checklist a published network should satisfy, and [Uusitalo2007](@cite) the advantages
and the discretisation costs of using them in ecological modelling. Environmental risk
assessment is now a large part of that literature ([Moe2021](@cite);
[Kaikkonen2021](@cite)), and where the models carry decisions, the value of information
([Runge2011](@cite)) is what an adaptive-management programme is designed around.
Model quality is reported with the metrics of [Marcot2012](@cite).

Part of the ecorecipes compositional Bayesian-network ecosystem.
"""
module EcologicalBayesianNetworks

using TOML
using SHA: sha256
using Dates: Date, today
using Downloads: Downloads
using Scratch: @get_scratch!
using CodecZlib: GzipDecompressorStream
using BayesianNetworkFormats: BayesianNetworkFormats, NetworkIR, ChanceNode, DecisionNode,
                              UtilityNode,
                              read_network, detect_format, has_decisions, fixture_path
using BayesianNetworks: BayesianNetworks, BayesModel
using BayesianNetworkInference: BayesianNetworkInference
using InfluenceDiagrams: InfluenceDiagrams, InfluenceDiagramModel
using FiniteKernels: FiniteKernels

# errors.jl
export ZooError, UnknownModelError, InvalidManifestError, ModelNotFetchedError,
       NoDownloadURLError, ChecksumMismatchError, NotAModelFileError, NoModelFileError,
       FetchError, ReconstructionOnlyError
# registry.jl
export ModelSpec, ModelCatalog, MODEL_SPECS, MODELS_DIR, MODEL_CATEGORY_ORDER,
       model_info, model_catalog, available_models, model_categories, n_models,
       catalog_table, read_manifest, load_model_specs, model_dir, is_verbatim,
       is_fetch_only, is_builtin, is_reconstruction, is_redistributable,
       is_influence_diagram
# cache.jl
export cache_dir, with_cache_dir, CACHE_ENV_VAR, model_path, cached_path, fetch_model,
       import_model, is_available, is_fetchable, fetchable_models, clear_cache,
       verify_checksums, sha256_file, licence_text
# loading.jl
export model_ir, load_model, model_summary, ModelSummary, read_model_file
# reference models
export reference_habitat_bn, reference_habitat_model, reference_grazing_id
# Re-exported from the siblings for convenience in vignettes.
export NetworkIR, BayesModel, InfluenceDiagramModel, read_network, has_decisions

include("errors.jl")
include("registry.jl")
include("cache.jl")
include("loading.jl")
include("reference/habitat_bn.jl")
include("reference/grazing_id.jl")

end # module
