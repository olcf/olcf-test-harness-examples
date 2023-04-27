#!/bin/bash

module load PrgEnv-cray
module load craype-accel-amd-gfx90a
module load rocm
module load hwloc

export MPICH_OFI_NIC_POLICY=NUMA

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

