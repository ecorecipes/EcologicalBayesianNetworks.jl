# Model zoo manifests

Every model known to `EcologicalBayesianNetworks.jl` has a directory here containing a
`metadata.toml` manifest and, when the licence allows it, the original model file and a
`LICENSE.txt`. The registry (`src/registry.jl`) reads every `*/metadata.toml` at
precompile time; there is no hand-maintained list.

## Licence policy

Recorded in `docs/adr/0008-model-zoo-licence-policy.md`, which is the authority; the
summary below is the working version:

- **Verbatim originals are committed only for permissive licences**: CC BY, CC BY-SA,
  CC0 and MIT. The check is an explicit allow-list of licence strings plus a rejection of
  anything carrying an ND or NC clause (`licence_permits_redistribution` in
  `test/registry.jl`); a substring match cannot do the job, because `"CC BY-ND"` contains
  `"CC BY"`. The file is stored byte-for-byte as downloaded (gzipped files stay
  gzipped) together with a `LICENSE.txt` carrying the attribution. Only the filename may
  differ (spaces replaced by underscores); the manifest `notes` say so.
- **No-derivatives (ND), non-commercial (NC) and unstated licences are metadata plus
  fetch-only**: the manifest records the source, a direct `download_url` where one exists,
  `fetch_instructions` for the manual route, and the `sha256` of a test download.
  `fetch_model(name)` or `import_model(name, path)` puts the file into a gitignored
  scratch cache; it is never committed.
- **Converted derivatives are never committed**, whatever the licence: the zoo stores
  what the authors published, and conversions happen in memory when a model is loaded.
- Julia-built reference models (`format = "julia"`) have no file; they are
  `redistribution = "builtin"` and MIT like the rest of the package.
- **Reconstruction packages** (`format = "package"`, `redistribution = "reconstruction"`)
  are catalogue records for data or code archives (Dryad, Zenodo, figshare, a source
  repository) from which a network can be rebuilt but which are not themselves network
  files. They carry the source URL, licence, citation and a note on what the archive
  holds; nothing is committed, nothing is cached, and `model_path`, `model_ir` and
  `load_model` raise `ReconstructionOnlyError`.
- **A licence is recorded as the source states it.** BNMA labels its records `CC-BY`,
  `CC-BY-SA`, `CC-BY-ND`, `CC-BY-NC` and `CC-BY-NC-ND` with no version, so the manifests
  say, for example, `licence = "CC-BY (version unstated)"`. The interpretation (which
  version of the licence text the file is treated under) lives in the model's
  `LICENSE.txt`, not in the manifest.

## Manifest keys

| Key | Meaning |
| --- | --- |
| `name` | directory name and registry key (`snake_case`) |
| `title` | one-line human title |
| `category` | one of `reference`, `habitat`, `population`, `water`, `risk`, `biosecurity`, `decision`, `benchmark` (the catalogue display order of `MODEL_CATEGORY_ORDER`) |
| `domain_tags` | free-text tags for searching |
| `format` | `dne`, `xdsl`, `net`, `bif`, `dsc`, `uai`, `neta` (fetch-only, binary), `julia` (built in code) or `package` (a reconstruction archive, not a network file) |
| `file` | committed file name relative to the directory; omitted for fetch-only and Julia models |
| `constructor` | Julia models only: the function in `EcologicalBayesianNetworks` that builds the model |
| `source_url` | landing page of the record |
| `download_url` | direct download used by `fetch_model`; `""` when only a manual route exists |
| `fetch_instructions` | how to obtain the file by hand (fetch-only models) |
| `citation`, `doi` | how to cite the model |
| `licence` | licence exactly as stated by the source, including the absence of a version (`unstated` when none is given); the interpretation belongs in `LICENSE.txt` |
| `redistribution` | `verbatim`, `fetch-only`, `builtin` or `reconstruction` |
| `has_decisions`, `has_utilities` | node kinds present (decision models load as `InfluenceDiagramModel`) |
| `n_nodes`, `n_arcs` | counts as parsed by BayesianNetworkFormats.jl (CONSTANT and skipped nodes excluded); `0` when unknown |
| `retrieved` | ISO date of the download the `sha256` refers to |
| `sha256` | checksum of the committed or test-downloaded file (`""` for Julia models) |
| `known_parse_issue` | optional: why the current reader cannot parse the file (empty for every current model; a value makes the test suite expect a `ParseError`) |
| `aliases` | extra lookup keys for `model_info`; BNMA models carry their record number (`model_info("BNMA 126")` finds `koalas`) |
| `notes` | free text |
| `[parser_options]` | keyword arguments applied by `model_ir`: `strict`, `atol` and `renormalize` go to `read_network`; `allow_missing_tables = true` lets `BayesianNetworkFormats.validate` accept chance nodes without a table (Netica finding and equation nodes with `evidence` but no `probs`; `model_summary` reports their number) |

The seven `renormalize = true` entries (`water`, `barley`, `mildew`,
`plexus_teb_bat_site`, `plexus_teb_bat_subwatershed`, `tidal_saline_wetlands` and
`waterhole_fence`) all work around the same thing: CPT rows that sum to one within the
readers' `atol = 1e-6` but not within the `1e-8` that `validate(m; semantics = true)`
uses by default. Note that this is a property of the *validation call*, not of the build:
passing `atol` to `BayesModel(ir; atol)` does not make a later `validate` accept the
model.

Six of them are chance-only models, and `BayesianNetworks.validate` has always taken an
`atol` keyword, so those could equally be handled by passing `atol = 1e-6` at every
`validate` call site; keeping the tolerance in the manifest keeps it out of every caller
and is the better place for it. The seventh, `waterhole_fence`, is an influence diagram,
and `InfluenceDiagrams.validate(::InfluenceDiagramModel)` had no `atol` to forward, so for
that one the manifest entry was the only option available. It now does take `atol`, so
`waterhole_fence` could drop the entry; it is kept for consistency with the other six.

## Adding a model

1. Check the licence against the allow-list in `docs/adr/0008-model-zoo-licence-policy.md`.
   Permissive: create `models/<name>/`, copy the original file in unchanged and write
   `LICENSE.txt`. Otherwise create the directory with the manifest only and put the file
   in the cache with `import_model`. For an archive that is not a network file at all, use
   `format = "package"` with `redistribution = "reconstruction"` and no file.
2. Write `metadata.toml` with every key above (`file` only for verbatim models).
3. Run `julia --project scripts/add_model.jl models/<name>` to fill `n_nodes`, `n_arcs`,
   `has_decisions`, `has_utilities`, `sha256` and `retrieved` from the file (or from the
   cache for fetch-only models).
4. Run `julia --project scripts/update_readme_table.jl` to regenerate the catalogue table
   in the top-level `README.md`, then `Pkg.test()` (which re-runs that script with
   `--check`) and `julia --project scripts/run_network_tests.jl` if the model is
   fetch-only.
