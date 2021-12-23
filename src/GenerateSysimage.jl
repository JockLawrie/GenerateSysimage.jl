module GenerateSysimage

export generate_sysimage

const packages_to_retain = Set(["Dates", "Logging", "PackageCompiler", "Pkg"])

using Dates
using Pkg
using PackageCompiler
using Logging

function generate_sysimage(packagelist::Vector{String}, sysimage_name::String, precompile_script=nothing)
    @info "$(now()) Start"
    @info "$(now()) Checking inputs"
    !isnothing(precompile_script) && !isfile(precompile_script) && error("The precompile script is not a file")

    @info "$(now()) Determining the path of the resulting sysimage"
    outdir = joinpath(pwd(), "output")
    !isdir(outdir) && mkdir(outdir)
    result_fullpath = joinpath(outdir, sysimage_name)

    @info "$(now()) Adding the packages in the package list"
    for p in packagelist
        Pkg.add(p)
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


end
