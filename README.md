# Generate Sysimage

To build a clean depot of packages and optionally a custom Julia sysimage, do the following:

1. Navigate to this project's root directory.

2. Open `scripts/generate_sysimage.jl` and configure the input parameters as required.

   The input parameters are:
   - `output_directory`. The full path of the directory in which output will be stored.
   - `packagelist::Vector{String}`. List of package names to be included in the new depot and sysimage (optional).
   - `sysimage_name`. One of:

       - `nothing`. A custom sysimage will not be built.
       - The name of the sysimage to be built. For example, `"MyImage.so"`.

   - `precompile_script`. One of the following:

       - `nothing`. No precompiling occurs during sysimage creation.
       - `"usetests"`. Precompile packages by running their test suites.
       - filename (full path). Precompile packages by running the script contained in filename.

3. Run the script from the command line as follows:  `julia scripts/generate_sysimage.jl`

   The resulting sysimage is stored in the `GenerateSysimage.jl/output` directory.

To use the new sysimage, start Julia from the command line with the sysimage flag set to the sysimage's location. For example:

```
julia --sysimage=GenerateSysimage.jl/output/TestSysimage.so
```

## Under the hood

This package:

1. Generates a temporary project with the list of supplied packages as dependencies.
2. Creates a sysimage from the temporary project and stores it in the `GenerateSysimage.jl/output` directory.
3. Deletes the temporary project.