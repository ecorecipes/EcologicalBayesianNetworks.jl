# EcologicalBayesianNetworks.jl

[![Build Status](https://github.com/ecorecipes/EcologicalBayesianNetworks.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/ecorecipes/EcologicalBayesianNetworks.jl/actions/workflows/CI.yml)
[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://ecorecipes.github.io/EcologicalBayesianNetworks.jl/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A curated zoo of downloadable ecological Bayesian belief networks and influence diagrams,
with reference models and ecological vignettes.

Part of the ecorecipes compositional Bayesian-network ecosystem:
`FiniteKernels.jl` → `BayesianNetworks.jl` → `BayesianNetworkInference.jl` →
`InfluenceDiagrams.jl`,
with `BayesianNetworkFormats.jl` (file formats) and `EcologicalBayesianNetworks.jl` (model zoo).

## Features

- A registry of ecological models built from `models/<name>/metadata.toml` manifests
  (source, citation, DOI, licence, checksum, parser options), queried with
  `model_catalog`, `available_models` and `model_info`.
- Verbatim originals committed for permissively licensed models; a licence-aware
  cache (`fetch_model`, `import_model`, `verify_checksums`) for the rest, whose root is
  overridable with `with_cache_dir` or `ECOLOGICAL_BN_CACHE` so that tests and rendered
  vignettes never touch a user's downloads.
- Catalogue records (`format = "package"`) for the Dryad, Zenodo, figshare and
  source-repository archives from which a network can be reconstructed but which are not
  themselves network files.
- Loaders into the BayesianNetworkFormats.jl `NetworkIR` (`model_ir`, gunzipping on
  the fly), into BayesianNetworks.jl `BayesModel`s for chance-only models and into
  InfluenceDiagrams.jl `InfluenceDiagramModel`s for decision networks (`load_model`),
  with `model_summary` for a structural overview without building anything.
- The SPEC reference models built in Julia: the section 45 habitat network
  (`reference_habitat_bn`, `reference_habitat_model`) and the section 46
  grazing-management influence diagram (`reference_grazing_id`).
- Seven vignettes: the zoo tour, the reference habitat network end to end, the five
  section 46 decision analyses, direct intervention versus imperfect implementation
  (section 42), a real BNMA decision network, scenario analysis on the WATER
  benchmark, and dynamic models with the roadmap.

## Catalogue

The table is generated from the manifests by `scripts/update_readme_table.jl`.

<!-- catalogue:begin -->
| name                            | category    | format  | licence                                                                      | redistribution | nodes | arcs | kind    |
| ------------------------------- | ----------- | ------- | ---------------------------------------------------------------------------- | -------------- | ----- | ---- | ------- |
| reference_grazing_id            | reference   | julia   | MIT                                                                          | builtin        | 12    | 13   | ID      |
| reference_habitat_bn            | reference   | julia   | MIT                                                                          | builtin        | 7     | 6    | BN      |
| beach_mice_bn                   | habitat     | neta    | CC0 1.0 (ScienceBase record); US Government work in the public domain        | fetch-only     | 0     | 0    | BN      |
| brown_bear_recreation           | habitat     | dne     | CC-BY-NC-ND (version unstated)                                               | fetch-only     | 37    | 45   | BN      |
| gulf_sturgeon_bn                | habitat     | neta    | CC0 1.0 (ScienceBase record); US Government work in the public domain        | fetch-only     | 0     | 0    | BN      |
| habitat_suitability_tiger       | habitat     | xdsl    | CC-BY (version unstated)                                                     | verbatim       | 11    | 12   | BN      |
| plexus_teb_bat_site             | habitat     | dne     | unstated                                                                     | fetch-only     | 13    | 15   | BN      |
| plexus_teb_bat_subwatershed     | habitat     | dne     | unstated                                                                     | fetch-only     | 7     | 6    | BN      |
| seagrass_dbn_package            | habitat     | package | Dryad record terms (consult the record; Dryad lists its content as reusable) | reconstruction | 0     | 0    | package |
| thailand_vertebrate_bbn_package | habitat     | package | figshare collection terms (consult the individual items)                     | reconstruction | 0     | 0    | package |
| bull_trout_food_web             | population  | dne     | CC-BY-NC-ND (version unstated)                                               | fetch-only     | 10    | 15   | BN      |
| marten_age                      | population  | dne     | CC-BY (version unstated)                                                     | verbatim       | 7     | 6    | BN      |
| marten_telomere                 | population  | dne     | CC-BY-NC-ND (version unstated)                                               | fetch-only     | 0     | 0    | BN      |
| native_fish_v1                  | population  | dne     | CC-BY (version unstated)                                                     | verbatim       | 7     | 8    | BN      |
| pacific_walrus                  | population  | dne     | CC-BY-NC-ND (version unstated)                                               | fetch-only     | 77    | 96   | BN      |
| plexus_population_viability     | population  | dne     | unstated                                                                     | fetch-only     | 11    | 13   | ID      |
| plexus_teb_bat_basin            | population  | dne     | unstated                                                                     | fetch-only     | 8     | 7    | BN      |
| polar_bear_stressor_i           | population  | dne     | CC-BY-NC-ND (version unstated)                                               | fetch-only     | 38    | 44   | BN      |
| polar_bear_stressor_ii          | population  | dne     | CC-BY-NC-ND (version unstated)                                               | fetch-only     | 49    | 53   | BN      |
| ballycanew_diffuse_p            | water       | xdsl    | MIT                                                                          | verbatim       | 4     | 2    | BN      |
| ballycanew_point_diffuse_p      | water       | xdsl    | MIT                                                                          | verbatim       | 12    | 8    | BN      |
| bnma_water                      | water       | dne     | CC-BY-SA (version unstated)                                                  | verbatim       | 32    | 66   | BN      |
| vansjo_seasonal_bn_package      | water       | package | unstated (repository states no licence; check the repository terms)          | reconstruction | 0     | 0    | package |
| shark_management_survey         | risk        | dne     | CC-BY-NC (version unstated)                                                  | fetch-only     | 26    | 54   | BN      |
| tidal_saline_wetlands           | risk        | dne     | CC-BY-ND (version unstated)                                                  | fetch-only     | 18    | 16   | BN      |
| arhopalus_flight_activity       | biosecurity | dne     | CC-BY-NC-ND (version unstated)                                               | fetch-only     | 7     | 11   | BN      |
| fisram_freshwater_species       | biosecurity | dne     | CC-BY-ND (version unstated)                                                  | fetch-only     | 20    | 23   | BN      |
| hylastes_flight_activity        | biosecurity | dne     | CC-BY-NC-ND (version unstated)                                               | fetch-only     | 7     | 11   | BN      |
| hylurgus_flight_activity        | biosecurity | dne     | CC-BY-NC-ND (version unstated)                                               | fetch-only     | 10    | 17   | BN      |
| microctonus_ng_risk             | biosecurity | xdsl    | CC-BY-NC-ND (version unstated)                                               | fetch-only     | 45    | 51   | BN      |
| wild_pig_hsi_package            | biosecurity | package | CC0 1.0                                                                      | reconstruction | 0     | 0    | package |
| brown_trout_bdn                 | decision    | dne     | CC-BY (version unstated)                                                     | verbatim       | 9     | 13   | ID      |
| koalas                          | decision    | dne     | CC-BY (version unstated)                                                     | verbatim       | 10    | 11   | ID      |
| song_sparrow_bdn                | decision    | dne     | CC-BY (version unstated)                                                     | verbatim       | 12    | 15   | ID      |
| waterhole_fence                 | decision    | dne     | CC-BY (version unstated)                                                     | verbatim       | 10    | 12   | ID      |
| animals                         | benchmark   | dne     | CC-BY-NC-ND (version unstated)                                               | fetch-only     | 7     | 6    | BN      |
| barley                          | benchmark   | net     | CC BY-SA 3.0                                                                 | verbatim       | 48    | 84   | BN      |
| bnrep_package                   | benchmark   | package | MIT                                                                          | reconstruction | 0     | 0    | package |
| hailfinder                      | benchmark   | net     | CC BY-SA 3.0                                                                 | verbatim       | 56    | 66   | BN      |
| mildew                          | benchmark   | net     | CC BY-SA 3.0                                                                 | verbatim       | 35    | 46   | BN      |
| water                           | benchmark   | net     | CC BY-SA 3.0                                                                 | verbatim       | 32    | 66   | BN      |
<!-- catalogue:end -->

## Licence policy

Model files are committed verbatim only when the source states a licence that permits
redistribution (CC BY, CC BY-SA, CC0, MIT), each with a `LICENSE.txt` giving the
attribution. No-derivatives, non-commercial and unstated licences are metadata plus
fetch-only: `fetch_model(name)` downloads the file into a cache outside the repository
when a direct URL exists, and `import_model(name, path)` copies a file obtained by hand.
Converted derivatives are never committed. A licence is recorded in the manifest exactly
as the source states it, including the absence of a version; the interpretation lives in
the model's `LICENSE.txt`. The policy is recorded in
[`docs/adr/0008-model-zoo-licence-policy.md`](docs/adr/0008-model-zoo-licence-policy.md)
and summarised in [`models/README.md`](models/README.md); it is enforced by an explicit
allow-list plus an ND/NC clause check in the test suite, because `"CC BY-ND"` contains
`"CC BY"`.

## Installation

The ecosystem packages are not registered. Install this package and its ecosystem
dependencies by URL, in dependency order:

```julia
using Pkg
Pkg.add(url="https://github.com/ecorecipes/FiniteKernels.jl")
Pkg.add(url="https://github.com/ecorecipes/BayesianNetworkFormats.jl")
Pkg.add(url="https://github.com/ecorecipes/BayesianNetworks.jl")
Pkg.add(url="https://github.com/ecorecipes/BayesianNetworkInference.jl")
Pkg.add(url="https://github.com/ecorecipes/InfluenceDiagrams.jl")
Pkg.add(url="https://github.com/ecorecipes/EcologicalBayesianNetworks.jl")
```

Requires Julia ≥ 1.12.

## Quick Start

```julia
using EcologicalBayesianNetworks
using BayesianNetworks: marginal, observe, do_intervention
using InfluenceDiagrams: optimize, expected_utility, policy_table

model_catalog(category = "benchmark")
water = load_model("water")               # bnlearn's WATER, gunzipped on the fly
fish = load_model("native_fish_v1")       # a small CC BY network from BNMA
marginal(observe(fish, :Drought => :Yes), :FishAbundance)

model_summary("koalas")                   # 4 chance, 2 decision, 4 utility nodes
koalas = load_model("koalas")             # an InfluenceDiagramModel
sol = optimize(koalas)                    # decision variable elimination
sol.expected_utility                      # 20.2
policy_table(sol.strategy[:Relocate])     # [:Yes, :Yes, :Yes], indexed by Cull

g = reference_grazing_id()                # SPEC section 46 reference influence diagram
expected_utility(g, :GrazingManagement => :exclude)
optimize(do_intervention(g, :GrazingPressure => :low)).expected_utility

# Fetch-only records need the network and write into a cache outside the repository.
# `with_cache_dir` keeps that out of your real cache, which is what the tests do.
with_cache_dir(mktempdir()) do
    fetch_model("tidal_saline_wetlands")  # CC BY-ND: into the cache, never committed
end
```

Scripts: `scripts/fetch_all.jl` (fill the cache), `scripts/verify_checksums.jl`,
`scripts/add_model.jl models/<name> [file]` (fill derived manifest fields),
`scripts/update_readme_table.jl` (regenerates the table above; `--check` runs as a test),
`scripts/run_network_tests.jl` (the suite with the network and slow gates open).

## Vignettes

Rendered vignettes live in [`vignettes/`](vignettes/) and are published in the
[documentation](https://ecorecipes.github.io/EcologicalBayesianNetworks.jl/):

1. A tour of the model zoo
2. The reference habitat network (SPEC section 45)
3. The grazing-management influence diagram (the five analyses of SPEC section 46)
4. Direct intervention versus imperfect implementation (SPEC section 42)
5. A real decision network from the zoo (Song Sparrow, Waterhole Fence, Koalas)
6. Scenario analysis on the WATER benchmark
7. Dynamic models and the roadmap (SPEC sections 43, 44 and 47)
8. Held-out ecological prediction with Palmer penguins: training-only discretization,
   a temporal holdout and a prior baseline on pinned CC0 field observations

## References

The ecological Bayesian-network literature this zoo serves, and the collections the
models come from. The same entries, with the rest of the ecosystem's bibliography, are
in [`vignettes/references.bib`](vignettes/references.bib) and on the
[References page](https://ecorecipes.github.io/EcologicalBayesianNetworks.jl/references/)
of the documentation.

- McCann, R. K., Marcot, B. G. and Ellis, R. (2006). Bayesian belief networks:
  applications in ecology and natural resource management. *Canadian Journal of Forest
  Research* 36(12), 3053-3062.
  doi:[10.1139/x06-238](https://doi.org/10.1139/x06-238).
- Marcot, B. G., Steventon, J. D., Sutherland, G. D. and McCann, R. K. (2006).
  Guidelines for developing and updating Bayesian belief networks applied to ecological
  modeling and conservation. *Canadian Journal of Forest Research* 36(12), 3063-3074.
  doi:[10.1139/x06-135](https://doi.org/10.1139/x06-135) -- the life cycle the ecosystem
  follows.
- Chen, S. H. and Pollino, C. A. (2012). Good practice in Bayesian network modelling.
  *Environmental Modelling & Software* 37, 134-145.
  doi:[10.1016/j.envsoft.2012.03.016](https://doi.org/10.1016/j.envsoft.2012.03.016).
- Uusitalo, L. (2007). Advantages and challenges of Bayesian networks in environmental
  modelling. *Ecological Modelling* 203(3-4), 312-318.
  doi:[10.1016/j.ecolmodel.2006.11.018](https://doi.org/10.1016/j.ecolmodel.2006.11.018).
- Newton, A. C., Stewart, G. B., Diaz, A., Golicher, D. and Pullin, A. S. (2007).
  Bayesian Belief Networks as a tool for evidence-based conservation management.
  *Journal for Nature Conservation* 15(2), 144-160.
  doi:[10.1016/j.jnc.2007.03.001](https://doi.org/10.1016/j.jnc.2007.03.001).
- Kuhnert, P. M., Martin, T. G. and Griffiths, S. P. (2010). A guide to eliciting and
  using expert knowledge in Bayesian ecological models. *Ecology Letters* 13(7),
  900-914.
  doi:[10.1111/j.1461-0248.2010.01477.x](https://doi.org/10.1111/j.1461-0248.2010.01477.x).
- Landuyt, D., Broekx, S., D'hondt, R., Engelen, G., Aertsens, J. and Goethals, P. L. M.
  (2013). A review of Bayesian belief networks in ecosystem service modelling.
  *Environmental Modelling & Software* 46, 1-11.
  doi:[10.1016/j.envsoft.2013.03.017](https://doi.org/10.1016/j.envsoft.2013.03.017).
- Death, R. G., Death, F., Stubbington, R., Joy, M. K. and van den Belt, M. (2015). How
  good are Bayesian belief networks for environmental management? A test with data from
  an agricultural river catchment. *Freshwater Biology* 60(11), 2297-2309.
  doi:[10.1111/fwb.12655](https://doi.org/10.1111/fwb.12655) -- the sceptical case.
- Marcot, B. G. (2012). Metrics for evaluating performance and uncertainty of Bayesian
  network models. *Ecological Modelling* 230, 50-62.
  doi:[10.1016/j.ecolmodel.2012.01.013](https://doi.org/10.1016/j.ecolmodel.2012.01.013).
- Moe, S. J., Carriger, J. F. and Glendell, M. (2021). Increased use of Bayesian network
  models has improved environmental risk assessments. *Integrated Environmental
  Assessment and Management* 17(1), 53-61.
  doi:[10.1002/ieam.4369](https://doi.org/10.1002/ieam.4369); and Kaikkonen, L.,
  Parviainen, T., Rahikainen, M., Uusitalo, L. and Lehikoinen, A. (2021). Bayesian
  networks in environmental risk assessment: a review. *Ibid.* 17(1), 62-78.
  doi:[10.1002/ieam.4332](https://doi.org/10.1002/ieam.4332).
- Runge, M. C., Converse, S. J. and Lyons, J. E. (2011). Which uncertainty? Using expert
  elicitation and expected value of information to design an adaptive program.
  *Biological Conservation* 144(4), 1214-1223.
  doi:[10.1016/j.biocon.2010.12.020](https://doi.org/10.1016/j.biocon.2010.12.020).
- Kotalik, C. J., Rowland, F. E., Marcot, B. G. et al. (2026). Causal networks to inform
  decisions for ecological restoration. *Environmental Management* 76(7).
  doi:[10.59381/ofwegrfqyo](https://doi.org/10.59381/ofwegrfqyo) -- the Song Sparrow
  belief decision network of vignette 5.

Model collections: the Bayesian Network Model Archive (<https://bnma.co/bnrepo/>), the
bnlearn network repository of Scutari, M. (2010), Learning Bayesian networks with the
bnlearn R package, *Journal of Statistical Software* 35(3), 1-22,
doi:[10.18637/jss.v035.i03](https://doi.org/10.18637/jss.v035.i03)
(<https://www.bnlearn.com/bnrepository/>), and bnRep, Leonelli, M. (2025), a repository
of Bayesian networks from the academic literature
(<https://github.com/manueleleonelli/bnRep>). Every model's own citation, DOI and
licence is in its `models/<name>/metadata.toml`.
