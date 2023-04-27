#!/bin/bash -l
#SBATCH -J __job_name__
#SBATCH -N __nodes__
#SBATCH -t __walltime__
#SBATCH -o __job_name__.o%j
#SBATCH --no-kill

# Define environment variables needed
SCRIPTS_DIR="__scripts_dir__"
WORK_DIR="__working_dir__"
RESULTS_DIR="__results_dir__"
HARNESS_ID="__harness_id__"
BUILD_DIR="__build_dir__"

TEST_NAME=$(basename $(dirname $(dirname $RGT_TEST_RUNARCHIVE_DIR)))
#[[ -z "$(echo $TEST_NAME | sed -e 's/.*_mpi_.*//')" ]] && \ 
#  IS_USING_MPI=YES || IS_USING_MPI=NO
NUM_NODE=$(echo $TEST_NAME | sed -e 's/.*_n0*\([0-9]*\).*/\1/')
NUM_RANK_PER_NODE=$(echo $TEST_NAME | \
  sed -e 's/.*_rpn0*\([0-9]*\).*/\1/' -e 's/.*[a-zA-Z_].*/1/')

NUM_PROC=$(( $NUM_NODE * $NUM_RANK_PER_NODE ))

export LD_LIBRARY_PATH="/gpfs/alpine/stf016/proj-shared/frontierAT/efaccept/mpi_libs/libs.mpich_cxi_ctr:${LD_LIBRARY_PATH}"

export PMI_MMAP_SYNC_WAIT_TIME=1800
export PMI_SHARED_SECRET=1234

echo "Printing test directory environment variables:"
env | fgrep RGT_APP_SOURCE_
env | fgrep RGT_TEST_
echo

[ ! -d $WORK_DIR ] && { echo "ERROR: working directory $WORK_DIR is missing!"; exit 1; }

# Copy built executables we need to the run dir
mv $BUILD_DIR/sweep $WORK_DIR/

# Change directory to the working directory.
cd $WORK_DIR

env | sort &> job.environ
scontrol show hostnames | sort > job.nodes

# Run the executable.
log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode start

EXECUTABLE=$SCRIPTS_DIR/run.bash
#RUNCMD="srun -n $NUM_PROC -N __nodes__ --ntasks-per-gpu=1 $EXECUTABLE"
RUNCMD="srun -l -v -n $NUM_PROC -N __nodes__ --ntasks-per-node=${NUM_RANK_PER_NODE} --gpus=$NUM_PROC --gpu-bind=map_gpu:0,1,2,3,4,5,6,7 $EXECUTABLE"
echo "Running: $RUNCMD"
$RUNCMD

log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode final

export failed_nodes=""
if [ "$(sacct -j ${SLURM_JOBID} -X -n | wc -l)" == "1" ]; then
    echo "No node failure detected."
else
    echo "Node failure detected."
    export failed_nodes="found resized job step."
fi
[ ! "x$failed_nodes" == "x" ] && echo "Found failed nodes: $failed_nodes"

# Ensure we return to the starting directory.
cd $SCRIPTS_DIR

# Copy the output and results back to the $RESULTS_DIR
cp -rf "$WORK_DIR/"* $RESULTS_DIR 
cp $BUILD_DIR/output_build* $RESULTS_DIR

# Check the final results.
echo "Checking results:"
check_executable_driver.py -p $RESULTS_DIR -i $HARNESS_ID

# Resubmit if needed
case __resubmit__ in
    0) 
       echo "No resubmit";;
    1) 
       echo "Resubmitting:"
       test_harness_driver.py -r ;;
esac 

