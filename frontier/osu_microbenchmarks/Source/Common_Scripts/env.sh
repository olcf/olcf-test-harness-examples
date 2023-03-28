#!/bin/bash

if [ -z "$RGT_CRAYPE_ACCEL" ]; then
    module load craype-accel-amd-gfx908
else
    module load $RGT_CRAYPE_ACCEL
fi

if [ -z "$RGT_PRG_ENV" ]; then
    module load PrgEnv-cray
else
    module load $RGT_PRG_ENV
fi

if [ -z "$RGT_MPICH_MODULE" ]; then
    module load cray-mpich
else
    module load $RGT_MPICH_MODULE
fi

if [ -z "$RGT_ROCM_MODULE" ]; then
    module load rocm
else
    module load $RGT_ROCM_MODULE
fi

## These must be set before compiling so the executable picks up GTL
export PE_MPICH_GTL_DIR_amd_gfx908="-L${CRAY_MPICH_ROOTDIR}/gtl/lib"
export PE_MPICH_GTL_LIBS_amd_gfx908="-lmpi_gtl_hsa"

## These must be set before running
export MPIR_CVAR_GPU_EAGER_DEVICE_MEM=0
export MPICH_GPU_SUPPORT_ENABLED=1

export MPICH_SMP_SINGLE_COPY_MODE=CMA
