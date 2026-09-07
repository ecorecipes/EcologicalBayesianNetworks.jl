# EcologicalBayesianNetworks.jl

A curated zoo of downloadable ecological Bayesian belief networks and influence
diagrams, with reference models and ecological vignettes.

```julia
using EcologicalBayesianNetworks
using InfluenceDiagrams: optimize
model_catalog()                      # every model, as a table
m = load_model("water")              # a BayesianNetworks.BayesModel
id = load_model("koalas")            # an InfluenceDiagrams.InfluenceDiagramModel
optimize(id).expected_utility        # 20.2
g = reference_grazing_id()           # the SPEC section 46 reference influence diagram
fetch_model("tidal_saline_wetlands") # fetch-only models go to a scratch cache
```

Models with decision or utility nodes load as influence diagrams, ready for
`expected_utility`, `optimize` (decision variable elimination or exhaustive search) and
`expected_value_of_information`; chance-only models load as Bayesian networks for
`marginal`, `observe`, `do_intervention` and the inference backends of
BayesianNetworkInference.jl.

Each model lives in `models/<name>/metadata.toml` with its source, citation, licence
and SHA-256. Files are committed verbatim only under CC BY, CC BY-SA, CC0 or MIT
licences; everything else is fetched on demand and never redistributed or converted, and
a few catalogue entries record data or code archives (`format = "package"`) from which a
network can be rebuilt but which are not network files themselves. The policy is in
`docs/adr/0008-model-zoo-licence-policy.md` and summarised in `models/README.md`.

The fetch cache is not the user's to lose: `cache_dir()` follows an enclosing
`with_cache_dir(f, dir)` block, then `ENV["ECOLOGICAL_BN_CACHE"]`, then the package's
Scratch.jl space, so a test suite or a rendered document can be pointed somewhere
temporary before it fetches, imports or clears anything.

## References

Bayesian belief networks have been a standard tool of habitat, conservation and
natural-resource modelling since [McCannMarcotEllis2006](@cite),
[Marcot2006](@cite) and [Newton2007](@cite); [Uusitalo2007](@cite),
[Landuyt2013](@cite) and [Death2015](@cite) set out what they do and do not deliver, and
[Kuhnert2010](@cite) how the tables are elicited. [ChenPollino2012](@cite) is the
good-practice checklist and [Marcot2012](@cite) the evaluation metrics.
Environmental risk assessment is surveyed by [Moe2021](@cite) and
[Kaikkonen2021](@cite); value of information for adaptive management by
[Runge2011](@cite). The collections the models come from are the Bayesian Network Model
Archive [BNMA](@cite), the bnlearn repository [Scutari2010](@cite) and bnRep
[Leonelli2025](@cite); vignette 5 uses the Song Sparrow network of
[Kotalik2026](@cite). Full entries are on the [References](references.md) page.

See the Tutorials section for rendered vignettes and the API Reference for docstrings.
