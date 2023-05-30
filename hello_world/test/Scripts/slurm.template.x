#!/bin/bash -l
#SBATCH -J __job_name__
#SBATCH -N __nodes__
#SBATCH -t __walltime__
#SBATCH -o __job_name__.o%j

module list

# Define environment variables needed
EXECUTABLE="__executable_path__"
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

# Make the working scratch space directory.
if [ ! -e $WORK_DIR ]
then
    mkdir -p $WORK_DIR
fi

# Change directory to the working directory.
cd $WORK_DIR

env &> job.environ
scontrol show hostnames > job.nodes

# Run the executable.
log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode start

CMD="sleep 60"
echo "$CMD"
$CMD 2>&1 | tee ./test_output.txt

log_binary_execution_time.py --scriptsdir $SCRIPTS_DIR --uniqueid $HARNESS_ID --mode final

# Ensure we return to the starting directory.
cd $SCRIPTS_DIR

# Copy the output and results back to the $RESULTS_DIR
cp -rf $WORK_DIR/* $RESULTS_DIR 
cp $BUILD_DIR/output_build.txt $RESULTS_DIR

# Check the final results.
check_executable_driver.py -p $RESULTS_DIR -i $HARNESS_ID

# Resubmit if needed
case __resubmit__ in
    0) 
       echo "No resubmit";;
    1) 
       test_harness_driver.py -r __max_submissions__ ;;
esac 

