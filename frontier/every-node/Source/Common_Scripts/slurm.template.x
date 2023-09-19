#!/bin/bash
#SBATCH -t __walltime__
#SBATCH -N __nodes__
#SBATCH --job-name=__job_name__
#SBATCH --no-kill
#SBATCH -C nvme
#__sbatch1__
#__sbatch2__
#__sbatch3__
# ^ Optional SBATCH pragmas useful for -S 0, --threads-per-core, -o, etc

# Define environment variables needed
export SCRIPTS_DIR="__scripts_dir__"
export WORK_DIR="__working_dir__"
export RESULTS_DIR="__results_dir__"
export HARNESS_ID="__harness_id__"
export BUILD_DIR="__build_dir__"
export EXECUTABLE="__executable_path__"

echo "Printing test directory environment variables:"
env | fgrep RGT_APP_SOURCE_
env | fgrep RGT_TEST_
echo

# Ensure we are in the starting directory
cd $SCRIPTS_DIR

# Set up test-specific environment
source ${SCRIPTS_DIR}/setup_env.sh

echo "Environment setup completed. Loaded modules:"
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
# make one directory per node
cat job.nodes | xargs -L 8 mkdir

# Default path to executable
src_exe=${BUILD_DIR}/pre-built/${EXECUTABLE}

if [ "x${RGT_COPYLESS_BUILD}" == "x1" ]; then
    # If copy-less build, then there's no build in $BUILD_DIR, copy directly from source
    src_exe=${PREBUILT_PATH}/${RGT_MACHINE_NAME}/${EXECUTABLE}
fi

base_exe=$(basename ${src_exe})

# Set NODE_LOCAL_TMP in your rgt_test_input.ini or setup_env.sh to override /tmp. Use for sending to NVMe
export NODE_LOCAL_TMP=$(echo "${NODE_LOCAL_TMP:-/tmp}" | sed -e "s|\$USER|${USER}|g")
# $USER environment variable replacement needed

echo "Beginning SBCAST of executable from ${src_exe}"
# sbcast the executable & libraries
sbcast --send-libs --exclude=NONE -pf ${src_exe} ${NODE_LOCAL_TMP}/${base_exe}
sbcast_exit=$?
if [ ! "$sbcast_exit" == "0" ]; then
    echo "SBCAST failed (exit code: $sbcast_exit)."
fi

echo "SBCAST complete. Patching linking"

# Patch linking -- libfabric requires ``libhsa-runtime64.so``, `sbcast` only ever sends ``libhsa-runtime64.so.1``
srun -N ${SLURM_NNODES} -n ${SLURM_NNODES} --ntasks-per-node=1 --label -D ${NODE_LOCAL_TMP}/${base_exe}_libs \
    bash -c "if [ -f libhsa-runtime64.so.1 ]; then ln -s libhsa-runtime64.so.1 libhsa-runtime64.so; fi; if [ -f libamdhip64.so.5 ]; then ln -s libamdhip64.so.5 libamdhip64.so; fi"

echo "Patch linking complete."

# Truncate LD_LIBRARY_PATH to be local file-system only
export LD_LIBRARY_PATH=${NODE_LOCAL_TMP}/${base_exe}_libs:`pkg-config --variable=libdir libfabric`

# Binary & libraries have already been sbcast
# Good use case -- putting an `sbcast` in this function to bcast input files
[[ $(type -t job_prologue) == "function" ]] && job_prologue ${nodename}

# OTH function: log the start of the `binary_execute` event type
log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode start

if [ "__launch_separate__" == "1" ]; then
    # batched run
    num_launched=0
    for nodename in `scontrol show hostnames`; do
        usleep 50000
        # Check if node_prologue exists
        [[ $(type -t node_prologue) == "function" ]] && node_prologue ${nodename}
        cd $nodename
        set -x
        # stdout.txt is in a per-node directory
        __launch_command__ &> stdout.txt &
        set +x
        cd ..
        num_launched=`expr $num_launched + 1`
        # every 2,000, pause and wait for finish
        if [ $num_launched -eq 2000 ]; then
            wait
            num_launched=0
        fi
    done
    wait
else
    # Launch as one srun
    set -x
    __launch_command__ &> stdout.txt
    set +x
fi

# OTH function: log the end of the `binary_execute` event type
log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode final

# This would be a good place to run `srun -N ${NODES} -n ${NODES} --ntasks-per-node=1 <check_command>
[[ $(type -t job_epilogue) == "function" ]] && job_epilogue

# Ensure we return to the starting directory.
cd $SCRIPTS_DIR

# Copy ONLY the job environment and nodes back to the $RESULTS_DIR
cp $WORK_DIR/job.* $RESULTS_DIR

# Check the final results. RGT_TEST_WORK_DIR is in the environment, so to avoid
# copying files around unnecessarily, please use RGT_TEST_WORK_DIR in your check
# script to find output files
check_executable_driver.py -p $RESULTS_DIR -i $HARNESS_ID

# Make exit code based off of node statuses
#   FAILED - FAILED, FAIL, BAD
#   SUCCESS - OK, SUCCESS, GOOD, PASS
#   HW-FAIL - INCORRECT, HW-FAIL
#   PERF-FAIL - PERF, PERF-FAIL
exit_code=0
if [ -f $RESULTS_DIR/nodecheck.txt ]; then
    echo "Setting job exit code from result of nodecheck.txt"
    # Fail the Slurm job if any node failed the node screen. Performance failures do not currently count towards this
    cat $RESULTS_DIR/nodecheck.txt | tr [a-z] [A-Z] | awk '{print $2}' | grep -e '^FAILED$' -e '^FAIL$' -e '^BAD$' -e '^INCORRECT$' -e '^HW-FAIL' -q && exit_code=1
elif ! touch $RESULTS_DIR/nodecheck.txt; then
    # Then $RESULTS_DIR is inaccessible & this job should exit 1
    echo "$RESULTS_DIR/nodecheck.txt is inaccessible"
    exit_code=1
fi

# OPTIONAL: exclude the current nodes from the next job
if [ "x${RGT_EXCLUDE_CURRENT_NODES}" == "x1" ]; then
    if [ -z $RGT_SUBMIT_ARGS_ORIG ]; then
        # then this is the first iteration -- need to set this so that we can save the original state
        export RGT_SUBMIT_ARGS_ORIG=${RGT_SUBMIT_ARGS:-""}
    fi
    export RGT_SUBMIT_ARGS="${RGT_SUBMIT_ARGS_ORIG} -x $(scontrol show hostnames | xargs | sed -e 's| |,|g')"
    echo "Set RGT_SUBMIT_ARGS=\"${RGT_SUBMIT_ARGS}\""
fi

# Resubmit if needed
case __resubmit__ in
    0)
       echo "No resubmit";;
    1)
       test_harness_driver.py -r;;
esac

exit ${exit_code}
