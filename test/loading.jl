const CHANCE_ONLY_VERBATIM = ["water", "habitat_suitability_tiger", "native_fish_v1",
                              "ballycanew_diffuse_p", "ballycanew_point_diffuse_p"]
const SLOW_BENCHMARKS = ["barley", "mildew"]

@testset "loading" begin
    @testset "every parseable verbatim model reads into a NetworkIR" begin
        for spec in MODEL_SPECS
            is_verbatim(spec) || continue
            # A recorded parse issue must be real; none of the current models has one.
            if !isempty(spec.known_parse_issue)
                @test_throws ParseError model_ir(spec.name)
                continue
            end
            ir = model_ir(spec.name)
            @test ir isa NetworkIR
            @test length(ir.variables) == spec.n_nodes
            @test sum(length(v.parents) for v in ir.variables) == spec.n_arcs
            @test any(v -> v.kind == DecisionNode, ir.variables) == spec.has_decisions
            @test any(v -> v.kind == UtilityNode, ir.variables) == spec.has_utilities
            @test BayesianNetworkFormats.validate(ir; allow_missing_tables=true) === ir
            s = model_summary(spec.name)
            @test s.n_nodes == spec.n_nodes && s.n_arcs == spec.n_arcs
            @test s.loadable == !is_influence_diagram(spec)
            @test s.has_decisions == spec.has_decisions
        end
    end

    @testset "BNMA decision networks: strict parse, finding nodes without tables" begin
        # Netica '#n' state-index literals and finding/equation nodes with evidence but
        # no probs; the manifests set allow_missing_tables = true.
        expected = Dict("song_sparrow_bdn" => (12, 15, 8, 2, 2,
                                               [:RiparianPlantCost_infl_adj, :Time]),
                        "brown_trout_bdn" => (9, 13, 7, 2, 0, [:time]))
        for (name, (nn, na, nc, nd, nu, missing_ids)) in expected
            spec = model_info(name)
            @test spec.parser_options[:strict] === true
            @test spec.parser_options[:allow_missing_tables] === true
            @test isempty(spec.known_parse_issue)
            ir = model_ir(name; strict=true)
            @test length(ir.variables) == nn == spec.n_nodes
            @test sum(length(v.parents) for v in ir.variables) == na == spec.n_arcs
            @test count(v -> v.kind == ChanceNode, ir.variables) == nc
            @test count(v -> v.kind == DecisionNode, ir.variables) == nd
            @test count(v -> v.kind == UtilityNode, ir.variables) == nu
            @test [v.id
                   for v in ir.variables
                   if v.kind == ChanceNode && v.table === nothing] == missing_ids
            @test_throws ValidationError model_ir(name; allow_missing_tables=false)
            @test_throws ValidationError BayesianNetworkFormats.validate(ir)
            s = model_summary(name)
            @test s.n_missing_tables == length(missing_ids)
            @test s.n_chance == nc && !s.loadable
            text = sprint(show, MIME"text/plain"(), s)
            @test occursin("nodes without a CPT  $(length(missing_ids))", text)
            plural = length(missing_ids) == 1 ? "" : "s"
            @test occursin("InfluenceDiagramModel ($(length(missing_ids)) mechanism$(plural) unbound)",
                           text)
            # The model loads with the finding nodes' mechanisms unbound, which stops
            # semantic validation and optimisation with a MissingKernelError.
            m = load_model(name)
            @test m isa InfluenceDiagramModel
            @test sort(missing_kernels(m)) == sort(missing_ids)
            @test_throws MissingKernelError validate(m; semantics=true)
            @test_throws MissingKernelError optimize(m)
        end
        # Models whose chance nodes all have tables are unaffected by the option.
        @test model_summary("water").n_missing_tables == 0
        @test length(model_ir("water"; allow_missing_tables=true).variables) == 32
        @test !occursin("without a CPT",
                        sprint(show, MIME"text/plain"(), model_summary("water")))
        @test_throws ArgumentError E.read_model_file(model_info("water"),
                                                     model_path("water"); bogus=1)
    end

    @testset "gzip and parser options" begin
        ir = model_ir("water")
        @test ir.format == :net
        @test length(ir.variables) == 32
        @test endswith(ir.source, "water.net.gz")
        @test_throws ArgumentError model_ir("water"; bogus=1)
        @test_throws ArgumentError load_model("water"; nope=true)
        # Ballycanew reads only with strict = false (manifest default); strict = true
        # must hit the equation nodes.
        @test_throws BayesianNetworkFormats.UnsupportedNodeError model_ir("ballycanew_diffuse_p";
                                                                          strict=true)
        ir = model_ir("ballycanew_diffuse_p")
        @test length(ir.extras[:skipped]) == 19
        @test model_summary("ballycanew_diffuse_p").n_skipped == 19
        @test_throws NotAModelFileError E.read_model_file(model_info("beach_mice_bn"),
                                                          "x.neta")
    end

    @testset "parser options on Julia-built models" begin
        # A builtin has no file, so `strict` cannot apply and the build keywords cannot
        # either: both are rejected by name rather than silently ignored.
        for name in ("reference_habitat_bn", "reference_grazing_id")
            @test model_ir(name) isa NetworkIR
            @test load_model(name) !== nothing
            e = try
                model_ir(name; strict=true)
            catch err
                err
            end
            @test e isa ArgumentError
            @test occursin("strict", e.msg) && occursin(name, e.msg)
            for opt in (:atol => 1e-3, :renormalize => true)
                e2 = try
                    load_model(name; (opt.first => opt.second,)...)
                catch err
                    err
                end
                @test e2 isa ArgumentError
                @test occursin(string(opt.first), e2.msg) && occursin(name, e2.msg)
            end
            # The validation keywords of `model_ir` still apply to a built model.
            @test model_ir(name; atol=1e-6) isa NetworkIR
            @test model_ir(name; allow_missing_tables=true) isa NetworkIR
        end
    end

    @testset "load_model on chance-only models" begin
        for name in CHANCE_ONLY_VERBATIM
            m = load_model(name)
            @test m isa BayesModel
            @test validate(m; semantics=true) === nothing
            @test length(variable_names(syntax(m))) == model_info(name).n_nodes
        end
        m = load_model("native_fish_v1")
        p = marginal(m, :FishAbundance)
        @test isapprox(sum(p.table), 1.0; atol=1e-12)
        @test all(>=(0), p.table)
        # Exact check against the IR joint distribution from Formats.
        ir = model_ir("native_fish_v1")
        @test isapprox(p.table,
                       BayesianNetworkFormats.marginal(BayesianNetworkFormats.joint_distribution(ir),
                                                       :FishAbundance); atol=1e-12)
        @test model_summary("native_fish_v1").loadable
        text = sprint(show, MIME"text/plain"(), model_summary("native_fish_v1"))
        @test occursin("7 chance", text) && occursin("BayesModel", text)
        @test occursin("7 nodes", sprint(show, model_summary("native_fish_v1")))
    end

    @testset "slow benchmarks" begin
        for name in SLOW_BENCHMARKS
            ir = model_ir(name)
            @test length(ir.variables) == model_info(name).n_nodes
            if SLOW
                m = load_model(name)
                @test validate(m; semantics=true) === nothing
            end
        end
    end

    @testset "decision models load as InfluenceDiagramModels" begin
        for name in
            ("koalas", "waterhole_fence", "reference_grazing_id", "brown_trout_bdn",
             "song_sparrow_bdn")
            @test is_influence_diagram(model_info(name))
            m = load_model(name)
            @test m isa InfluenceDiagramModel
            ir = model_ir(name)
            @test has_decisions(ir)
            s = model_summary(name)
            @test !s.loadable && s.n_decision > 0
            @test occursin("InfluenceDiagramModel", sprint(show, MIME"text/plain"(), s))
            @test nparts(syntax(m), :Decision) == s.n_decision
            @test nparts(syntax(m), :Utility) == s.n_utility
        end
        # Models whose chance nodes all carry tables validate and solve, and decision
        # variable elimination agrees with the exhaustive oracle.
        expected = Dict("waterhole_fence" => (-30.0833, Dict(:PutInFence => :Yes)),
                        "koalas" => (20.2, Dict(:Cull => :No, :Relocate => :Yes)),
                        "reference_grazing_id" => (36.5241,
                                                   Dict(:GrazingManagement => :maintain)))
        for (name, (meu, actions)) in expected
            m = load_model(name)
            @test validate(m; closed=true, unique_names=true, semantics=true) === nothing
            dve = optimize(m; backend=DecisionVariableElimination())
            ex = optimize(m; backend=ExhaustivePolicySearch())
            @test isapprox(dve.expected_utility, meu; atol=1e-4)
            @test isapprox(dve.expected_utility, ex.expected_utility; atol=1e-9)
            for (d, a) in actions
                @test all(==(a), policy_table(dve.strategy[d]))
                @test all(==(a), policy_table(ex.strategy[d]))
            end
            @test isapprox(expected_utility(m, dve.strategy), meu; atol=1e-4)
        end
        # Waterhole Fence: the fence pays for itself.
        w = load_model("waterhole_fence")
        @test expected_utility(w, :PutInFence => :Yes) >
              expected_utility(w, :PutInFence => :No)
        @test isapprox(expected_utility(w, :PutInFence => :No), -48.9819; atol=1e-4)
        # Its Rainfall prior sums to one only within 5e-8: the manifest renormalises.
        @test model_info("waterhole_fence").parser_options[:renormalize] === true
        @test_throws UnnormalizedKernelError validate(load_model("waterhole_fence";
                                                                 renormalize=false);
                                                      semantics=true)
        # Koalas has two decisions, so a fixed action must fix both.
        k = load_model("koalas")
        @test isapprox(expected_utility(k, [:Cull => :No, :Relocate => :Yes]), 20.2;
                       atol=1e-9)
        @test_throws IncompleteStrategyError expected_utility(k, :Cull => :No)
    end
end
