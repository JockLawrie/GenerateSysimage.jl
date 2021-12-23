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
    !isnothing(precompile_script) && !isfile(precompile_script) && precompile_script != "usetests" && error("The precompile script is unrecognised")

    @info "$(now()) Determining the path of the resulting sysimage"
    outdir = joinpath(pwd(), "output")
    !isdir(outdir) && mkdir(outdir)
    result_fullpath = joinpath(outdir, sysimage_name)

    @info "$(now()) Adding the packages in the package list"
    for p in packagelist
        Pkg.add(p)
    end

    if precompile_script == "usetests"
        @info "$(now()) Auto-generating precompile script"
        precompile_script = generate_precompile_file(packagelist, outdir, sysimage_name)
    end

    @info "$(now()) Creating sysimage"
    if isnothing(precompile_script)
        create_sysimage(packagelist; sysimage_path=result_fullpath)
    else
        create_sysimage(packagelist; sysimage_path=result_fullpath, precompile_execution_file=precompile_script)
    end
    @info "$(now()) Done. The new sysimage is at: $(result_fullpath)"

    @info "$(now()) Removing packages (ensures that the next sysimage has the latest versions)"
    for p in packagelist
        in(p, packages_to_retain) && continue
        Pkg.rm(p)
    end
    @info "$(now()) Finished"
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
