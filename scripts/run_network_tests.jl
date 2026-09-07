# Run the full test suite with every optional gate open: the network fetch tests
# (test/fetch.jl) and the slow model builds (barley, mildew).
#
#   julia --project scripts/run_network_tests.jl
#
# `Pkg.test()` on its own runs neither, because both need a resource the default run must
# not assume: a working connection to bnma.co, plexuseco.com, bnlearn.com and
# sciencebase.gov for the first, and about a minute of CPU for the second. The gates are
# environment variables read by `zoo_env_flag` in test/runtests.jl:
#
#   ECOLOGICAL_BN_FETCH=true   test/fetch.jl: fetch_model's real download branch,
#                              import_model's copy branch, verify_checksums(include_cache
#                              = true), and a re-download of the verbatim files to check
#                              that the committed bytes still match upstream.
#   ECOLOGICAL_BN_SLOW=true    build and validate the barley and mildew benchmarks.
#
# The suite runs against a temporary cache (`with_cache_dir` in test/runtests.jl), so this
# downloads every fetchable model afresh and leaves the user's own cache untouched.
using Pkg

const VARS = ("ECOLOGICAL_BN_FETCH" => "true", "ECOLOGICAL_BN_SLOW" => "true")

for (k, v) in VARS
    println("setting ", k, "=", v)
    ENV[k] = v
end

Pkg.test(; test_args=ARGS)
