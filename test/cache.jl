@testset "cache" begin
    @testset "checksums of committed files" begin
        checked = verify_checksums()
        @test Set(checked) == Set(s.name for s in MODEL_SPECS if is_verbatim(s))
        @test sha256_file(model_path("water")) == model_info("water").sha256
    end

    @testset "model_path" begin
        @test isfile(model_path("water"))
        @test endswith(model_path("water"), "water.net.gz")
        @test_throws NoModelFileError model_path("reference_habitat_bn")
        @test is_available("water") && is_available("reference_grazing_id")
        @test fetch_model("water") == model_path("water")
        @test import_model("water", model_path("water")) == model_path("water")
        @test_throws NoModelFileError fetch_model("reference_habitat_bn")
        @test_throws NoModelFileError import_model("reference_habitat_bn",
                                                   model_path("water"))
        @test licence_text("water") !== nothing &&
              occursin("CC BY-SA", licence_text("water"))
        @test licence_text("animals") === nothing
    end

    @testset "fetch-only models without the file" begin
        spec = model_info("plexus_teb_bat_site")
        @test is_fetch_only(spec) && is_fetchable(spec)
        @test "plexus_teb_bat_site" in fetchable_models()
        clear_cache(; name="plexus_teb_bat_site")
        @test !is_available("plexus_teb_bat_site")
        e = try
            model_path("plexus_teb_bat_site")
        catch err
            err
        end
        @test e isa ModelNotFetchedError
        msg = sprint(showerror, e)
        @test occursin("fetch_model(\"plexus_teb_bat_site\")", msg)
        @test occursin(spec.download_url, msg)
        @test occursin(spec.fetch_instructions, msg)
        @test_throws ModelNotFetchedError model_ir("plexus_teb_bat_site")
        @test_throws ModelNotFetchedError load_model("plexus_teb_bat_site")
        # A fetch-only model whose host has no working direct endpoint: fetch_model must
        # say so rather than downloading an error page.
        @test !is_fetchable("marten_telomere")
        @test "marten_telomere" ∉ fetchable_models()
        @test_throws NoDownloadURLError fetch_model("marten_telomere")
        manual = ModelNotFetchedError("x", "do this", "")
        @test occursin("No direct download", sprint(showerror, manual))
        @test occursin("do this", sprint(showerror, NoDownloadURLError("x", "do this")))
    end

    @testset "import_model round trip" begin
        # Use a fetch-only spec whose checksum we control: build one from the koalas file.
        spec = ModelSpec(; name="koalas_import_test", title="t", category="decision",
                         format="dne", redistribution="fetch-only", directory="koalas",
                         sha256=model_info("koalas").sha256)
        src = model_path("koalas")
        mktempdir() do tmp
            copy = joinpath(tmp, "Koalas copy.dne")
            cp(src, copy)
            dest = E.cached_path(spec)
            rm(dirname(dest); recursive=true, force=true)
            @test E.check_model_file(spec, copy) === nothing
            @test E._verify_checksum(spec, copy) == spec.sha256
            mkpath(dirname(dest))
            cp(copy, dest; force=true)
            @test isfile(dest)
            @test read(dest) == read(src)
            @test E.read_model_file(spec, dest).name == "Koalas"
            @test "koalas_import_test" ∈ readdir(cache_dir())
            rm(dirname(dest); recursive=true, force=true)

            # Wrong bytes: checksum mismatch, with the expected and actual digests.
            bad = joinpath(tmp, "bad.dne")
            write(bad, vcat(read(src), UInt8[' ']))
            e = try
                E._verify_checksum(spec, bad)
            catch err
                err
            end
            @test e isa ChecksumMismatchError
            @test occursin(spec.sha256, sprint(showerror, e))
            @test occursin(sha256_file(bad), sprint(showerror, e))

            # HTML and empty files are rejected before any checksum.
            html = joinpath(tmp, "page.dne")
            write(html, "<!DOCTYPE html><html><body>login</body></html>")
            @test_throws NotAModelFileError E.check_model_file(spec, html)
            empty = joinpath(tmp, "empty.dne")
            touch(empty)
            @test_throws NotAModelFileError E.check_model_file(spec, empty)
            @test_throws NotAModelFileError E.check_model_file(spec, joinpath(tmp, "none"))
            @test_throws ArgumentError import_model("animals", joinpath(tmp, "none"))
            @test_throws NotAModelFileError import_model("animals", html)
            @test_throws ChecksumMismatchError import_model("animals", copy)

            # A manifest without a checksum warns and records nothing.
            nosum = ModelSpec(; name="nosum", title="t", category="decision",
                              format="dne", redistribution="fetch-only",
                              directory="koalas")
            @test_logs (:warn, r"no sha256") E._verify_checksum(nosum, copy)
        end
    end

    @testset "import_model through the public API" begin
        # Temporarily point the animals cache entry at a file we can construct: the
        # checksum must match, so import the real koalas bytes under a spec that says so.
        spec = model_info("koalas")
        @test import_model("koalas", model_path("koalas")) == model_path("koalas")
        @test E.cached_file_name(model_info("animals")) == "animals.dne"
        @test E.cached_file_name(ModelSpec(; name="z", title="t", category="benchmark",
                                           format="net", redistribution="fetch-only",
                                           directory="z",
                                           download_url="http://x/z.net.gz")) ==
              "z.net.gz"
        @test startswith(E.cached_path(model_info("animals")), cache_dir())
        @test isdir(cache_dir())
        @test occursin("EcologicalBayesianNetworks", E.USER_AGENT)
    end

    @testset "cache root override" begin
        # cache_dir() follows with_cache_dir first, then ECOLOGICAL_BN_CACHE, and the
        # scratch space only when neither is set. The whole suite runs inside a
        # with_cache_dir block (test/runtests.jl), which is why nothing here can delete a
        # user's downloaded models.
        outer = cache_dir()
        mktempdir() do inner
            with_cache_dir(inner) do
                @test cache_dir() == abspath(inner)
                @test startswith(E.cached_path(model_info("animals")), abspath(inner))
            end
            @test cache_dir() == outer
            # A thrown error must still restore the previous root.
            @test_throws ErrorException with_cache_dir(() -> error("boom"), inner)
            @test cache_dir() == outer

            # The environment variable is honoured when no block is active.
            envdir = joinpath(inner, "from_env", "nested")
            saved = E._CACHE_OVERRIDE[]
            try
                E._CACHE_OVERRIDE[] = nothing
                withenv(E.CACHE_ENV_VAR => envdir) do
                    @test cache_dir() == abspath(envdir)
                    @test isdir(envdir)          # created on demand
                end
                withenv(E.CACHE_ENV_VAR => nothing) do
                    @test cache_dir() == SCRATCH_CACHE
                end
            finally
                E._CACHE_OVERRIDE[] = saved
            end
        end
        @test cache_dir() == outer
    end

    @testset "verify_checksums collecting mode" begin
        result = verify_checksums(; collect_mismatches=true)
        @test result.checked == verify_checksums()
        @test isempty(result.mismatches)
    end

    @testset "FetchError" begin
        e = FetchError("animals", "https://example.invalid/x.dne",
                       ErrorException("connection refused"))
        @test e isa ZooError
        msg = sprint(showerror, e)
        @test occursin("FetchError", msg)
        @test occursin("animals", msg)
        @test occursin("https://example.invalid/x.dne", msg)
        @test occursin("connection refused", msg)
        @test occursin("import_model", msg)
        # A download failure is wrapped rather than surfacing as a Downloads.RequestError.
        spec = model_info("animals")
        # A file:// URL that does not exist fails in curl exactly as an HTTP error does,
        # without touching the network.
        bad = ModelSpec(; name=spec.name, title=spec.title, category=spec.category,
                        format=spec.format, redistribution="fetch-only",
                        directory=spec.directory, sha256=spec.sha256,
                        download_url="file:///ecorecipes-no-such-directory/missing.dne")
        mktempdir() do tmp
            with_cache_dir(tmp) do
                err = try
                    fetch_model(bad; verbose=false)
                catch caught
                    caught
                end
                @test err isa FetchError
                @test err.name == "animals"
                @test err.url == bad.download_url
                @test !isfile(E.cached_path(bad))
                # No half-written temporary file is left behind.
                @test isempty(readdir(dirname(E.cached_path(bad))))
            end
        end
    end

    @testset "download into place across filesystems" begin
        # _move_into_place falls back to copy + remove when rename fails (a depot on a
        # volume separate from the download directory).
        mktempdir() do tmp
            src = joinpath(tmp, "a.txt")
            dest = joinpath(tmp, "sub", "b.txt")
            write(src, "payload")
            mkpath(dirname(dest))
            @test E._move_into_place(src, dest) == dest
            @test read(dest, String) == "payload"
            @test !isfile(src)
        end
    end

    @testset "clear_cache" begin
        marker = joinpath(cache_dir(), "zz_test_entry")
        mkpath(marker)
        touch(joinpath(marker, "x"))
        clear_cache(; name="animals")
        @test isdir(marker)
        clear_cache()
        @test !isdir(marker)
        @test isdir(cache_dir())
    end
end
