
output_directory   = "C:/data"
packagelist        = ["CategoricalArrays", "CSV", "DataFrames", "Dates", "Distributions", "GLM", "JSON3", "Logging",
                      "MLJLinearModels", "MultinomialRegression", "ODBC", "Optim", "Random", "Statistics", "Tables",
                      "TOML", "UUIDs"]
remove_precompiled = true
sysimage_name      = nothing
precompile_script  = nothing

using Pkg
Pkg.activate(".")
using GenerateSysimage

GenerateSysimage.generate_content(output_directory, packagelist, remove_precompiled, sysimage_name, precompile_script)