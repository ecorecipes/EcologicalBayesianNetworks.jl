# The exception hierarchy of ADR 0013: ZooError sits under BayesianNetworks' BayesNetError, and
# the roots and every exception type BayesianNetworkFormats exports are re-exported as the same
# bindings.
function exported_exception_names(M)
    return filter(names(M)) do n
        T = getglobal(M, n)
        return T isa Type && T <: Exception
    end
end

@testset "errors" begin
    @test ZooError <: BayesianNetworks.BayesNetError
    @test ZooError <: AnyBayesNetError
    @test_throws UnknownModelError load_model("no-such-model")
    @test_throws AnyBayesNetError load_model("no-such-model")
    exported = names(EcologicalBayesianNetworks)
    for n in (:BayesNetError, :AnyBayesNetError, :BayesianNetworkFormatsError)
        @test n in exported
    end
    fmt = exported_exception_names(BayesianNetworkFormats)
    @test issubset([:ParseError, :ValidationError, :NotNormalizedError], fmt)
    for n in fmt
        @test n in exported
        @test getglobal(EcologicalBayesianNetworks, n) ===
              getglobal(BayesianNetworkFormats, n)
    end
end
