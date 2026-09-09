using Test
using EcologicalBayesianNetworks
using BayesianNetworkFormats: BayesianNetworkFormats, NetworkIR, ChanceNode, DecisionNode,
                              UtilityNode, ParseError, ValidationError
using BayesianNetworks: BayesianNetworks, BayesModel, marginal, validate, syntax,
                        variable_names, probability, missing_kernels, MissingKernelError,
                        UnnormalizedKernelError
using InfluenceDiagrams: InfluenceDiagrams, InfluenceDiagramModel, optimize,
                         DecisionVariableElimination, ExhaustivePolicySearch,
                         expected_utility, policy_table, IncompleteStrategyError, nparts
using SHA: sha256

const E = EcologicalBayesianNetworks

"""
    zoo_env_flag(name) -> Bool

`true` when the environment variable `name` is set to `true` (or `1` / `yes`, in any
case). The optional parts of the suite are gated one flag per resource they need:

- `ECOLOGICAL_BN_SLOW` — the minute-scale builds (`barley`, `mildew`).
- `ECOLOGICAL_BN_FETCH` — everything that needs the network (`test/fetch.jl`).

`julia --project scripts/run_network_tests.jl` sets both and runs the suite.
"""
function zoo_env_flag(name::AbstractString)
    return lowercase(strip(get(ENV, name, "false"))) in ("true", "1", "yes")
end

const SLOW_VAR = "ECOLOGICAL_BN_SLOW"
const FETCH_VAR = "ECOLOGICAL_BN_FETCH"
const SLOW = zoo_env_flag(SLOW_VAR)
const FETCH = zoo_env_flag(FETCH_VAR)

SLOW || @info "skipping the slow model builds; set $(SLOW_VAR)=true to run them"
FETCH ||
    @info "skipping the network tests in test/fetch.jl; set $(FETCH_VAR)=true to run them (or use scripts/run_network_tests.jl)"

# The suite fetches, imports and clears cache entries, so it must never run against the
# user's real cache: `with_cache_dir` points `cache_dir()` at a temporary directory for
# the whole run and the default scratch space is checked to be untouched at the end.
function _tree_snapshot(dir)
    isdir(dir) || return String[]
    entries = String[]
    for (root, dirs, files) in walkdir(dir), f in vcat(dirs, files)
        push!(entries, relpath(joinpath(root, f), dir))
    end
    return sort!(entries)
end

const DEFAULT_CACHE = cache_dir()
const DEFAULT_CACHE_BEFORE = _tree_snapshot(DEFAULT_CACHE)
const SCRATCH_CACHE = withenv(E.CACHE_ENV_VAR => nothing) do
    return cache_dir()
end
const SCRATCH_CACHE_BEFORE = _tree_snapshot(SCRATCH_CACHE)

mktempdir() do cache_root
    with_cache_dir(cache_root) do
        @testset "EcologicalBayesianNetworks" begin
            @testset "the suite runs against a temporary cache" begin
                @test cache_dir() == abspath(cache_root)
                @test cache_dir() != DEFAULT_CACHE
            end
            include("registry.jl")
            include("cache.jl")
            include("loading.jl")
            include("reference.jl")
            include("scripts.jl")
            FETCH && include("fetch.jl")
        end
    end
end

@testset "the default cache is untouched" begin
    @test cache_dir() == DEFAULT_CACHE
    @test _tree_snapshot(DEFAULT_CACHE) == DEFAULT_CACHE_BEFORE
    @test _tree_snapshot(SCRATCH_CACHE) == SCRATCH_CACHE_BEFORE
end
