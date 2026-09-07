# Fetch every fetch-only model that has a direct download URL into the scratch cache.
#
#   julia --project scripts/fetch_all.jl [--force]
#
# Models without a download URL are listed with their manual fetch instructions.
using EcologicalBayesianNetworks

const FORCE = "--force" in ARGS

failures = String[]
for spec in MODEL_SPECS
    is_fetch_only(spec) || continue
    if isempty(spec.download_url)
        println(rpad(spec.name, 30), " manual: ", spec.fetch_instructions)
        continue
    end
    try
        path = fetch_model(spec.name; force=FORCE, verbose=false)
        println(rpad(spec.name, 30), " ok  ", path)
    catch e
        push!(failures, spec.name)
        println(rpad(spec.name, 30), " FAILED ", sprint(showerror, e))
    end
end
if isempty(failures)
    println("all fetchable models are in ", cache_dir())
else
    println(length(failures), " model(s) could not be fetched: ", join(failures, ", "))
    exit(1)
end
