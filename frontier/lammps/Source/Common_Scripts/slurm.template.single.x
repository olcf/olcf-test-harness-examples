#!/bin/bash
#SBATCH -t __walltime__
#SBATCH -N __nodes__
#SBATCH --job-name=__job_name__

# Define environment variables needed
SCRIPTS_DIR="__scripts_dir__"
WORK_DIR="__working_dir__"
RESULTS_DIR="__results_dir__"
HARNESS_ID="__harness_id__"
BUILD_DIR="__build_dir__"

echo "Printing test directory environment variables:"
env | fgrep RGT_APP_SOURCE_
env | fgrep RGT_TEST_
echo

# Ensure we are in the starting directory
cd $SCRIPTS_DIR

#-# Set up the environment
source ${BUILD_DIR}/Common_Scripts/setup_env.sh

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

#-# Run!
LAMMPS_EXE=${BUILD_DIR}/lammps/bin/lmp_${RGT_GPU_ARCH}
ldd ${LAMMPS_EXE} &> ldd.log

if [ -d ${SCRIPTS_DIR}/input_files ]; then
    cp ${SCRIPTS_DIR}/input_files/* ./
else
    echo "No directory of input files found: ${SCRIPTS_DIR}/input_files"
    exit 1
fi

input_file=`ls ./in.*`

if [ ! -z $LAMMPS_BENCHMARK ] && [ "${LAMMPS_BENCHMARK}" == "REAX" ]; then
    # Then we're in the Reax example and need to change things in the input file
    echo 'processors * * * grid twolevel 8 2 2 2' > ${input_file}.kokkos
    sed 's#reax/c dual#reax/c#g' ${input_file} >> ${input_file}.kokkos
    sed 's#qeq/reax#qeq/reax/omp#g' ${input_file} > ${input_file}.omp
else
    cp ${input_file} ${input_file}.kokkos
    cp ${input_file} ${input_file}.omp
fi

# Run the executable.
log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode start

run_local(){
    nodect=$1
    NRANKS=`expr ${RGT_TASKS_PER_NODE} \* ${nodect}`
    # Original system is __atoms_per_system__ atoms
    if [ -z $LAMMPS_ATOMS_PER_TASK ]; then
        # test-specific. For Reax, there's 300 per system. For TIP3P, theres 45000
        # So these tests will have different values of default_systems_per_task
        REP_SYSTEMS_PER_TASK=__default_systems_per_task__
    else
        # calculate REP_SYSTEMS_PER_TASK, rounds down
        REP_SYSTEMS_PER_TASK=`python -c "print(int(${LAMMPS_ATOMS_PER_TASK} / __atoms_per_system__)"`
    fi
    total_size=`expr ${NRANKS} \* ${REP_SYSTEMS_PER_TASK}`
    v_multipliers=`${BUILD_DIR}/Common_Scripts/find_n_close_factors.py 3 ${total_size}`
    x_size="-v x `echo ${v_multipliers} | cut -d' ' -f1`"
    y_size="-v y `echo ${v_multipliers} | cut -d' ' -f2`"
    z_size="-v z `echo ${v_multipliers} | cut -d' ' -f3`"
    set -x
    srun -N ${nodect} -m *,nopack -n ${NRANKS} \
        --gpus-per-node=${RGT_TASKS_PER_NODE} --gpu-bind=closest \
        ${LAMMPS_EXE} -k on g 1 \
        -sf kk -pk kokkos gpu/aware on ${LMP_PKG_KOKKOS_CMD} \
        -in ${input_file}.kokkos -log log.`echo ${input_file} | sed -e "s|./in.||"`.n${SLURM_NNODES} \
        ${x_size} ${y_size} ${z_size} ${steps_cmd} \
        2>&1 >> stdout.txt
    if [ ! "$?" == "0" ]; then set +x; return 1; fi
    set +x

    if [ ! -z ${NO_RFP} ]; then
        return 0
    fi

    echo "Starting RFP"
    module is-loaded rocm && module unload rocm
    module is-loaded craype-accel-amd-${RGT_GPU_ARCH} && module unload craype-accel-amd-${RGT_GPU_ARCH}
    export MPICH_GPU_SUPPORT_ENABLED=0
    export OMP_NUM_THREADS=${RGT_LAMMPS_THREADS_PER_TASK}
    export OMP_PLACES=threads
    export OMP_PROC_BIND=true
    LAMMPS_EXE=${BUILD_DIR}/lammps/bin/lmp_cray_cc
    ldd ${LAMMPS_EXE} &> ldd.rfp.log

    set -x
    srun -N ${SLURM_NNODES} -n ${NRANKS} --ntasks-per-node=${RGT_TASKS_PER_NODE} -c ${OMP_NUM_THREADS} \
        ${LAMMPS_EXE} -sf omp -pk omp ${OMP_NUM_THREADS} \
        -in ${input_file}.omp -log rfp.log.`echo ${input_file} | sed -e "s|./in.||"`.n${SLURM_NNODES} \
        ${x_size} ${y_size} ${z_size} ${steps_cmd} \
        2>&1 >> stdout.txt
    if [ ! "$?" == "0" ]; then set +x; return 1; fi
    set +x
}

run_local ${SLURM_NNODES}
exit_code="$?"

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
