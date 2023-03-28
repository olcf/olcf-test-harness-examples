#!/bin/bash

exit_check() {
    if [[ $1 -ne 0 ]]; then 
        echo "Command failed. Exiting..."
        exit 1
    fi
}

module load craype-accel-amd-gfx908
module load PrgEnv-cray
module load rocm

## These must be set before compiling so the executable picks up GTL
export PE_MPICH_GTL_DIR_amd_gfx908="-L${CRAY_MPICH_ROOTDIR}/gtl/lib"
export PE_MPICH_GTL_LIBS_amd_gfx908="-lmpi_gtl_hsa"

## These must be set before running
export MPIR_CVAR_GPU_EAGER_DEVICE_MEM=0
export MPICH_GPU_SUPPORT_ENABLED=1

export MPICH_SMP_SINGLE_COPY_MODE=CMA

echo $'\nModules loaded:\n'
module -t list
exit_check $?

echo $'\nChanging directory to hipOMB...\n'
cd osu-micro-benchmarks-5.7
exit_check $?

echo $'\nRunning autoreconf...\n'
autoreconf -ivf
exit_check $?

echo $'\nConfiguring...\n'
./configure CC=${CRAYPE_DIR}/bin/cc \
            CXX=${CRAYPE_DIR}/bin/CC \
            CFLAGS="-I${ROCM_PATH}/include" \
            CXXFLAGS="-I${ROCM_PATH}/include" \
            LDFLAGS="-L$ROCM_PATH/lib -lhsa-runtime64" \
            --enable-rocm --with-rocm=$ROCM_PATH \
            --prefix=$PWD/..

exit_check $?

echo $'\nCompiling...\n'
make
#exit_check $? #UPC doesn't compile for some reason, but it's not needed

echo $'\nInstalling...\n'
make install
#exit_check $? #UPC doesn't compile for some reason, but it's not needed

echo $'\nhipOMB installed successfully.\n'
