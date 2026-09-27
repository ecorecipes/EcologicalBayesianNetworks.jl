# Contributing to EcologicalBayesianNetworks.jl

## Local setup

The ecosystem packages depend on each other through `[sources]` entries that point at
sibling directories (`../OtherPackage.jl`). Clone every package you need side by side:

```sh
mkdir -p bbn && cd bbn
git clone https://github.com/ecorecipes/FiniteKernels.jl
git clone https://github.com/ecorecipes/MarkovCategories.jl        # vignettes only
git clone https://github.com/ecorecipes/CategoricalBayesianNetworks.jl   # vignettes only
git clone https://github.com/ecorecipes/BayesianNetworkFormats.jl
git clone https://github.com/ecorecipes/BayesianNetworks.jl
git clone https://github.com/ecorecipes/BayesianNetworkInference.jl
git clone https://github.com/ecorecipes/InfluenceDiagrams.jl
git clone https://github.com/ecorecipes/EcologicalBayesianNetworks.jl
cd EcologicalBayesianNetworks.jl
julia --project -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
```

`Pkg.test()` is the only run that counts as "the suite passes".

## The optional test gates

Two parts of the suite are gated on environment variables, because each needs a resource
the default run must not assume. `zoo_env_flag` in `test/runtests.jl` reads them and the
run prints which gate it skipped and how to open it.

| Variable | What it adds | Cost |
| --- | --- | --- |
| `ECOLOGICAL_BN_FETCH=true` | `test/fetch.jl`: the real download branch of `fetch_model`, the copy branch of `import_model`, `verify_checksums(include_cache = true)`, and a re-download of the verbatim files to confirm the committed bytes still match upstream | needs bnma.co, plexuseco.com, bnlearn.com and sciencebase.gov |
| `ECOLOGICAL_BN_SLOW=true` | building and validating the `barley` and `mildew` benchmarks | about a minute |

`julia --project scripts/run_network_tests.jl` sets both and runs the suite. Run it before
changing anything under `src/cache.jl`, `models/*/metadata.toml` or `scripts/`: those are
the paths the offline suite cannot cover. The gated tests run against a temporary cache
like the rest of the suite, so they download every fetchable model afresh and leave your
own cache alone.

## The model cache in tests and vignettes

`cache_dir()` is overridable, and nothing that a user runs may delete files they have
downloaded. The whole suite runs inside `with_cache_dir(mktempdir())` (`test/runtests.jl`)
and asserts at the end that the default Scratch.jl space is byte-for-byte as it was.
Never call `clear_cache()`, `fetch_model` or `import_model` from a test or a vignette
outside a `with_cache_dir` block; set `ECOLOGICAL_BN_CACHE` to point a whole session
somewhere else.

## Style

- Julia ≥ 1.12. Every dependency, including stdlibs and test-only extras, has a `[compat]` entry.
- Format with JuliaFormatter using the repository `.JuliaFormatter.toml` (`style = "yas"`).
- `snake_case` for functions and variables, `CamelCase` for types, a leading underscore for internal helpers.
- Public functions have docstrings with a signature line, a one-sentence summary, and an example where practical.
- Errors follow ADR 0013. Exceptions are typed, carry the offending variable / mechanism names, and live in
  `src/errors.jl`; library code never calls a bare `error("...")`. Each exception subtypes the nearest root:
  `FiniteKernelsError`, `BayesianNetworkFormatsError` or `BayesNetError` (a package with two or more types of its
  own adds an abstract type under it). Invalid arguments and keywords raise `ArgumentError`. A typed error from a
  lower package passes through unchanged, and the docstring of the function that raises it says so, unless this
  package wraps it to add information such as the variable. A docstring names another package's type as a code
  span, never with `@ref`.
- Every optimised code path is tested against a slower reference implementation on small models.

## Adding a vignette

1. Create `vignettes/NN_short_name/NN_short_name.qmd` with front matter including `engine: julia` and
   `pdf: default` under `format:` (copy an existing vignette's front matter).
2. Add any new dependencies to `vignettes/Project.toml`.
3. `cd vignettes && quarto render` renders HTML, GitHub-flavoured Markdown and PDF (the PDF needs
   `lualatex` and the JuliaMono font in `../fonts/JuliaMono/`; see `vignettes/README.md`). Commit the
   `.qmd`, the rendered `.md`, `.html` and `.pdf`, and `NN_short_name_files/`.
4. `julia scripts/sync_vignettes.jl` and commit `docs/src/tutorials/`.

The `Vignettes` workflow re-renders everything weekly and on demand; it is not a required check because
rendering is slow and depends on a Quarto installation. The `vignette-sync` job in CI is required.

## Architecture decision records

Significant design decisions are recorded in `docs/adr/NNNN-title.md` (context, decision, consequences).
Add a new record rather than editing an old one when a decision changes.

## Pull requests

Branch from `main`, keep PRs focused, and make sure CI is green (tests on Julia 1.12 and latest,
vignette sync check, docs build).
