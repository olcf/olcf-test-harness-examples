#!/bin/bash

source Common_Scripts/setup_env.sh

# For test development, allow a pre-built to be used

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

# Added lammps to the repo Jul 12, 2022
if [ ! -d ./lammps ]; then
    if [ -z "${RGT_LAMMPS_CLONE_CMD}" ]; then
        git clone -b spock git@github.com:olcf/lammps.git
    else
        ${RGT_LAMMPS_CLONE_CMD}
    fi
fi

# to save space, remove some of the larger unneccessary dirs
if [ -d lammps/.git ]; then
    rm -rf ./lammps/.git
    rm -rf ./lammps/examples
fi

cd lammps/src

mkdir ../bin/

make no-all
make yes-CLASS2 yes-KSPACE yes-KOKKOS yes-MOLECULE yes-REAXFF yes-RIGID

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

