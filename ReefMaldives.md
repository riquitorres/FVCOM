# Progress work ReefMaldives
** compilation of FVCOM in Archer2

30 April 2026

Copied files from ~/maz/Code/ pertinent to building FVCOM in archer and placed them in ./maz
Copied maz/build.sh to ~/Code/FVCOM/ and changed module loads and paths to work with FVCOM5

There were some changes required to compile the libs that I got from /work/n01/n01/benbar/ECLH/source/FVCOM5.0/

The module loads were also changed to support petsc/hd5 and netcdf (the parallel versions were needed)

I am hitting compatibility issues with PETSC versions. Ask Yaru what PETSC version they are using.

My changes in FVCOM4.3 need to be ported here. Also, checkout 5.1 and not 5.0.1 as the update to use later PETSC wasn't completed in 5.0.1

After that it should compile in Archer2 and Scylla.
Not compiling in either Scylla or Archer2. seems that i am missing a linking step.

It wasn't a linking step, it was missing two instances of NH preprocessing that had not been updated to PETSC_C option. 

The apparent discrepancy in GNU version of the PETSC module and the gfortran compiler in Prog-Env module safe didn't seem an issue during compilation. We will see during running. 

### checking the binary
On first test runs it seems i am missing proj library... don't know if i need to compile in /work? and not in home?

The solution to this was to add a rpath directly in the proj link step.
## First test simulations in Archer2

Try with saved restart file from Al in Archer2 with wint, tides and nest. Only to test what is missing in the restart file. First test should be to try and run with semi-implicit but no NH.