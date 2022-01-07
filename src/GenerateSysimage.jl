module GenerateSysimage

export generate_sysimage

const packages_to_retain = Set(["Dates", "Logging", "PackageCompiler", "Pkg"])

using Dates
using Pkg
using PackageCompiler
using Logging
using TOML

function generate_sysimage(packagelist::Vector{String}, sysimage_name::String, precompile_script)
    @info "$(now()) Start"
    @info "$(now()) Determining the path of the resulting sysimage"
    outdir = joinpath(pwd(), "output")
    !isdir(outdir) && mkdir(outdir)
    create_new_depot(outdir)  # Fresh depot to be used by the temporary project
    result_fullpath = joinpath(outdir, sysimage_name)
    
    @info "$(now()) Generating temporary project"
    tempproject_dir = generate_tempproject(packagelist, outdir)
    if precompile_script == "usetests"
        @info "$(now()) Generating precompile script from the test suites of listed packages"
        precompile_script = generate_precompile_script(packagelist, sysimage_name, outdir, tempproject_dir)
    end

    @info "$(now()) Creating sysimage from temporary project"
    if isnothing(precompile_script)
        create_sysimage(packagelist; sysimage_path=result_fullpath)
    else
        create_sysimage(packagelist; sysimage_path=result_fullpath, precompile_execution_file=precompile_script)
    end
    @info "$(now()) Done. The new sysimage is at: $(result_fullpath)"

    @info "$(now()) Removing temporary project"
    cd(@__DIR__)
    rm(tempproject_dir; recursive=true)

    @info "$(now()) Finished"
end

################################################################################
# Generate temp project

function create_new_depot(outdir)
    newdepot = joinpath(outdir, ".julia")
    isdir(newdepot) && rm(newdepot; recursive=true)
    mkdir(newdepot)
    empty!(DEPOT_PATH)
    push!(DEPOT_PATH, newdepot)
end

function generate_tempproject(packagelist, outdir)
    # Init tempproject
    cd(tempdir())
    isdir("tempproject") && rm("tempproject"; recursive=true)
    Pkg.generate("tempproject")
    cd("tempproject")
    Pkg.activate(".")
    pkgdir = pwd()

    # Add packages to tempproject
    for p in packagelist
        Pkg.add(p)
    end
    pwd()
end

################################################################################
# Generate precompile script

function generate_precompile_script(packagelist, sysimage_name, outdir, tempproject_dir)
    precompile_script = init_precompilescript(sysimage_name, outdir)
    append_package_imports_to_precompilescript!(precompile_script, packagelist)
    pkgname2pkgdir = construct_pkgname2pkgdir()
    extrapackages  = construct_extrapackages(packagelist, pkgname2pkgdir)
    add_packages_to_tempproject!(tempproject_dir, extrapackages)
    append_package_imports_to_precompilescript!(precompile_script, extrapackages)
    append_tests_to_precompilescript!(precompile_script, packagelist)
end

function init_precompilescript(sysimage_name, outdir)
    imagename, ext    = splitext(sysimage_name)
    precompile_script = joinpath(outdir, "$(imagename).jl")
    touch(precompile_script)
end

function append_package_imports_to_precompilescript!(precompile_script, packagelist)
    open(precompile_script, "w") do f
        for p in packagelist  # Import all dependencies before running tests
            write(f, "using $(p)\n")
        end
    end
end

function construct_pkgname2pkgdir()
    result = Dict{String, String}()  # packagename => packagedir
    deps   = Pkg.dependencies()
    for (uuid, pkginfo) in deps
        result[pkginfo.name] = pkginfo.source
    end
    result
end

function construct_extrapackages(packagelist, pkgname2pkgdir)
    result = Set{String}()
    packages_done = Set(packagelist)
    for pkgname in packagelist
        packagedir     = pkgname2pkgdir[pkgname]
        extra_packages = get_extra_packages(result, packagedir)
        for p in extrapackages
            in(p, packages_done) && continue
            push!(result, p)
            push!(packages_done, p)
        end
    end
    sort!([x for x in result])
end

function get_extra_packages(result, packagedir::String)
    projtoml = joinpath(packagedir, "Project.toml")
    extract_package_names!(result, projtoml, "extras")
    projtoml = joinpath(packagedir, "test", "Project.toml")
    extract_package_names!(result, projtoml, "deps")
    result
end

"Insert into result the packages listed in the specified section of the Project.toml file."
function extract_package_names!(result::Set{String}, projtoml_fullpath, section)
    !isfile(projtoml_fullpath) && return
    d = TOML.parsefile(projtoml_fullpath)
    !haskey(d, section) && return
    for (packagename, uuid) in d[section]
        push!(result, packagename)
    end
end

function add_packages_to_tempproject!(tempproject_dir, extrapackages)
    for p in extrapackages
        Pkg.add(p)
    end
end

function append_tests_to_precompilescript!(precompile_script, packagelist, pkgname2pkgdir)
    open(precompile_script, "w") do f
        for pkgname in packagelist
            write(f, "include($(pkgname2pkgdir[pkgname]), \"test\", \"runtests.jl\"))\n")
        end
    end
end

end
