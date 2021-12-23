module GenerateSysimage

export generate_sysimage

const packages_to_retain = Set(["Dates", "Logging", "PackageCompiler", "Pkg"])

using Dates
using Pkg
using PackageCompiler
using Logging

function generate_sysimage(packagelist::Vector{String}, sysimage_name::String, precompile_script)
    @info "$(now()) Start"
    @info "$(now()) Checking inputs"
    precompile_script = check_precompile_script(precompile_script)

    @info "$(now()) Determining the path of the resulting sysimage"
    outdir = joinpath(pwd(), "output")
    !isdir(outdir) && mkdir(outdir)
    result_fullpath = joinpath(outdir, sysimage_name)

    @info "$(now()) Generating temporary package"
    temppkg_dir = generate_temppkg(packagelist)

    @info "$(now()) Creating sysimage from temporary package"
    if isnothing(precompile_script)
        create_sysimage(packagelist; sysimage_path=result_fullpath)
    else
        create_sysimage(packagelist; sysimage_path=result_fullpath, precompile_execution_file=precompile_script)
    end
    @info "$(now()) Done. The new sysimage is at: $(result_fullpath)"

    @info "$(now()) Removing temporary package"
    cd(@__DIR__)
    rm(temppkg_dir; recursive=true)

    @info "$(now()) Finished"
end

################################################################################

function check_precompile_script(precompile_script)
    if isnothing(precompile_script) || isfile(precompile_script)
        return precompile_script
    elseif precompile_script == "usetests"
        @info "$(now()) Auto-generating precompile script"
        return generate_precompile_file(packagelist, outdir, sysimage_name)
    else
        error("The precompile script is unrecognised")
    end
end

function generate_temppkg(packagelist)
    cd(tempdir())
    Pkg.generate("temppkg")
    cd("temppkg")
    Pkg.activate(".")
    for p in packagelist
        Pkg.add(p)
    end
    pwd()
end

function generate_precompile_file(packagelist, outdir, sysimage_name)
    imagename, ext  = splitext(sysimage_name)
    precompile_file = joinpath(outdir, "$(imagename).jl")
    open(precompile_file, "w") do f
        for p in packagelist
            write(f, "using $(p)\n")
            write(f, "include(joinpath(pkgdir($(p)), \"test\", \"runtests.jl\"))\n")
        end
    end
    precompile_file
end

end
