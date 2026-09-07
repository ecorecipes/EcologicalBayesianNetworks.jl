# The licence policy (docs/adr/0008-model-zoo-licence-policy.md): a verbatim file may be
# committed only under one of these exact licence strings. Anything carrying a
# no-derivatives (ND) or non-commercial (NC) clause is fetch-only, and a substring match
# cannot enforce that -- "CC BY-ND" contains "CC BY".
const VERBATIM_LICENCES = ("CC-BY (version unstated)", "CC-BY-SA (version unstated)",
                           "CC BY 4.0", "CC BY-SA 3.0", "CC BY-SA 4.0", "CC0 1.0", "MIT")

"""
    licence_permits_redistribution(licence) -> Bool

`true` when `licence` is on the verbatim allow-list and carries no ND or NC clause. Both
conditions are checked: the allow-list is the policy, the clause check is the backstop
that catches an allow-list entry added by mistake.
"""
function licence_permits_redistribution(licence::AbstractString)
    licence in VERBATIM_LICENCES || return false
    return !occursin(r"\bN[CD]\b"i, licence) &&
           !occursin(r"non-?commercial|no-?derivat"i,
                     licence)
end

@testset "registry" begin
    @testset "licence allow-list" begin
        # Every permitted string passes and is stable.
        @test all(licence_permits_redistribution, VERBATIM_LICENCES)
        for bad in ("CC BY-ND", "CC-BY-ND (version unstated)", "CC BY-NC-ND",
                    "CC-BY-NC-ND (version unstated)", "CC-BY-NC (version unstated)",
                    "CC BY-NC 4.0", "unstated",
                    "CC0 1.0 (ScienceBase record); US Government work in the public domain")
            @test !licence_permits_redistribution(bad)
        end
        # The regression this replaces: `occursin(r"CC BY|MIT|CC0"i, licence)` accepted a
        # no-derivatives and a non-commercial licence, so either could have been committed
        # verbatim. The allow-list rejects them, and the clause check is the backstop.
        for slipped_through in ("CC BY-ND", "CC BY-NC-ND", "CC BY-NC 4.0")
            @test occursin(r"CC BY|MIT|CC0"i, slipped_through)      # the old test passed
            @test !licence_permits_redistribution(slipped_through)  # the new one does not
            @test occursin(r"\bN[CD]\b"i, slipped_through)
        end
    end

    @testset "a verbatim ND manifest is rejected" begin
        # A manifest that claims verbatim redistribution under CC BY-ND must fail the
        # policy check even though its licence string contains "CC BY".
        mktempdir() do tmp
            dir = joinpath(tmp, "koalas")
            mkpath(dir)
            good = read(joinpath(MODELS_DIR, "koalas", "metadata.toml"), String)
            cp(joinpath(MODELS_DIR, "koalas", "Koalas.dne"), joinpath(dir, "Koalas.dne"))
            path = joinpath(dir, "metadata.toml")
            write(path,
                  replace(good,
                          "licence = \"CC-BY (version unstated)\"" => "licence = \"CC BY-ND\""))
            spec = read_manifest(path)      # structurally valid ...
            @test is_verbatim(spec)
            @test spec.licence == "CC BY-ND"
            @test !licence_permits_redistribution(spec.licence)   # ... but not permitted
            @test occursin(r"CC BY|MIT|CC0"i, spec.licence)       # the old test passed it
        end
    end

    @testset "manifests load and are complete" begin
        @test n_models() == length(MODEL_SPECS) >= 20
        dirs = sort(filter(d -> isfile(joinpath(MODELS_DIR, d, "metadata.toml")),
                           readdir(MODELS_DIR)))
        @test sort([spec.name for spec in MODEL_SPECS]) == dirs
        for spec in MODEL_SPECS
            path = joinpath(model_dir(spec), "metadata.toml")
            d = E.TOML.parsefile(path)
            for key in E.REQUIRED_MANIFEST_KEYS
                @test haskey(d, key)
            end
            @test spec.category in MODEL_CATEGORY_ORDER
            @test spec.format in E.MODEL_FORMATS
            @test spec.redistribution in E.REDISTRIBUTION_KINDS
            @test !isempty(spec.title)
            @test !isempty(spec.licence)
            @test !isempty(spec.citation)
            @test occursin(r"^\d{4}-\d{2}-\d{2}$", spec.retrieved)
            @test read_manifest(path) == spec
            if is_verbatim(spec)
                @test isfile(joinpath(model_dir(spec), spec.file))
                @test isfile(joinpath(model_dir(spec), "LICENSE.txt"))
                @test occursin(r"^[0-9a-f]{64}$", spec.sha256)
                @test licence_permits_redistribution(spec.licence)
            elseif is_fetch_only(spec)
                @test isempty(spec.file)
                @test !isempty(spec.fetch_instructions)
                # Never a committed model file next to a fetch-only manifest.
                @test all(f -> f in ("metadata.toml",), readdir(model_dir(spec)))
                isempty(spec.download_url) || @test occursin(r"^[0-9a-f]{64}$", spec.sha256)
            elseif is_reconstruction(spec)
                @test spec.format == "package"
                @test isempty(spec.file)
                @test !isempty(spec.source_url)
                @test !isempty(spec.fetch_instructions)
                @test isempty(spec.sha256)
                @test spec.n_nodes == 0 && spec.n_arcs == 0
                @test !is_redistributable(spec)
                @test all(f -> f in ("metadata.toml",), readdir(model_dir(spec)))
                @test !is_available(spec.name)
                for f in (model_path, model_ir, load_model)
                    @test_throws ReconstructionOnlyError f(spec.name)
                end
                @test_throws ReconstructionOnlyError import_model(spec.name,
                                                                  model_path("water"))
                msg = sprint(showerror,
                             ReconstructionOnlyError(spec.name, spec.source_url,
                                                     spec.licence))
                @test occursin(spec.name, msg) && occursin(spec.source_url, msg)
            else
                @test spec.format == "julia"
                @test !isempty(spec.constructor)
                @test isdefined(E, Symbol(spec.constructor))
            end
        end
    end

    @testset "ordering and categories" begin
        keys_ = [E._spec_sort_key(spec) for spec in MODEL_SPECS]
        @test issorted(keys_)
        @test model_categories() == [c for c in MODEL_CATEGORY_ORDER
                                     if any(s -> s.category == c, MODEL_SPECS)]
        @test "benchmark" in model_categories()
        @test "reference" in model_categories()
    end

    @testset "lookup" begin
        @test model_info("water").name == "water"
        @test model_info(:water).name == "water"
        @test model_info("WATER").name == "water"
        @test model_info("Song Sparrow BDN").name == "song_sparrow_bdn"
        @test model_info("song-sparrow-bdn").name == "song_sparrow_bdn"
        @test model_info("BNMA 126").name == "koalas"
        @test_throws UnknownModelError model_info("run_koalas")
        @test model_info("water.net.gz").name == "water"
        @test model_info(model_info("koalas")) === model_info("koalas")
        @test_throws UnknownModelError model_info("nonesuch")
        @test occursin("nonesuch", sprint(showerror, UnknownModelError("nonesuch")))
        @test E._normalize_model_lookup_key(" Foo Bar-1 ") == "foobar1"
        @test E._normalize_model_lookup_key("Run_Foo") == "runfoo"
        # ModelSpec hashes field-wise, so equal specs agree and a changed field does not.
        koalas = model_info("koalas")
        @test hash(koalas) == hash(read_manifest(joinpath(model_dir(koalas),
                                                          "metadata.toml")))
        @test hash(koalas) != hash(model_info("water"))
        @test length(Set([koalas, model_info("koalas"), model_info("water")])) == 2
    end

    @testset "available_models and model_catalog" begin
        bench = available_models(; category="benchmark")
        @test issorted(bench)
        @test "water" in bench && "barley" in bench && "mildew" in bench
        @test "koalas" ∉ bench
        ids = available_models(; kind=:id)
        @test "koalas" in ids && "waterhole_fence" in ids && "reference_grazing_id" in ids
        @test "water" ∉ ids
        bns = available_models(; kind=:bn)
        @test "water" in bns && "koalas" ∉ bns
        pkgs = available_models(; kind=:package)
        @test isempty(intersect(ids, bns))
        @test isempty(intersect(pkgs, vcat(ids, bns)))
        @test sort(vcat(ids, bns, pkgs)) == available_models()
        @test "bnrep_package" in pkgs && "water" ∉ pkgs
        @test all(n -> is_reconstruction(model_info(n)), pkgs)
        @test "bnrep_package" ∉ available_models(; redistributable=true)
        @test "animals" ∉ available_models(; redistributable=true)
        @test "animals" in available_models(; redistributable=false)
        e = try
            available_models(; kind=:foo)
        catch err
            err
        end
        @test e isa ArgumentError && occursin(":package", e.msg)
        cat = model_catalog(; category="decision")
        @test cat isa ModelCatalog
        @test length(cat) == length(collect(cat))
        @test all(s -> s.category == "decision", cat)
        @test length(model_catalog(; format="net")) == 4     # + hailfinder
        @test length(model_catalog(; format="package")) == 5
        @test length(model_catalog(; licence="by-sa")) == 5
        @test length(model_catalog()) == n_models()
        text = sprint(show, MIME"text/plain"(), model_catalog(; category="benchmark"))
        @test occursin("water", text) && occursin("CC BY-SA 3.0", text)
        pkg_text = sprint(show, MIME"text/plain"(), model_info("bnrep_package"))
        @test occursin("reconstruction package", pkg_text)
        @test occursin("package",
                       sprint(io -> catalog_table(io, [model_info("bnrep_package")])))
        @test occursin("ModelCatalog(", sprint(show, model_catalog()))
        md = sprint(io -> catalog_table(io, MODEL_SPECS; markdown=true))
        @test startswith(md, "| name")
        @test count("\n", md) == n_models() + 2
        spec_text = sprint(show, MIME"text/plain"(), model_info("water"))
        @test occursin("renormalize = true", spec_text)
        @test occursin("ModelSpec(\"water\"", sprint(show, model_info("water")))
    end

    @testset "invalid manifests" begin
        mktempdir() do tmp
            dir = joinpath(tmp, "bad")
            mkpath(dir)
            path = joinpath(dir, "metadata.toml")
            write(path, "name = \"bad\"\n")
            @test_throws InvalidManifestError read_manifest(path)
            e = try
                read_manifest(path)
            catch err
                err
            end
            @test occursin("missing required keys", sprint(showerror, e))
            good = read(joinpath(MODELS_DIR, "koalas", "metadata.toml"), String)
            write(path,
                  replace(good, "name = \"koalas\"" => "name = \"bad\"",
                          "category = \"decision\"" => "category = \"zoo\""))
            @test_throws InvalidManifestError read_manifest(path)
            write(path, replace(good, "name = \"koalas\"" => "name = \"bad\""))
            @test_throws InvalidManifestError read_manifest(path)   # file missing
            write(path, replace(good, "name = \"koalas\"" => "name = \"other\""))
            @test_throws InvalidManifestError read_manifest(path)   # name != dir
            @test_throws InvalidManifestError read_manifest(joinpath(tmp, "none.toml"))
            # A file that is not TOML at all is reported as a manifest error, not as a
            # bare TOML.ParserError.
            write(path, "name = \"bad\"\nthis is not = = toml\n")
            e = try
                read_manifest(path)
            catch err
                err
            end
            @test e isa InvalidManifestError
            @test occursin("TOML parse error", sprint(showerror, e))
            @test isempty(load_model_specs(joinpath(tmp, "nothing-here")))
            write(path,
                  replace(good, "name = \"koalas\"" => "name = \"bad\"",
                          "redistribution = \"verbatim\"" => "redistribution = \"fetch-only\"",
                          "file = \"Koalas.dne\"" => ""))
            @test read_manifest(path).name == "bad"
            @test length(load_model_specs(tmp)) == 1
        end
    end
end
