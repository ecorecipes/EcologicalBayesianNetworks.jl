# API Reference

```@docs
EcologicalBayesianNetworks
```

## Registry

```@docs
ModelSpec
ModelCatalog
MODEL_SPECS
MODELS_DIR
MODEL_CATEGORY_ORDER
model_info
model_catalog
available_models
model_categories
n_models
catalog_table
read_manifest
load_model_specs
model_dir
is_verbatim
is_fetch_only
is_builtin
is_reconstruction
is_redistributable
is_influence_diagram
```

## Cache, fetching and checksums

```@docs
cache_dir
with_cache_dir
CACHE_ENV_VAR
model_path
cached_path
fetch_model
import_model
is_available
is_fetchable
fetchable_models
clear_cache
verify_checksums
sha256_file
licence_text
```

## Loading

```@docs
model_ir
load_model
model_summary
ModelSummary
read_model_file
```

## Reference models

```@docs
reference_grazing_id
```

`reference_habitat_bn` and `reference_habitat_model` are re-exported from
BayesianNetworks.jl; `reference_grazing_id` returns
`InfluenceDiagrams.reference_grazing_model()`. `NetworkIR`, `BayesModel`,
`InfluenceDiagramModel`, `read_network` and `has_decisions` are re-exported from the
siblings for use in the vignettes.

## Errors

Every exception the zoo introduces subtypes `ZooError`, which subtypes BayesianNetworks.jl's
`BayesNetError` (ADR 0013). Errors of the lower packages pass through unchanged, notably
BayesianNetworkFormats.jl's reader errors from `load_model` and `model_ir`. The roots
`BayesNetError`, `BayesianNetworkFormatsError` and the union `AnyBayesNetError`, and every
exception type BayesianNetworkFormats.jl exports (`ParseError`, `ValidationError`,
`NotNormalizedError`, ...), are re-exported; they are documented in their own packages'
API references.

```@docs
ZooError
UnknownModelError
InvalidManifestError
ModelNotFetchedError
NoDownloadURLError
ChecksumMismatchError
NotAModelFileError
NoModelFileError
FetchError
ReconstructionOnlyError
```

## Everything else

```@autodocs
Modules = [EcologicalBayesianNetworks]
Filter = t -> !(t in (ModelSpec, ModelCatalog, ModelSummary))
Public = false
Private = true
```
