sysimage_name     = "TestSysimage.so"
packagelist       = ["DataFrames"]
precompile_script = nothing

using Pkg
Pkg.activate(".")
using GenerateSysimage

generate_sysimage(packagelist, sysimage_name, precompile_script)