module GenerateSysimage

export generate_sysimage

using Dates
using Pkg
using PackageCompiler
using Logging

function generate_sysimage(packagelist, sysimage_name)
    @info "$(now()) Start"
    @info "$(now()) Determining result path"
    outdir = joinpath(pwd(), "output")
    if !isdir(outdir)
        mkdir(outdir)
    end
    result_fullpath = joinpath(outdir, sysimage_name)

    @info "$(now()) Adding the packages in the package list"
    for p in packagelist
        Pkg.add(p)
    end

    @info "$(now()) Creating sysimage"
    PackageCompiler.create_sysimage(packagelist; sysimage_path=result_fullpath)
    #PackageCompiler.create_sysimage(packagelist; sysimage_path=result_fullpath,precompile_execution_file="precompile_example.jl")
    @info "$(now()) Done. The new sysimage is at: $(result_fullpath)"

    @info "$(now()) Removing packages (ensures that the next sysimage has the latest versions)"
    for p in packagelist
        Pkg.rm(p)
    end
    @info "$(now()) Finished"
end


end
