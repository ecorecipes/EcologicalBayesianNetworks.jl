# Recompute the SHA-256 of every committed model file (and of cached fetch-only files
# with --cache) and compare with the manifests. Every file is checked and every mismatch
# reported; exits 1 when there is at least one.
#
#   julia --project scripts/verify_checksums.jl [--cache]
using EcologicalBayesianNetworks

result = verify_checksums(; include_cache="--cache" in ARGS, verbose=true,
                          collect_mismatches=true)
println(length(result.checked), " file(s) verified")
if !isempty(result.mismatches)
    println(length(result.mismatches), " mismatch(es):")
    for e in result.mismatches
        println("  ", sprint(showerror, e))
    end
    exit(1)
end
