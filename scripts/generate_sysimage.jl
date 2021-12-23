#=
  To run this script:
  1. Configure the sysimage_name and packagelist inputs as desired.
  2. Navigate to this project's root directory, then type:  julia scripts/generate_sysimage.jl
=#

sysimage_name     = "TestSysimage.so"
packagelist       = ["DataFrames"]
precompile_script = "usetests"  # One of: nothing, "usetests", filename

using Pkg
Pkg.activate(".")
using GenerateSysimage

generate_sysimage(packagelist, sysimage_name, precompile_script)