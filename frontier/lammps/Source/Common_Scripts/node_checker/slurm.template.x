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

# Copy correct results into the work directory
cp ${SCRIPTS_DIR}/correct_results/* .

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
else
    cp ${input_file} ${input_file}.kokkos
fi

# Run the executable.
log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode start

run_local(){
    nodename=$1
    NRANKS=${RGT_TASKS_PER_NODE}
    REP_SYSTEMS_PER_TASK=__default_systems_per_task__
    mult_size=1
    num_sizes=1
    # defaults to running 1, 2, 4
    if [ -z $LAMMPS_NUM_SIZES ]; then LAMMPS_NUM_SIZES=3; fi
    # Run the test for 1x, 2x, and 4x the original system size
    while [ $num_sizes -le $LAMMPS_NUM_SIZES ]; do
        total_size=`expr ${NRANKS} \* ${REP_SYSTEMS_PER_TASK} \* ${mult_size}`
        v_multipliers=`${BUILD_DIR}/Common_Scripts/find_n_close_factors.py 3 ${total_size}`
        x_size="-v x `echo ${v_multipliers} | cut -d' ' -f1`"
        y_size="-v y `echo ${v_multipliers} | cut -d' ' -f2`"
        z_size="-v z `echo ${v_multipliers} | cut -d' ' -f3`"
        set -x
        srun -u -N 1 -m *,nopack -n ${NRANKS} -w ${nodename} \
            --gpus-per-node=${RGT_TASKS_PER_NODE} --gpu-bind=closest \
            ${LAMMPS_EXE} -k on g 1 \
            -sf kk -pk kokkos gpu/aware on ${LMP_PKG_KOKKOS_CMD} \
            -in ${input_file}.kokkos \
            -log log.`echo ${input_file} | sed -e "s|./in.||"`.${mult_size}x.${nodename} \
            ${x_size} ${y_size} ${z_size} ${LMP_THERMO_FLAG} ${LMP_STEP_FLAG} \
            2>&1 >> stdout.txt.${nodename}.${mult_size}
        set +x
        num_sizes=`expr ${num_sizes} + 1`
        mult_size=`expr ${mult_size} \* 2`
    done
}

# batched run
num_launched=0
for h in `scontrol show hostnames`; do
    run_local ${h} &
    num_launched=`expr $num_launched + 1`
    # every 2,000, pause and wait for finish
    if [ $num_launched -eq 2000 ]; then
        wait
        num_launched=0
    fi
done

wait

log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode final

# Ensure we return to the starting directory.
cd $SCRIPTS_DIR

# Copy the output and results back to the $RESULTS_DIR
#cp -rf $WORK_DIR/* $RESULTS_DIR
cp $WORK_DIR/job.* $RESULTS_DIR

# Check the final results.
check_executable_driver.py -p $RESULTS_DIR -i $HARNESS_ID

# Resubmit if needed
case __resubmit__ in
    0)
       echo "No resubmit";;
    1)
       test_harness_driver.py -r;;
esac
