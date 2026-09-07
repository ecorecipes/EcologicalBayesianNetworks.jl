# A tour of the model zoo
Simon Frost

- [Overview](#overview)
- [Setup](#setup)
- [The catalogue](#the-catalogue)
- [Licences and redistribution](#licences-and-redistribution)
- [Loading a benchmark network](#loading-a-benchmark-network)
- [A marginal on a small network](#a-marginal-on-a-small-network)
- [The fetch-only workflow](#the-fetch-only-workflow)
- [Reference models](#reference-models)
- [Summary](#summary)
- [References](#references)

## Overview

`EcologicalBayesianNetworks.jl` is a curated zoo of publicly
downloadable ecological Bayesian belief networks and influence diagrams.
Every model has a manifest (`models/<name>/metadata.toml`) recording
where it came from, how to cite it, its licence and a checksum; models
with permissive licences (CC BY, CC BY-SA, CC0, MIT) ship with the
package verbatim, and the rest are fetched into a local cache on demand.
This vignette walks through the catalogue, loads a benchmark network,
solves a decision model, and computes a marginal on a small chance-only
network.

The models are real ones: belief networks published for habitat,
conservation and natural-resource problems ([McCann et al.
2006](#ref-McCannMarcotEllis2006); [Newton et al.
2007](#ref-Newton2007)), environmental risk assessments ([Moe et al.
2021](#ref-Moe2021); [Kaikkonen et al. 2021](#ref-Kaikkonen2021)) and
ecosystem-service models ([Landuyt et al. 2013](#ref-Landuyt2013)). They
come from four kinds of source – the Bayesian Network Model Archive
([BNMA 2026](#ref-BNMA)), the bnlearn network repository ([Scutari
2010](#ref-Scutari2010)), the bnRep collection ([Leonelli
2025](#ref-Leonelli2025)), and the supplementary material of individual
papers – and each brings its own licence, which is why the zoo enforces
a redistribution policy rather than mirroring everything.

## Setup

``` julia
using EcologicalBayesianNetworks
n_models()
```

    41

## The catalogue

`model_catalog()` returns a filtered view of the registry that prints as
a table. The `kind` column says whether a model is a plain Bayesian
network (`BN`), has decision or utility nodes (`ID`, an influence
diagram), or is a `package`: a catalogue record for a Dryad, Zenodo,
figshare or source-repository archive from which a network can be
rebuilt but which is not itself a network file.

``` julia
model_catalog()
```

    ModelCatalog with 41 models
    name                             category     format   licence                                                                       redistribution  nodes  arcs  kind   
    -------------------------------  -----------  -------  ----------------------------------------------------------------------------  --------------  -----  ----  -------
    reference_grazing_id             reference    julia    MIT                                                                           builtin         12     13    ID     
    reference_habitat_bn             reference    julia    MIT                                                                           builtin         7      6     BN     
    beach_mice_bn                    habitat      neta     CC0 1.0 (ScienceBase record); US Government work in the public domain         fetch-only      0      0     BN     
    brown_bear_recreation            habitat      dne      CC-BY-NC-ND (version unstated)                                                fetch-only      37     45    BN     
    gulf_sturgeon_bn                 habitat      neta     CC0 1.0 (ScienceBase record); US Government work in the public domain         fetch-only      0      0     BN     
    habitat_suitability_tiger        habitat      xdsl     CC-BY (version unstated)                                                      verbatim        11     12    BN     
    plexus_teb_bat_site              habitat      dne      unstated                                                                      fetch-only      13     15    BN     
    plexus_teb_bat_subwatershed      habitat      dne      unstated                                                                      fetch-only      7      6     BN     
    seagrass_dbn_package             habitat      package  Dryad record terms (consult the record; Dryad lists its content as reusable)  reconstruction  0      0     package
    thailand_vertebrate_bbn_package  habitat      package  figshare collection terms (consult the individual items)                      reconstruction  0      0     package
    bull_trout_food_web              population   dne      CC-BY-NC-ND (version unstated)                                                fetch-only      10     15    BN     
    marten_age                       population   dne      CC-BY (version unstated)                                                      verbatim        7      6     BN     
    marten_telomere                  population   dne      CC-BY-NC-ND (version unstated)                                                fetch-only      0      0     BN     
    native_fish_v1                   population   dne      CC-BY (version unstated)                                                      verbatim        7      8     BN     
    pacific_walrus                   population   dne      CC-BY-NC-ND (version unstated)                                                fetch-only      77     96    BN     
    plexus_population_viability      population   dne      unstated                                                                      fetch-only      11     13    ID     
    plexus_teb_bat_basin             population   dne      unstated                                                                      fetch-only      8      7     BN     
    polar_bear_stressor_i            population   dne      CC-BY-NC-ND (version unstated)                                                fetch-only      38     44    BN     
    polar_bear_stressor_ii           population   dne      CC-BY-NC-ND (version unstated)                                                fetch-only      49     53    BN     
    ballycanew_diffuse_p             water        xdsl     MIT                                                                           verbatim        4      2     BN     
    ballycanew_point_diffuse_p       water        xdsl     MIT                                                                           verbatim        12     8     BN     
    bnma_water                       water        dne      CC-BY-SA (version unstated)                                                   verbatim        32     66    BN     
    vansjo_seasonal_bn_package       water        package  unstated (repository states no licence; check the repository terms)           reconstruction  0      0     package
    shark_management_survey          risk         dne      CC-BY-NC (version unstated)                                                   fetch-only      26     54    BN     
    tidal_saline_wetlands            risk         dne      CC-BY-ND (version unstated)                                                   fetch-only      18     16    BN     
    arhopalus_flight_activity        biosecurity  dne      CC-BY-NC-ND (version unstated)                                                fetch-only      7      11    BN     
    fisram_freshwater_species        biosecurity  dne      CC-BY-ND (version unstated)                                                   fetch-only      20     23    BN     
    hylastes_flight_activity         biosecurity  dne      CC-BY-NC-ND (version unstated)                                                fetch-only      7      11    BN     
    hylurgus_flight_activity         biosecurity  dne      CC-BY-NC-ND (version unstated)                                                fetch-only      10     17    BN     
    microctonus_ng_risk              biosecurity  xdsl     CC-BY-NC-ND (version unstated)                                                fetch-only      45     51    BN     
    wild_pig_hsi_package             biosecurity  package  CC0 1.0                                                                       reconstruction  0      0     package
    brown_trout_bdn                  decision     dne      CC-BY (version unstated)                                                      verbatim        9      13    ID     
    koalas                           decision     dne      CC-BY (version unstated)                                                      verbatim        10     11    ID     
    song_sparrow_bdn                 decision     dne      CC-BY (version unstated)                                                      verbatim        12     15    ID     
    waterhole_fence                  decision     dne      CC-BY (version unstated)                                                      verbatim        10     12    ID     
    animals                          benchmark    dne      CC-BY-NC-ND (version unstated)                                                fetch-only      7      6     BN     
    barley                           benchmark    net      CC BY-SA 3.0                                                                  verbatim        48     84    BN     
    bnrep_package                    benchmark    package  MIT                                                                           reconstruction  0      0     package
    hailfinder                       benchmark    net      CC BY-SA 3.0                                                                  verbatim        56     66    BN     
    mildew                           benchmark    net      CC BY-SA 3.0                                                                  verbatim        35     46    BN     
    water                            benchmark    net      CC BY-SA 3.0                                                                  verbatim        32     66    BN     

Categories, in display order:

``` julia
model_categories()
```

    8-element Vector{String}:
     "reference"
     "habitat"
     "population"
     "water"
     "risk"
     "biosecurity"
     "decision"
     "benchmark"

Filters combine: the benchmark networks, or only the influence diagrams
whose files ship with the package.

``` julia
available_models(category = "benchmark")
```

    6-element Vector{String}:
     "animals"
     "barley"
     "bnrep_package"
     "hailfinder"
     "mildew"
     "water"

``` julia
available_models(kind = :id, redistributable = true)
```

    5-element Vector{String}:
     "brown_trout_bdn"
     "koalas"
     "reference_grazing_id"
     "song_sparrow_bdn"
     "waterhole_fence"

`model_info` looks a model up by name, title or file name, ignoring case
and punctuation, and returns its `ModelSpec`.

``` julia
model_info("Song Sparrow BDN")
```

    ModelSpec song_sparrow_bdn
      title              Song Sparrow riparian restoration decision network (SongSparrowBDN_v250804)
      category           decision
      tags               bird, riparian, restoration, mercury, decision network, BNMA
      format             dne
      file               SongSparrowBDN_v250804.dne
      licence            CC-BY (version unstated)
      redistribution     verbatim
      nodes / arcs       12 / 15
      kind               influence diagram
      source             https://bnma.co/bn/2893
      download           https://bnma.co/bnrepo/?slice=download&format=dne&bnId=2893
      doi                10.59381/ofwegrfqyo
      citation           Kotalik, C. J., Rowland, F. E., Marcot, B. G., Skrabis, K., Walters, D. M., Hinck, J. E., Clements, W., Richer, E. and Isanhart, J. (2026). Causal networks to inform decisions for ecological restoration. Environmental Management 76(7).
      retrieved          2026-09-06
      sha256             9be7fb3ba119d0f5c8a00509fe87d19827043b6ac26d7dce5b57c679c7181666
      parser options     allow_missing_tables = true, strict = true
      notes              Original .dne as served by the BNMA converter (BN DOI 10.59381/ofwegrfqyo); filename unchanged. Decision network with planting and soil-treatment decisions and utility nodes (8 chance, 2 decision, 2 utility nodes; 7 CONSTANT nodes excluded); load_model returns an InfluenceDiagramModel whose two table-less mechanisms stay unbound, so it cannot be optimised. Two chance nodes (RiparianPlantCost_infl_adj, Time) are Netica finding/equation nodes with evidence but no CPT, so the manifest sets allow_missing_tables = true and model_ir validates with BayesianNetworkFormats.validate(ir; allow_missing_tables = true).

## Licences and redistribution

The manifest `redistribution` field is the licence policy in one word:

- `verbatim`: the original file is committed next to a `LICENSE.txt`
  with the attribution (the CC BY-SA 3.0 benchmarks of bnlearn ([Scutari
  2010](#ref-Scutari2010)), the MIT-licensed Ballycanew phosphorus
  tools, the CC BY records of the BNMA repository ([BNMA
  2026](#ref-BNMA)), the CC BY networks collected in bnRep ([Leonelli
  2025](#ref-Leonelli2025)));
- `fetch-only`: metadata only. No-derivatives, non-commercial and
  unstated licences are never committed and never converted;
  `fetch_model` downloads them into a scratch cache when a direct URL
  exists, and `import_model` copies a file you downloaded by hand;
- `builtin`: built in Julia (the reference models of the SPEC);
- `reconstruction`: a data or code archive rather than a network.
  Nothing is committed and nothing is cached; `load_model` raises
  `ReconstructionOnlyError` pointing at the record.

``` julia
model_catalog(kind = :package)
```

    ModelCatalog with 5 models
    name                             category     format   licence                                                                       redistribution  nodes  arcs  kind   
    -------------------------------  -----------  -------  ----------------------------------------------------------------------------  --------------  -----  ----  -------
    seagrass_dbn_package             habitat      package  Dryad record terms (consult the record; Dryad lists its content as reusable)  reconstruction  0      0     package
    thailand_vertebrate_bbn_package  habitat      package  figshare collection terms (consult the individual items)                      reconstruction  0      0     package
    vansjo_seasonal_bn_package       water        package  unstated (repository states no licence; check the repository terms)           reconstruction  0      0     package
    wild_pig_hsi_package             biosecurity  package  CC0 1.0                                                                       reconstruction  0      0     package
    bnrep_package                    benchmark    package  MIT                                                                           reconstruction  0      0     package

``` julia
try
    load_model("bnrep_package")
catch e
    println(sprint(showerror, e))
end
```

    ReconstructionOnlyError: model "bnrep_package" is a catalogue record for a data or code archive, not a network file, so there is nothing to load. The archive is at https://github.com/manueleleonelli/bnRep. Licence: MIT. Rebuild the network from the archive yourself, then register it as a model of its own with import_model.

``` julia
model_catalog(redistributable = false)
```

    ModelCatalog with 25 models
    name                             category     format   licence                                                                       redistribution  nodes  arcs  kind   
    -------------------------------  -----------  -------  ----------------------------------------------------------------------------  --------------  -----  ----  -------
    beach_mice_bn                    habitat      neta     CC0 1.0 (ScienceBase record); US Government work in the public domain         fetch-only      0      0     BN     
    brown_bear_recreation            habitat      dne      CC-BY-NC-ND (version unstated)                                                fetch-only      37     45    BN     
    gulf_sturgeon_bn                 habitat      neta     CC0 1.0 (ScienceBase record); US Government work in the public domain         fetch-only      0      0     BN     
    plexus_teb_bat_site              habitat      dne      unstated                                                                      fetch-only      13     15    BN     
    plexus_teb_bat_subwatershed      habitat      dne      unstated                                                                      fetch-only      7      6     BN     
    seagrass_dbn_package             habitat      package  Dryad record terms (consult the record; Dryad lists its content as reusable)  reconstruction  0      0     package
    thailand_vertebrate_bbn_package  habitat      package  figshare collection terms (consult the individual items)                      reconstruction  0      0     package
    bull_trout_food_web              population   dne      CC-BY-NC-ND (version unstated)                                                fetch-only      10     15    BN     
    marten_telomere                  population   dne      CC-BY-NC-ND (version unstated)                                                fetch-only      0      0     BN     
    pacific_walrus                   population   dne      CC-BY-NC-ND (version unstated)                                                fetch-only      77     96    BN     
    plexus_population_viability      population   dne      unstated                                                                      fetch-only      11     13    ID     
    plexus_teb_bat_basin             population   dne      unstated                                                                      fetch-only      8      7     BN     
    polar_bear_stressor_i            population   dne      CC-BY-NC-ND (version unstated)                                                fetch-only      38     44    BN     
    polar_bear_stressor_ii           population   dne      CC-BY-NC-ND (version unstated)                                                fetch-only      49     53    BN     
    vansjo_seasonal_bn_package       water        package  unstated (repository states no licence; check the repository terms)           reconstruction  0      0     package
    shark_management_survey          risk         dne      CC-BY-NC (version unstated)                                                   fetch-only      26     54    BN     
    tidal_saline_wetlands            risk         dne      CC-BY-ND (version unstated)                                                   fetch-only      18     16    BN     
    arhopalus_flight_activity        biosecurity  dne      CC-BY-NC-ND (version unstated)                                                fetch-only      7      11    BN     
    fisram_freshwater_species        biosecurity  dne      CC-BY-ND (version unstated)                                                   fetch-only      20     23    BN     
    hylastes_flight_activity         biosecurity  dne      CC-BY-NC-ND (version unstated)                                                fetch-only      7      11    BN     
    hylurgus_flight_activity         biosecurity  dne      CC-BY-NC-ND (version unstated)                                                fetch-only      10     17    BN     
    microctonus_ng_risk              biosecurity  xdsl     CC-BY-NC-ND (version unstated)                                                fetch-only      45     51    BN     
    wild_pig_hsi_package             biosecurity  package  CC0 1.0                                                                       reconstruction  0      0     package
    animals                          benchmark    dne      CC-BY-NC-ND (version unstated)                                                fetch-only      7      6     BN     
    bnrep_package                    benchmark    package  MIT                                                                           reconstruction  0      0     package

Every verbatim model carries its licence text:

``` julia
print(licence_text("water"))
```

    This network file is redistributed verbatim from the bnlearn Bayesian Network
    Repository (https://www.bnlearn.com/bnrepository/), maintained by Marco Scutari,
    under the Creative Commons Attribution-Share Alike 3.0 Unported licence
    (CC BY-SA 3.0, https://creativecommons.org/licenses/by-sa/3.0/).

    Attribution: Marco Scutari, bnlearn Bayesian Network Repository.
    Scutari, M. (2010). Learning Bayesian Networks with the bnlearn R Package.
    Journal of Statistical Software, 35(3), 1-22. https://doi.org/10.18637/jss.v035.i03

    The file is unmodified. Derivative works must be distributed under the same
    licence.

## Loading a benchmark network

`water` (Jensen et al. 1989, from the bnlearn repository ([Scutari
2010](#ref-Scutari2010))) is stored gzipped exactly as served; the
loader decompresses it in memory, applies the manifest’s parser options
and hands the `NetworkIR` to `BayesianNetworks.BayesModel`.

``` julia
water = load_model("water")
```

    BayesModel(32 variables, 32 mechanisms, 32 kernels)

``` julia
using BayesianNetworks: validate
validate(water; semantics = true)
```

`model_summary` parses a model and counts what is in it without building
a `BayesModel`, so it also works for influence diagrams:

``` julia
model_summary("water")
```

    ModelSummary water (WATER: waste-water treatment plant control)
      format / licence     net / CC BY-SA 3.0 (verbatim)
      nodes                32 (32 chance, 0 decision, 0 utility)
      arcs                 66
      largest state space  4
      largest in-degree    5
      load_model           BayesModel

``` julia
model_summary("waterhole_fence")
```

    ModelSummary waterhole_fence (Waterhole Fence: fencing and plant survival decision network)
      format / licence     dne / CC-BY (version unstated) (verbatim)
      nodes                10 (6 chance, 1 decision, 3 utility)
      arcs                 12
      largest state space  3
      largest in-degree    3
      load_model           InfluenceDiagramModel

Decision models load as `InfluenceDiagrams.InfluenceDiagramModel`s, with
their chance kernels and tabular utilities bound and the decision nodes’
parents as information sets:

``` julia
koalas = load_model("koalas")
```

    InfluenceDiagramModel(6 variables, 2 decisions, 4 utilities, 4 kernels, 4 bound)

``` julia
using InfluenceDiagrams: optimize, policy_table
sol = optimize(koalas)
sol.expected_utility, policy_table(sol.strategy[:Cull]), policy_table(sol.strategy[:Relocate])
```

    (20.199999999999996, fill(:No), [:Yes, :Yes, :Yes])

The `NetworkIR` behind any model is one call away:

``` julia
[(v.id, v.kind, length(v.parents)) for v in model_ir("koalas").variables]
```

    10-element Vector{Tuple{Symbol, BayesianNetworkFormats.NodeKind, Int64}}:
     (:Cull, BayesianNetworkFormats.DecisionNode, 0)
     (:Relocate, BayesianNetworkFormats.DecisionNode, 1)
     (:KoalaPopulation, BayesianNetworkFormats.ChanceNode, 2)
     (:U, BayesianNetworkFormats.UtilityNode, 1)
     (:NveSocialImplications, BayesianNetworkFormats.ChanceNode, 2)
     (:V, BayesianNetworkFormats.UtilityNode, 1)
     (:TreeSpecies, BayesianNetworkFormats.ChanceNode, 1)
     (:Tourists, BayesianNetworkFormats.ChanceNode, 1)
     (:W, BayesianNetworkFormats.UtilityNode, 1)
     (:X, BayesianNetworkFormats.UtilityNode, 1)

## A marginal on a small network

`native_fish_v1` (Bayesian Intelligence, CC BY) links rainfall, drought,
pesticide use and river flow to native fish abundance. With seven nodes
the reference joint distribution is tiny, so `BayesianNetworks.marginal`
answers exactly.

``` julia
using BayesianNetworks: marginal, observe, probability
fish = load_model("native_fish_v1")
marginal(fish, :FishAbundance)
```

    FiniteKernel{Float64}(I → FishAbundance{High,Medium,Low})
                  ()
      High    0.2569
      Medium  0.2239
      Low     0.5193

Conditioning on a drought year:

``` julia
marginal(observe(fish, :Drought => :Yes), :FishAbundance)
```

    FiniteKernel{Float64}(I → FishAbundance{High,Medium,Low})
                  ()
      High    0.1288
      Medium  0.1756
      Low     0.6957

``` julia
[(s, round(probability(marginal(observe(fish, :Drought => :Yes), :FishAbundance), s); digits = 3))
 for s in (:High, :Medium, :Low)]
```

    3-element Vector{Tuple{Symbol, Float64}}:
     (:High, 0.129)
     (:Medium, 0.176)
     (:Low, 0.696)

## The fetch-only workflow

Fetch-only models have a `download_url` (when the host serves the file
directly) and `fetch_instructions` for the manual route. Nothing below
touches the network: the calls that would are shown, not run.

``` julia
spec = model_info("tidal_saline_wetlands")
(spec.licence, spec.redistribution, spec.download_url)
```

    ("CC-BY-ND (version unstated)", "fetch-only", "https://bnma.co/bnrepo/?slice=download&format=dne&bnId=209")

``` julia
println(spec.fetch_instructions)
```

    Open the BNMA export page (source_url with body=convert), choose 'Netica .dne format', press Save, and then import_model(name, path); or call fetch_model(name), which uses the same GET endpoint the Save button uses. The licence forbids redistribution of the file, so it is never committed.

Asking for the file before it is fetched raises a `ModelNotFetchedError`
whose message repeats the instructions. Rendering this vignette must not
disturb whatever you have already downloaded, so the demonstration runs
inside `with_cache_dir`, which points `cache_dir()` at a temporary
directory for the duration of the block (which is the directory the
error message names below):

``` julia
mktempdir() do tmp
    with_cache_dir(tmp) do
        try
            model_path("tidal_saline_wetlands")
        catch e
            println(sprint(showerror, e))
        end
    end
end
```

    ModelNotFetchedError: the file of model "tidal_saline_wetlands" is not in the cache (<temporary cache>). Run fetch_model("tidal_saline_wetlands") to download it from https://bnma.co/bnrepo/?slice=download&format=dne&bnId=209, or obtain it by hand and call import_model("tidal_saline_wetlands", path). Instructions: Open the BNMA export page (source_url with body=convert), choose 'Netica .dne format', press Save, and then import_model(name, path); or call fetch_model(name), which uses the same GET endpoint the Save button uses. The licence forbids redistribution of the file, so it is never committed.

`with_cache_dir` is the safe way to run anything that writes to or
clears the cache (`fetch_model`, `import_model`, `clear_cache`); setting
`ECOLOGICAL_BN_CACHE` does the same for a whole session. Nothing above
deleted a file, and nothing below does either: the two ways to make the
model available are shown, not run.

``` julia
fetch_model("tidal_saline_wetlands")            # direct download, checksum verified
import_model("tidal_saline_wetlands", "Tidal Saline Wetlands.dne")
clear_cache(name = "tidal_saline_wetlands")     # remove it again
```

After a fetch, `is_available("tidal_saline_wetlands")` is `true` and
`model_ir` reads the file from the cache (`cache_dir()`).
`verify_checksums(include_cache = true)` re-checks every committed and
cached file against the manifests, and
`verify_checksums(collect_mismatches = true)` reports every bad file
rather than stopping at the first.

``` julia
is_available("tidal_saline_wetlands"), length(fetchable_models())
```

    (false, 19)

## Reference models

Two models are built in Julia rather than read from files: the SPEC
section 45 habitat network (`reference_habitat_bn`, structure only, and
`reference_habitat_model`, with its conditional probability tables) and
the section 46 grazing-management influence diagram
(`reference_grazing_id`, an `InfluenceDiagramModel`). The following
vignettes work through both.

``` julia
habitat = load_model("reference_habitat_bn")
marginal(habitat, :Occupancy)
```

    FiniteKernel{Float64}(I → Occupancy{absent,present})
                   ()
      absent   0.5238
      present  0.4762

``` julia
reference_grazing_id()
```

    InfluenceDiagramModel(10 variables, 1 decision, 2 utilities, 9 kernels, 2 bound)

## Summary

The zoo is a registry of manifests: every model records its source,
citation, DOI, licence, checksum and retrieval date, and the
`redistribution` field decides whether the file is committed verbatim,
fetched into a scratch cache on demand, built in Julia, or carried as a
catalogue record only. That policy is what makes it safe to ship
published networks alongside the code, and `licence_text` reproduces the
terms next to every verbatim file. The next vignette, *The reference
habitat network*, works one model end to end.

## References

<div id="refs" class="references csl-bib-body hanging-indent">

<div id="ref-BNMA" class="csl-entry">

BNMA. 2026. *The Bayesian Network Model Archive*.
<https://bnma.co/bnrepo/>.

</div>

<div id="ref-Kaikkonen2021" class="csl-entry">

Kaikkonen, Laura, Tuuli Parviainen, Mika Rahikainen, Laura Uusitalo, and
Annukka Lehikoinen. 2021. “Bayesian Networks in Environmental Risk
Assessment: A Review.” *Integrated Environmental Assessment and
Management* 17 (1): 62–78. <https://doi.org/10.1002/ieam.4332>.

</div>

<div id="ref-Landuyt2013" class="csl-entry">

Landuyt, Dries, Steven Broekx, Rob D’hondt, Guy Engelen, Joris Aertsens,
and Peter L. M. Goethals. 2013. “A Review of Bayesian Belief Networks in
Ecosystem Service Modelling.” *Environmental Modelling & Software* 46:
1–11. <https://doi.org/10.1016/j.envsoft.2013.03.017>.

</div>

<div id="ref-Leonelli2025" class="csl-entry">

Leonelli, Manuele. 2025. *<span class="nocase">bnRep</span>: A
Repository of Bayesian Networks from the Academic Literature*.
<https://github.com/manueleleonelli/bnRep>.

</div>

<div id="ref-McCannMarcotEllis2006" class="csl-entry">

McCann, Robert K., Bruce G. Marcot, and Rick Ellis. 2006. “Bayesian
Belief Networks: Applications in Ecology and Natural Resource
Management.” *Canadian Journal of Forest Research* 36 (12): 3053–62.
<https://doi.org/10.1139/x06-238>.

</div>

<div id="ref-Moe2021" class="csl-entry">

Moe, S. Jannicke, John F. Carriger, and Miriam Glendell. 2021.
“Increased Use of Bayesian Network Models Has Improved Environmental
Risk Assessments.” *Integrated Environmental Assessment and Management*
17 (1): 53–61. <https://doi.org/10.1002/ieam.4369>.

</div>

<div id="ref-Newton2007" class="csl-entry">

Newton, Adrian C., Gavin B. Stewart, Anita Diaz, Duncan Golicher, and
Andrew S. Pullin. 2007. “Bayesian Belief Networks as a Tool for
Evidence-Based Conservation Management.” *Journal for Nature
Conservation* 15 (2): 144–60.
<https://doi.org/10.1016/j.jnc.2007.03.001>.

</div>

<div id="ref-Scutari2010" class="csl-entry">

Scutari, Marco. 2010. “Learning Bayesian Networks with the
<span class="nocase">bnlearn</span> R Package.” *Journal of Statistical
Software* 35 (3): 1–22. <https://doi.org/10.18637/jss.v035.i03>.

</div>

</div>
