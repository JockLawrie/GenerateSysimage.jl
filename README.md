# Generate Sysimage

To build a custom sysimage, do the following:

1. Navigate to this project's root directory.

2. Open `scripts/generate_sysimage.jl` and configure the `sysimage_name` and `packagelist` inputs as desired.

3. Run the script from the command line as follows:  julia scripts/generate_sysimage.jl

To use the new sysimage, start Julia from the command line with the sysimage flag set to the location of your newly generated sysimage.
For example:

```
julia --sysimage=/path/to/GenerateSysimage.jl/output/TestSysimage1.so
```