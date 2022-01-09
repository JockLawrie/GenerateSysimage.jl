module GenerateSysimage

using Dates
using Logging
using PackageCompiler
using Pkg
using TOML

"""
Generate a depot containing the packages in the supplied package list.
If sysimage_name is not nothing, then also generate a sysimage.
"""
function generate_content(outdir::String, packagelist::Vector{String}, sysimage_name::Union{Nothing, String}, precompile_script)
    @info "$(now()) Start"

    @info "$(now()) Checking inputs"
    if isnothing(sysimage_name) && !isnothing(precompile_script)
        error("Cannot have a precompile_script and no image name. An image will not be generated without an image name.")
    end

    @info "$(now()) Creating output directory"
    output_type = isnothing(sysimage_name) ? "depot" : "sysimage"
    !isdir(outdir) && mkdir(outdir)
    outdir = abspath(joinpath(outdir, "$(output_type)-$(format_date_for_dirname(now()))"))
    !isdir(outdir) && mkdir(outdir)
    @info "$(now()) Output directory is: $(outdir)"

    @info "$(now()) Initiating new depot"
    newdepot = create_new_depot(outdir)  # Fresh depot to be used by the temporary project
    @info "$(now()) New depot initiated at: $(newdepot)"
    
    @info "$(now()) Generating temporary project"
    tempproject_dir = generate_tempproject(packagelist)  # pwd() is now set to tempproject_dir
    @info "$(now()) Depot updated with packages in the supplied package list"

    !isnothing(sysimage_name) && generate_sysimage(packagelist, sysimage_name, precompile_script, outdir, newdepot, tempproject_dir)

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
    newdepot
end

function generate_tempproject(packagelist)
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
# Generate sysimage

function generate_sysimage(packagelist::Vector{String}, sysimage_name::String, precompile_script,
                           outdir::String, newdepot::String, tempproject_dir::String)
    if precompile_script == "usetests"
        @info "$(now()) Generating precompile script from the test suites of listed packages"
        precompile_script = generate_precompile_script(packagelist, sysimage_name, outdir, tempproject_dir)
    end

    @info "$(now()) Creating sysimage from temporary project"
    sysimage_fullpath = joinpath(outdir, sysimage_name)
    if isnothing(precompile_script)
        create_sysimage(packagelist; sysimage_path=sysimage_fullpath)
    else
        create_sysimage(packagelist; sysimage_path=sysimage_fullpath, precompile_execution_file=precompile_script)
    end
    @info "$(now()) Done. The new sysimage is at: $(sysimage_fullpath)"

    in("PackageCompiler", packagelist) && return  # Do not remove C compiler from depot
    @info "$(now()) Removing compiler from DEPOT_PATH"
    dirnames  = readdir(joinpath(newdepot, "artifacts"); join=true)
    for d in dirnames
        !isdir(d) && continue
        contents = readdir(d)
        in("mingw64", contents) && rm(d; recursive=true)  # TODO Implement for other operating systems
    end
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
    append_tests_to_precompilescript!(precompile_script, packagelist, pkgname2pkgdir)
    precompile_script
end

function init_precompilescript(sysimage_name, outdir)
    imagename, ext    = splitext(sysimage_name)
    precompile_script = joinpath(outdir, "precompile_script_for_$(imagename).jl")
    touch(precompile_script)  # Returns precompile_script
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
        packagedir    = pkgname2pkgdir[pkgname]
        extrapackages = get_extra_packages(result, packagedir)
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

################################################################################
# Utils

function format_date_for_dirname(dttm::DateTime)
    x = "$(round(dttm, Second(1)))"
    x = replace(x, "-" => ".")
    replace(x, ":" => ".")
end

end
