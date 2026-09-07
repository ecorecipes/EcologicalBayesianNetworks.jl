# The maintenance scripts that assert an invariant are run as tests: they are fast and
# offline, and the README's "generated from the manifests, so it never drifts" claim is
# only true if something checks it on every run.
@testset "scripts" begin
    root = normpath(joinpath(@__DIR__, ".."))

    @testset "README catalogue table is in sync with the manifests" begin
        script = joinpath(root, "scripts", "update_readme_table.jl")
        @test isfile(script)
        out = IOBuffer()
        cmd = `$(Base.julia_cmd()) --project=$(root) --startup-file=no $(script) --check`
        ok = success(pipeline(ignorestatus(cmd); stdout=out, stderr=out))
        text = String(take!(out))
        ok ||
            @info "scripts/update_readme_table.jl --check failed; run it without --check" output = text
        @test ok
        @test occursin("up to date", text)
    end
end
