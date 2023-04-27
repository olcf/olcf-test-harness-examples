#!/bin/bash

module is-loaded craype-accel-amd-gfx908 && module unload craype-accel-amd-gfx908
module is-loaded craype-accel-amd-gfx90a && module unload craype-accel-amd-gfx90a

# If any of these variables are set, then load them. Otherwise stick with what's loaded
if [ ! -z "$RGT_PRG_ENV" ]; then
    module load $RGT_PRG_ENV
fi

if [ ! -z "$RGT_MPICH_VERSION" ]; then
    module load cray-mpich/$RGT_MPICH_VERSION
fi

# Handling ROCM depends on PrgEnv
module is-loaded PrgEnv-amd
if [ "$?" -eq "0" ]; then
    # if ROCM is loaded and AMD is loaded, unload rocm and re-load default amd module
    module is-loaded rocm && module unload rocm && module load amd
    # If a specific rocm version is requested, load the right amd module
    if [ ! -z "$RGT_ROCM_VERSION" ]; then module load amd/$RGT_ROCM_VERSION; fi
else
    if [ -z "$RGT_ROCM_VERSION" ]; then
        # if it's loaded, don't re-load
        module is-loaded rocm || module load rocm
    else
        module load rocm/$RGT_ROCM_VERSION
    fi
fi

# Allow for change in CCE version
module is-loaded PrgEnv-cray
if [ "$?" -eq "0" ]; then
    if [ ! -z $RGT_CCE_VERSION ]; then module load cce/${RGT_CCE_VERSION}; fi
fi

# Allow for change in GCC version
module is-loaded PrgEnv-gnu
if [ "$?" -eq "0" ]; then
    if [ ! -z $RGT_GCC_VERSION ]; then module load cce/${RGT_GCC_VERSION}; fi
fi

# LMOD-specific setup:
if [[ "${LMOD_SYSTEM_NAME}" == "spock" || \
        "${LMOD_SYSTEM_NAME}" == "bones" ]]; then
    echo "Using GFX908 target"
    export RGT_GPU_ARCH="gfx908"
    export RGT_TASKS_PER_NODE="4"
    export RGT_THREADS_PER_TASK="16"
elif [[ "${LMOD_SYSTEM_NAME}" == "borg" || \
        "${LMOD_SYSTEM_NAME}" == "crusher" || \
        "${LMOD_SYSTEM_NAME}" == "frontier" ]]; then
    echo "Using GFX90A target"
    export RGT_GPU_ARCH="gfx90a"
    export RGT_TASKS_PER_NODE="8"
    export RGT_LAMMPS_THREADS_PER_TASK="7"
else
    echo "Unable to determine the GPU architecture for the machine name: `hostname --long`"
    export RGT_GPU_ARCH="unknown"
fi

echo "Using ${PE_ENV:-unknown} toolchain"

## These must be set before running
export MPIR_CVAR_GPU_EAGER_DEVICE_MEM=0
export MPICH_GPU_SUPPORT_ENABLED=1
export MPICH_SMP_SINGLE_COPY_MODE=CMA

export LD_LIBRARY_PATH="${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"

module -t list

