#!/bin/bash

# Load the specific modules for our pre-built LAMMPS binary
# Note: since the OTH is loaded via modules, please don't do `module reset`
# If you do, make sure to run:
#   module use $OLCF_HARNESS_DIR/modulefiles
#   module load olcf_harness
module is-loaded craype-accel-amd-gfx90a && module unload craype-accel-amd-gfx90a
module load PrgEnv-cray
module load cpe/22.12
module load rocm/5.3.0

echo "Using ${PE_ENV:-unknown} compiler toolchain"

export MPICH_GPU_SUPPORT_ENABLED=1

export LD_LIBRARY_PATH="${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"

export input_file='in.reaxc.hns'

module -t list


# EVERY-NODE SETUP ###############################

# All the SLURM job template variables should be accessible -- WORK_DIR, SCRIPTS_DIR, etc

job_prologue() {
    ldd ${NODE_LOCAL_TMP}/lmp_gfx90a_serial &> ${WORK_DIR}/ldd.log
    #ldd /tmp/lmp_cray_hip &> ${WORK_DIR}/ldd.log

    # Bundle up input & validation files & sbcast
    mkdir ${WORK_DIR}/sbcast_inputs
    old_dir=${PWD}
    cd ${WORK_DIR}/sbcast_inputs
    cp ${SCRIPTS_DIR}/input_files/* .
    # Modify input file
    sed 's#reax/c dual#reax/c#g' ./${input_file} > ./${input_file}.kokkos
    # Correct log
    cp ${SCRIPTS_DIR}/correct_results/rfp.nompi.13.26.21.log .
    cp ${SCRIPTS_DIR}/check_single_node.py .
    tar -czf ${WORK_DIR}/inputs.tar.gz ./*
    echo "SBCASTing inputs.tar.gz"
    sbcast -pf ${WORK_DIR}/inputs.tar.gz ${NODE_LOCAL_TMP}/inputs.tar.gz || echo "sbcast of input files failed"
    echo "Completed SBCASTing inputs.tar.gz"
    echo "SBCASTing lmp_wrapper.sh"
    sbcast -pf ${SCRIPTS_DIR}/lmp_wrapper.sh ${NODE_LOCAL_TMP}/lmp_wrapper.sh || echo "sbcast of lmp_wrapper.sh failed"
    echo "Completed SBCASTing lmp_wrapper.sh"
    cd $old_dir
}

node_prologue() {
    node_name=$1
}

job_epilogue() {
    srun --kill-on-bad-exit=0 -N ${SLURM_NNODES} -n ${SLURM_NNODES} --ntasks-per-node=1 ${SCRIPTS_DIR}/check_single_node_wrapper.sh
}
