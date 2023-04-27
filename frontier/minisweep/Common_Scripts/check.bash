#!/bin/bash

TEST_COMPLETION_FAILURE=1
TEST_CORRECTNESS_FAILURE=2
TEST_PERFORMANCE_FAILURE=5
TEST_SUCCESS=0

FILE=out_sweep.txt

local_detect_nodefail() {
    export failed_nodes=""
    if [ "$(sacct -j ${1} -X -n | wc -l)" == "1" ]; then
        echo "No node failure detected."
    else
        echo "Node failure detected."
        export failed_nodes="found resized job step."
    fi
    [ ! "x$failed_nodes" == "x" ] && echo "$failed_nodes"
}

if [ ! "${failed_nodes+set}" = set ]; then
  # Try to find the job id & query sacct for it
  if ls | grep -q 'slurm-[0-9]+.out'; then
    echo "Found in slurm-*.out file"
    job_id=$(ls | grep 'slurm-[0-9]+.out' | sed -e 's|slurm-||g' -e 's|\.out||g')
    # same snippet from slurm.template.x to find a resizing step
    local_detect_nodefail $job_id
  elif grep -q '^SLURM_JOBID=' job.environ; then
    echo "Found in job.environ"
    job_id=$(grep '^SLURM_JOBID=' job.environ | cut -d'=' -f2)
    # same snippet from slurm.template.x to find a resizing step
    local_detect_nodefail $job_id
  else
    echo "Couldnt auto-detect slurm jobid. Skipping node check"
  fi
fi


# Automated node fail detection
[ ! "x$failed_nodes" == "x" ] && echo "Check script detected node failure. Exiting with status 9" && exit 9

# Check if job completed and produced output line
if [ $(grep Normsq <$FILE | wc -l) != 1 ] ; then
  echo "Job failed to complete."
  if grep -q "HSA_STATUS_ERROR" $FILE; then
    hsa_err=$(grep "HSA_STATUS_ERROR" $FILE | awk '{for (i = 1; i < NF; i++) { if ($i ~ /HSA_STATUS_.*/) print $i; }}' | sed -e 's|:||')
    echo "Auto-detected an HSA error: $hsa_err. Echoing to check_alias.txt."
    echo $hsa_err > check_alias.txt
  elif grep -q "Memory access fault" $FILE; then
    echo "Auto-detected a memory access fault. Echoing to check_alias.txt"
    echo "MEM_ACCESS_FAULT" > check_alias.txt
  elif grep -q "Bus error" $FILE; then
    echo "Auto-detected a Bus error. Echoing to check_alias.txt"
    echo "BUS_ERR" > check_alias.txt
  elif grep -q "MPICH ERROR" $FILE; then
    echo "Auto-detected an MPI error. Echoing to check_alias.txt"
    echo "MPI_ERR" > check_alias.txt
  else
    echo "No automatic failure mode was triggered."
    echo "GENERIC_FAIL" > check_alias.txt
  fi
  exit $TEST_COMPLETION_FAILURE
fi

# Check if job failed correctness check
if [ $(grep FAIL <$FILE | wc -l) == 1 ] ; then
  echo "Job failed correctness check."
  exit $TEST_CORRECTNESS_FAILURE
fi

# Check if job completed correctly
if [ $(grep PASS <$FILE | wc -l) != 1 ] ; then
  echo "Job failed correctness check."
  exit $TEST_CORRECTNESS_FAILURE
fi

#PERF_TARGET=200
PERF_TARGET=100
PERF_RATE="$(grep Normsq $FILE | sed -e 's/.*GF.s. *//')"
PERF_FAIL=$(echo "$PERF_RATE < $PERF_TARGET" | bc)

echo "gflops_per_s = $PERF_RATE" > metrics.txt

if [ $PERF_FAIL != 0 ] ; then
  echo "Job failed performance check."
  exit $TEST_PERF_FAILURE
fi

echo "Job completed successfully."
exit $TEST_SUCCESS

