# Network tests: run with ECOLOGICAL_BN_FETCH=true (or scripts/run_network_tests.jl).
# The suite runs inside with_cache_dir(mktempdir()) (test/runtests.jl), so every model is
# downloaded afresh here and nothing the user has fetched is touched.
@testset "fetch (network)" begin
    # Every fetchable model is downloaded and checksummed; the models that also build a
    # BayesModel cheaply get the deeper treatment below.
    deep = ("plexus_teb_bat_site", "plexus_teb_bat_subwatershed",
            "plexus_population_viability", "animals", "microctonus_ng_risk",
            "tidal_saline_wetlands", "beach_mice_bn")
    @test issubset(deep, fetchable_models())
    for name in fetchable_models()
        spec = model_info(name)
        clear_cache(; name=name)
        path = fetch_model(name; verbose=false)
        @test isfile(path)
        @test path == E.cached_path(spec)
        @test sha256_file(path) == spec.sha256
        @test is_available(name)
        @test fetch_model(name; verbose=false) == path      # cached, no download
        @test fetch_model(name; force=true, verbose=false) == path
        if spec.format == "neta"
            @test_throws NotAModelFileError model_ir(name)
        elseif !isempty(spec.known_parse_issue)
            # The manifest says the current reader cannot parse this file; if that ever
            # stops being true the manifest must lose its known_parse_issue.
            @test_throws ParseError model_ir(name)
        else
            ir = model_ir(name)
            @test length(ir.variables) == spec.n_nodes
            @test sum(length(v.parents) for v in ir.variables) == spec.n_arcs
            if name in deep && !is_influence_diagram(spec)
                m = load_model(name)
                @test validate(m) === nothing
                if model_summary(name).n_missing_tables == 0
                    @test validate(m; semantics=true) === nothing
                else
                    @test !isempty(missing_kernels(m))
                end
            end
        end
        # import_model of the fetched file round-trips.
        mktempdir() do tmp
            copy = joinpath(tmp, basename(path))
            cp(path, copy)
            clear_cache(; name=name)
            @test !is_available(name)
            @test import_model(name, copy) == path
            @test is_available(name)
        end
    end
    @test Set(verify_checksums(; include_cache=true)) ⊇
          Set(["animals", "plexus_teb_bat_site"])

    @testset "Netica '#n' literals: fetch-only pair parses strictly" begin
        # tidal_saline_wetlands: '(#0)' inside a table row, plus two finding nodes
        # without probs; plexus_teb_bat_subwatershed: 'evidence = #1' on a node that
        # does carry its CPT.
        expected = Dict("tidal_saline_wetlands" => (18, 16, [:t, :Denom]),
                        "plexus_teb_bat_subwatershed" => (7, 6, Symbol[]))
        for (name, (nn, na, missing_ids)) in expected
            spec = model_info(name)
            is_available(name) || fetch_model(name; verbose=false)
            @test spec.parser_options[:strict] === true
            @test get(spec.parser_options, :allow_missing_tables, false) ==
                  !isempty(missing_ids)
            ir = model_ir(name; strict=true)
            @test length(ir.variables) == nn == spec.n_nodes
            @test sum(length(v.parents) for v in ir.variables) == na == spec.n_arcs
            @test all(v -> v.kind == ChanceNode, ir.variables)
            @test [v.id
                   for v in ir.variables
                   if v.kind == ChanceNode && v.table === nothing] == missing_ids
            s = model_summary(name)
            @test s.n_missing_tables == length(missing_ids) && s.loadable
            m = load_model(name)
            @test m isa BayesModel
            @test missing_kernels(m) == missing_ids
            if isempty(missing_ids)
                @test validate(m; semantics=true) === nothing
                @test length(model_ir(name; allow_missing_tables=false).variables) == nn
            else
                @test_throws ValidationError model_ir(name; allow_missing_tables=false)
                @test occursin("mechanisms unbound", sprint(show, MIME"text/plain"(), s))
            end
        end
    end

    # Verbatim downloads still match what is committed.
    for name in ("water", "hailfinder", "koalas", "habitat_suitability_tiger",
                 "marten_age", "bnma_water")
        spec = model_info(name)
        tmp = tempname()
        E.Downloads.download(spec.download_url, tmp; headers=["User-Agent" => E.USER_AGENT])
        @test sha256_file(tmp) == spec.sha256
        rm(tmp)
    end
end
