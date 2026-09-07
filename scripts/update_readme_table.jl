# Regenerate the catalogue table in README.md between the two marker comments from the
# manifests, so the README never drifts from models/*/metadata.toml.
#
#   julia --project scripts/update_readme_table.jl [--check]
using EcologicalBayesianNetworks

const README = normpath(joinpath(@__DIR__, "..", "README.md"))
const BEGIN_MARK = "<!-- catalogue:begin -->"
const END_MARK = "<!-- catalogue:end -->"

table = sprint(io -> catalog_table(io, MODEL_SPECS; markdown=true))
block = string(BEGIN_MARK, "\n", table, END_MARK)

text = read(README, String)
i = findfirst(BEGIN_MARK, text)
j = findfirst(END_MARK, text)
(i === nothing || j === nothing) &&
    error("README.md must contain the markers $(BEGIN_MARK) and $(END_MARK)")
updated = text[1:(first(i) - 1)] * block * text[(last(j) + 1):end]
if "--check" in ARGS
    if updated == text
        println("README catalogue table is up to date")
    else
        println("README catalogue table is stale; run julia --project scripts/update_readme_table.jl")
        exit(1)
    end
else
    write(README, updated)
    println("README catalogue table updated (", n_models(), " models)")
end
