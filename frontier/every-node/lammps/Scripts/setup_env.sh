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

## These must be set before running
export MPICH_GPU_SUPPORT_ENABLED=1

# This is required to use any non-default libraries
export LD_LIBRARY_PATH="${CRAY_LD_LIBRARY_PATH}:${LD_LIBRARY_PATH}"

module -t list

# EVERY-NODE SETUP ###############################

# All the SLURM job template variables should be accessible -- WORK_DIR, SCRIPTS_DIR, etc

job_prologue() {
    ldd ${NODE_LOCAL_TMP}/lmp_gfx90a &> ${WORK_DIR}/ldd.log
    cp ${SCRIPTS_DIR}/correct_results/* $WORK_DIR
    # pre-stage the input files
    mkdir ${WORK_DIR}/input_files
    cp ${SCRIPTS_DIR}/input_files/* ${WORK_DIR}/input_files
    # For this LAMMPS problem, this is the name of the input file
    export input_file='in.reaxc.hns'
    echo 'processors * * * grid twolevel 8 2 2 2' > ${WORK_DIR}/input_files/${input_file}.kokkos
    sed 's#reax/c dual#reax/c#g' ${WORK_DIR}/input_files/${input_file} >> ${WORK_DIR}/input_files/${input_file}.kokkos
    # Get this input file pre-staged on each node in the job
    tar -czf ${WORK_DIR}/input_files.tar.gz -C ${WORK_DIR}/input_files/ .
    sbcast -pf ${WORK_DIR}/input_files.tar.gz ${NODE_LOCAL_TMP}/input_files.tar.gz || echo "sbcast of input files failed!"
    srun --kill-on-bad-exit=0 -N ${SLURM_NNODES} -n ${SLURM_NNODES} --ntasks-per-node=1 -D ${NODE_LOCAL_TMP} tar -xf ./input_files.tar.gz
    # Validate that on the current node, we see our input files
    set -x
    ls -lh ${NODE_LOCAL_TMP}
    set +x
}

# This function is run immediately before launching ``srun`` on each node
#node_prologue() {
    #node_name=$1
    # Nothing to do for this problem
#}

# This function is run after the node screen tests have completed
job_epilogue() {
    # Launch the single-node check script on each node, one process per node
    srun --kill-on-bad-exit=0 -N ${SLURM_NNODES} -n ${SLURM_NNODES} --ntasks-per-node=1 bash -c "${SCRIPTS_DIR}/check_single_node.py \$(hostname)"
}
