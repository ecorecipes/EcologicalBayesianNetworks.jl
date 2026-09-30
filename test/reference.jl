@testset "reference models" begin
    bn = reference_habitat_bn()
    @test bn isa BayesianNetworks.BayesNet
    m = load_model("reference_habitat_bn")
    @test m isa BayesModel
    @test m == reference_habitat_model() || string(m) == string(reference_habitat_model())
    @test validate(m; semantics=true) === nothing
    @test isapprox(marginal(m, :Occupancy).table[2], 0.4762; atol=1e-4)
    ir = model_ir("reference_habitat_bn")
    @test ir isa NetworkIR
    @test length(ir.variables) == 7
    @test sum(length(v.parents) for v in ir.variables) == 6
    @test model_summary("reference_habitat_bn").loadable

    g = reference_grazing_id()
    @test g isa InfluenceDiagramModel
    @test g ≈ InfluenceDiagrams.reference_grazing_model()
    @test load_model("reference_grazing_id") ≈ g
    fixture = read_network(BayesianNetworkFormats.fixture_path("dne/grazing_reference_id.dne"))
    @test InfluenceDiagramModel(fixture) ≈ g
    gir = model_ir("reference_grazing_id")
    @test gir isa NetworkIR
    @test has_decisions(gir)
    @test count(v -> v.kind == DecisionNode, gir.variables) == 1
    @test count(v -> v.kind == UtilityNode, gir.variables) == 2
    @test length(gir.variables) == model_info("reference_grazing_id").n_nodes
    @test model_info("reference_grazing_id").n_arcs ==
          sum(length(v.parents) for v in gir.variables)
    @test isapprox(optimize(g).expected_utility, 36.5241; atol=1e-4)
    @test_throws NoModelFileError model_path("reference_grazing_id")
    @test is_builtin(model_info("reference_grazing_id"))
    @test model_info("reference_habitat_bn").constructor == "reference_habitat_model"

    # A manifest pointing at a missing constructor is caught at load time.
    bad = ModelSpec(; name="bad", title="t", category="reference", format="julia",
                    constructor="no_such_function", redistribution="builtin",
                    directory="bad")
    @test_throws InvalidManifestError E._constructor(bad)
    # One naming something that cannot build a model without arguments too (ADR 0015).
    notcallable = ModelSpec(; name="bad", title="t", category="reference", format="julia",
                            constructor="read_manifest", redistribution="builtin",
                            directory="bad")
    @test_throws InvalidManifestError E._constructor(notcallable)
end
