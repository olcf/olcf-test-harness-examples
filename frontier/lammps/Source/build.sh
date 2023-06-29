#!/bin/bash

source Common_Scripts/setup_env.sh

# For test development, allow a pre-built to be used
# Some source codes take an annoying amount of time to build, so using pre-built 
# binary can speed things up during test development.
# You could also opt to use pre-built binaries in production tests, but you won't 
# exercise your build environment, compilers, etc doing that - if you care to test those.

# Set $USE_MY_LAMMPS to a directory containing your lammps build at harness launch time
if [ ! -z ${USE_MY_LAMMPS} ]; then
    if [ -d ${USE_MY_LAMMPS} ]; then
        if [ -f ${USE_MY_LAMMPS}/bin/lmp_gfx90a ] && [ -f ${USE_MY_LAMMPS}/bin/lmp_cray_cc ]; then
            mkdir -p ./lammps/bin
            cp ${USE_MY_LAMMPS}/bin/lmp_gfx90a ./lammps/bin
            cp ${USE_MY_LAMMPS}/bin/lmp_cray_cc ./lammps/bin
            exit 0
        fi
    fi
fi

# The source is quite large, so in interest in minmizing the example repo, we will grab from the internet
# In your own implementations, you could also 
# 1) include source directly in your test repo (alongside this script in the Source directory)
# 2) clone your own source repo here
# 3) do a `cp -r` from a local filesystem
# 4) Do a wget of a tarball and unpack it here
# 5) Leave like this
# Essentially, you just need to get the source here somehow. However works best in your situation.
# The version here is the latest known working version with these particular tests
git clone -b patch_28Mar2023_update1 https://github.com/lammps/lammps.git

# Copy over makefiles
mkdir -p lammps/src/MAKE/MINE
cp Makefile.cray_cc lammps/src/MAKE/MINE/
cp Makefile.gfx90a lammps/src/MAKE/MINE/

# to save space, remove some of the larger unneccessary dirs
if [ -d lammps/.git ]; then
    rm -rf ./lammps/.git
    rm -rf ./lammps/examples
fi

cd lammps/src

mkdir ../bin/

make no-all
make yes-CLASS2 yes-KSPACE yes-KOKKOS yes-MOLECULE yes-REAXFF yes-RIGID

# RGT_GPU_ARCH is set to gfx90a on Frontier. Adjust or remove as necessary on your system.
echo "Starting LAMMPS ${RGT_GPU_ARCH} build at `date`"
make -j 32 ${RGT_GPU_ARCH}
echo "Finished LAMMPS ${RGT_GPU_ARCH} build at `date`"

mv ./lmp_${RGT_GPU_ARCH} ../bin/

module is-loaded rocm
if [ "$?" -eq "0" ]; then module unload rocm; fi
module unload craype-accel-amd-${RGT_GPU_ARCH}

make no-all
make yes-CLASS2 yes-KSPACE yes-MOLECULE yes-REAXFF yes-RIGID yes-OPENMP
echo "Starting LAMMPS CPU-only build at `date`"
make -j 32 cray_cc
echo "Finished LAMMPS CPU-only build at `date`"

mv ./lmp_cray_cc ../bin/

