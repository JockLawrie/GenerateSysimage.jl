module GenerateSysimage

export generate_sysimage

const packages_to_retain = Set(["Dates", "Logging", "PackageCompiler", "Pkg"])

using Dates
using Pkg
using PackageCompiler
using Logging

function generate_sysimage(packagelist::Vector{String}, sysimage_name::String, precompile_script)
    @info "$(now()) Start"
    @info "$(now()) Determining the path of the resulting sysimage"
    outdir = joinpath(pwd(), "output")
    !isdir(outdir) && mkdir(outdir)
    result_fullpath = joinpath(outdir, sysimage_name)

    @info "$(now()) Generating temporary project"
    precompile_script = generate_precompile_script(packagelist, sysimage_name, precompile_script, outdir)
    tempproject_dir   = generate_tempproject(packagelist)

    @info "$(now()) Creating sysimage from temporary project"
    create_sysimage(packagelist; sysimage_path=result_fullpath, precompile_execution_file=precompile_script)
    @info "$(now()) Done. The new sysimage is at: $(result_fullpath)"

    @info "$(now()) Removing temporary project"
    cd(@__DIR__)
    rm(tempproject_dir; recursive=true)

    @info "$(now()) Finished"
end

################################################################################
# Generate precompile script

function generate_precompile_script(packagelist, sysimage_name, precompile_script, outdir)
    isnothing(precompile_script)    && return generate_precompile_script_from_packagelist(packagelist, outdir, sysimage_name, false)
    precompile_script == "usetests" && return generate_precompile_script_from_packagelist(packagelist, outdir, sysimage_name, true)
    isfile(precompile_script)       && return precompile_script
    error("The precompile script is unrecognised")
end

"""
For each package in packagelist:
- Include a line containing: using packagename
- If usetests == true, also include a line that runs the package's test suite.
"""
function generate_precompile_script_from_packagelist(packagelist, outdir, sysimage_name, usetests::Bool)
    @info "$(now()) Auto-generating precompile script"
    imagename, ext  = splitext(sysimage_name)
    precompile_file = joinpath(outdir, "$(imagename).jl")
    open(precompile_file, "w") do f
        for p in packagelist
            write(f, "using $(p)\n")
            usetests && write(f, "include(joinpath(pkgdir($(p)), \"test\", \"runtests.jl\"))\n")
        end
    end
    precompile_file
end

################################################################################
# Other functions

function generate_tempproject(packagelist)
    cd(tempdir())
    Pkg.generate("tempproject")
    cd("tempproject")
    Pkg.activate(".")
    for p in packagelist
        Pkg.add(p)
    end
    pwd()
end

end
