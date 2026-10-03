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

    @testset "the size limits of the readers" begin
        # `max_states` and `max_table_cells` reach BayesianNetworkFormats' readers from a
        # keyword or from the manifest; both were rejected as unknown parser options.
        ir = model_ir("koalas")
        cells = maximum(length(v.table) for v in ir.variables if v.table !== nothing)
        states = maximum(length(v.states) for v in ir.variables)
        @test model_ir("koalas"; max_states=states, max_table_cells=cells) == ir
        e = try
            model_ir("koalas"; max_table_cells=cells - 1)
        catch err
            err
        end
        @test e isa ParseError && occursin("max_table_cells = $(cells - 1)", e.message)
        @test_throws ParseError load_model("koalas"; max_states=states - 1)
        # a gzipped model is read by the same reader
        @test_throws ParseError model_ir("water"; max_table_cells=10)
        # the keywords are validated as `read_network` validates them
        @test_throws ArgumentError model_ir("koalas"; max_states=0)
        @test_throws TypeError model_ir("koalas"; max_table_cells=1.5)
        # a manifest that lowers a limit, on a copy of koalas; a keyword overrides it
        mktempdir() do tmp
            dir = joinpath(tmp, "koalas")
            cp(model_dir(model_info("koalas")), dir)
            path = joinpath(dir, "metadata.toml")
            write(path,
                  replace(read(path, String),
                          "[parser_options]" => "[parser_options]\nmax_table_cells = $(cells - 1)"))
            spec = read_manifest(path)
            @test spec.parser_options[:max_table_cells] == cells - 1
            file = joinpath(dir, spec.file)
            @test_throws ParseError E.read_model_file(spec, file)
            @test E.read_model_file(spec, file; max_table_cells=cells) isa NetworkIR
        end
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
            # The size limits act only on a file, so both functions reject them, and
            # `load_model` now rejects `strict` for the same reason instead of dropping it.
            for opt in (:max_states => 10, :max_table_cells => 10),
                f in (model_ir, load_model)

                e3 = try
                    f(name; (opt.first => opt.second,)...)
                catch err
                    err
                end
                @test e3 isa ArgumentError
                @test occursin(string(opt.first), e3.msg) && occursin(name, e3.msg)
            end
            e4 = try
                load_model(name; strict=true)
            catch err
                err
            end
            @test e4 isa ArgumentError && occursin("strict", e4.msg)
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

    @testset "a zoo decision model's certificate records Julia's solution" begin
        I = InfluenceDiagrams
        k = load_model("koalas")
        id = I.syntax(k)
        simple(x) = (q = rationalize(BigInt, x); I._dve_rounds_to(q, x) ? q : big(x) // 1)
        companions = Dict{Tuple{Symbol,Int,Tuple},Rational{BigInt}}()
        for mid in I.mechanisms(id)
            t = I.cpt(I.kernel(k, I.variable_name(id, I.target(id, mid))))
            for c in CartesianIndices(t)
                companions[(:cpt, mid, Tuple(c) .- 1)] = simple(t[c])
            end
        end
        for uid in I.utilities(id)
            t = I.utility_table(I.utility(k, I.utility_name(id, uid)),
                                I._utility_axes(k, uid))
            for c in CartesianIndices(t)
                companions[(:utility, uid, Tuple(c) .- 1)] = simple(t[c])
            end
        end
        f64(v) = reinterpret(Float64, parse(UInt64, v.f64; base=16))
        stable = DecisionVariableElimination(; stable=true)
        for (kwargs, backend, exact) in
            (((;), DecisionVariableElimination(), false), ((;), stable, true),
             ((numeric_mode=:rational_exact, exact_tables=companions), stable, true))
            c = I.export_dve_certificate(k; kwargs..., solution=backend)
            s = c["solution"]
            @test c["version"] == 2 && length(s.policies) == 2
            @test s.arithmetic == (exact ? "exact_rational" : "binary64")
            @test s.data == (haskey(kwargs, :numeric_mode) ? "q" : "f64")
            reference = optimize(k, backend)
            for p in s.policies
                d = parse(Int, p.decision)
                a = I.decision_variable(id, d)
                @test p.axes == string.(I.decision_information(id, d))
                table = policy_table(reference.strategy[I.decision_name(id, d)])
                ids = BayesianNetworks.state_ids(id, a)
                labels = I.states(id, a)
                @test [e.action for e in p.entries] ==
                      [string(ids[findfirst(==(table[(e.at .+ 1)...]), labels)])
                       for e in p.entries]
            end
            value = f64(s.value)
            @test abs(value - reference.expected_utility) <= 4 * eps(abs(value))
            haskey(kwargs, :numeric_mode) || @test value === reference.expected_utility
            eu = expected_utility(k, reference.strategy)
            @test abs(value - eu) <= 4 * eps(max(abs(value), abs(eu)))
            @test isapprox(value, 20.2; atol=1e-9)
        end
    end
end
