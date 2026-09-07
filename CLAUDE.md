# EcologicalBayesianNetworks.jl

A curated zoo of downloadable ecological Bayesian belief networks and influence diagrams, with reference models and ecological vignettes.

## Place in the ecosystem

Dependency order (arrows = depends on):
EcologicalBayesianNetworks → InfluenceDiagrams → BayesianNetworkInference → BayesianNetworks →
FiniteKernels,
and BayesianNetworks → BayesianNetworkFormats (a Catlab-free leaf).
This package depends on all five siblings. `load_model` returns a `BayesModel` for chance-only
models and an `InfluenceDiagrams.InfluenceDiagramModel` for models with decision or utility nodes
(`InfluenceDiagramModel(::NetworkIR)`); `model_ir` returns the `NetworkIR` of either.
Sibling packages are expected at `../<Name>.jl` (see `[sources]` in Project.toml, and the same in
`vignettes/Project.toml` and `docs/Project.toml`); CI checks out all five.

## Layout

- `models/<name>/metadata.toml` is the source of truth; `src/registry.jl` reads every manifest at
  precompile time into `MODEL_SPECS` (with `include_dependency`, so editing a manifest recompiles).
  `models/README.md` documents the keys and the licence policy.
- `src/cache.jl`: the model cache, `fetch_model` / `import_model` / `verify_checksums`.
  `cache_dir()` is overridable: an enclosing `with_cache_dir(f, dir)` first, then
  `ENV["ECOLOGICAL_BN_CACHE"]`, then the Scratch.jl space. The whole test suite runs
  inside `with_cache_dir(mktempdir())` and checks afterwards that the default scratch
  space is untouched; a vignette must never call `clear_cache`, `fetch_model` or
  `import_model` outside such a block.
- `src/loading.jl`: `model_ir` (gunzips `.gz` in memory, applies `[parser_options]`), `load_model`,
  `model_summary`. `src/reference/`: Julia-built reference models (`reference_habitat_model` from
  BayesianNetworks, `reference_grazing_id` = `InfluenceDiagrams.reference_grazing_model`).
- Netica finding/equation nodes (Song Sparrow, Brown Trout) have no CPT: the manifest sets
  `allow_missing_tables = true`, the model loads with those mechanisms unbound
  (`missing_kernels`) and `optimize` / `validate(; semantics = true)` raise `MissingKernelError`.
  Do not invent kernels for them in tests or vignettes.
- `vignettes/`: 01 zoo tour, 02 reference habitat BN (SPEC 45), 03 management ID (SPEC 46
  analyses 1-5), 04 intervention vs implementation (SPEC 42), 05 Song Sparrow / Waterhole Fence /
  Koalas, 06 scenarios on `water`, 07 dynamic models and roadmap.
- `scripts/`: `fetch_all.jl`, `verify_checksums.jl`, `add_model.jl`, `update_readme_table.jl`,
  `sync_vignettes.jl`, `run_network_tests.jl` (the suite with `ECOLOGICAL_BN_FETCH` and
  `ECOLOGICAL_BN_SLOW` both set; the offline run covers neither branch).
- The two optional gates are read by `zoo_env_flag` in `test/runtests.jl`, which prints
  the variable name of every gate it skips. `scripts/update_readme_table.jl --check` runs
  as a test (`test/scripts.jl`), so the README catalogue cannot drift.

## Invariants that must not be broken

- Licence policy (ADR 0008): verbatim files only for CC BY / CC BY-SA / CC0 / MIT, always with
  `LICENSE.txt`; ND, NC and unstated licences are fetch-only; converted derivatives are never
  committed. The test is an explicit allow-list plus an ND/NC clause check
  (`licence_permits_redistribution` in `test/registry.jl`), never a substring match: `"CC BY-ND"`
  contains `"CC BY"`.
- Tests and vignettes never touch the user's real model cache (see `src/cache.jl` above).
- A committed file is byte-identical to the download its `sha256` was taken from (only the file name
  may change). `verify_checksums()` is part of the test suite.
- Structural syntax (ACSets) and numerical semantics (kernels, utilities) stay separate; CPT arrays are never ACSet attributes.
- Parent / input order is explicit (`input_position`) and total. Never rely on part-id order.
- Axis conventions: user-facing CPTs are `(parents..., child)` normalised over the last axis; FinStoch kernels internally are outputs-first. Convert with the documented `permutedims`, never by hand.
- Observation (`observe`) and intervention (`do_intervention`) are different operations and stay different.
- Every optimised path is checked against a slower oracle (`joint_distribution`, exhaustive policy search) on small models.

## Commands

```sh
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.test()'   # the test suite (no network)
ECOLOGICAL_BN_SLOW=true julia --project -e 'using Pkg; Pkg.test()'   # also build+validate barley, mildew
ECOLOGICAL_BN_FETCH=true julia --project -e 'using Pkg; Pkg.test()'  # also the network fetch tests
julia --project scripts/run_network_tests.jl                      # both gates open (FETCH + SLOW)
julia --project scripts/fetch_all.jl                              # fill the scratch cache
julia --project scripts/add_model.jl models/<name> [file]         # fill derived manifest fields
julia --project scripts/update_readme_table.jl [--check]          # README catalogue table
julia --project=docs docs/make.jl                                 # build docs locally
cd vignettes && quarto render                                     # render vignettes to html/gfm/pdf (julia engine; PDF needs lualatex + ../fonts/JuliaMono)
julia scripts/sync_vignettes.jl [--check]                         # copy vignettes into docs/src/tutorials
```

## Files not to edit by hand

- `docs/src/tutorials/` is generated by `scripts/sync_vignettes.jl`.
- `vignettes/*/*.md`, `*.html`, `*.pdf` and `*_files/` are quarto output; edit the `.qmd`.
- The catalogue table in `README.md` between the `catalogue:begin/end` markers.
- `models/*/<file>`: never modify a committed model file.

## Style

JuliaFormatter `yas`; docstrings on every exported name; typed exceptions with variable names in the message;
no emojis in code or docs.
