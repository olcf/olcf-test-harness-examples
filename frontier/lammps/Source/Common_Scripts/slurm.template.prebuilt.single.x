#!/bin/bash
#SBATCH -t __walltime__
#SBATCH -N __nodes__
#SBATCH --job-name=__job_name__
#SBATCH --no-kill

# Define environment variables needed
SCRIPTS_DIR="__scripts_dir__"
WORK_DIR="__working_dir__"
RESULTS_DIR="__results_dir__"
HARNESS_ID="__harness_id__"
BUILD_DIR="__build_dir__"
EXECUTABLE="__executable_path__"

echo "Printing test directory environment variables:"
env | fgrep RGT_APP_SOURCE_
env | fgrep RGT_TEST_
echo

# Ensure we are in the starting directory
cd $SCRIPTS_DIR

#-# Set up the environment
source ${SCRIPTS_DIR}/setup_env.sh

module -t list

# Make the working scratch space directory.
if [ ! -e $WORK_DIR ]
then
    mkdir -p $WORK_DIR
fi

# Change directory to the working directory.
cd $WORK_DIR

env &> job.environ
scontrol show hostnames > job.nodes

SLURM_NNODES_SAVED=${SLURM_NNODES}

echo "SBCAST'ing executable out to all nodes"
sbcast --send-libs --exclude=NONE -pf ${BUILD_DIR}/pre-built/${EXECUTABLE} /tmp/$(basename ${BUILD_DIR}/pre-built/${EXECUTABLE})

# Patch linking
srun -N ${SLURM_NNODES} -n ${SLURM_NNODES} --ntasks-per-node=1 --label -D /tmp/$(basename ${BUILD_DIR}/pre-built/${EXECUTABLE})_libs \
    bash -c "if [ -f libhsa-runtime64.so.1 ]; then ln -s libhsa-runtime64.so.1 libhsa-runtime64.so; fi; if [ -f libamdhip64.so.5 ]; then ln -s libamdhip64.so.5 libamdhip64.so; fi"

export LD_LIBRARY_PATH=/tmp/$(basename ${BUILD_DIR}/pre-built/${EXECUTABLE})_libs:`pkg-config --variable=libdir libfabric`

echo "SBCAST and linking complete"

#-# Run!
LAMMPS_EXE=/tmp/$(basename ${BUILD_DIR}/pre-built/${EXECUTABLE})
ldd ${LAMMPS_EXE} &> ldd.log

if [ -d ${SCRIPTS_DIR}/input_files ]; then
    cp ${SCRIPTS_DIR}/input_files/* ./
else
    echo "No directory of input files found: ${SCRIPTS_DIR}/input_files"
    exit 1
fi

input_file=`ls ./in.*`
cp ${SCRIPTS_DIR}/correct_results/* ./

if [ ! -z $LAMMPS_BENCHMARK ] && [ "${LAMMPS_BENCHMARK}" == "REAX" ]; then
    # Then we're in the Reax example and need to change things in the input file
    echo 'processors * * * grid twolevel 8 2 2 2' > ${input_file}.kokkos
    sed 's#reax/c dual#reax/c#g' ${input_file} >> ${input_file}.kokkos
else
    cp ${input_file} ${input_file}.kokkos
fi

# Run the executable.
log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode start

run_local(){
    nodect=$1
    # This test requires 8 per node to have correct number of MPI tasks
    NRANKS=`expr 8 \* ${nodect}`
    set -x
    srun -N ${nodect} -m *,nopack -n ${NRANKS} \
        --gpus-per-node=8 --gpu-bind=closest \
        ${LAMMPS_EXE} -k on g 1 \
        -sf kk -pk kokkos gpu/aware on ${LMP_PKG_KOKKOS_CMD} \
        -in ${input_file}.kokkos -log log.reax.${nodect}node \
        ${LAMMPS_SIZE} ${LAMMPS_STEPS} ${LAMMPS_THERMO_STEP} \
        2>&1 >> stdout.txt
    if [ ! "$?" == "0" ]; then set +x; return 1; fi
    set +x
    return 0
}

run_local ${SLURM_NNODES}
exit_code="$?"

echo "SLURM_NNODES_SAVED: ${SLURM_NNODES_SAVED}"
echo "SLURM_NNODES: ${SLURM_NNODES}"

log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode final

# Ensure we return to the starting directory.
cd $SCRIPTS_DIR

# Copy the output and results back to the $RESULTS_DIR
cp -rf $WORK_DIR/* $RESULTS_DIR

# Check the final results.
check_executable_driver.py -p $RESULTS_DIR -i $HARNESS_ID

# Resubmit if needed
case __resubmit__ in
    0)
       echo "No resubmit";;
    1)
       test_harness_driver.py -r;;
esac

exit ${exit_code}
