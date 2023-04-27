#!/bin/bash
#------------------------------------------------------------------------------

TEST_NAME=$(basename $(dirname $(dirname $RGT_TEST_RUNARCHIVE_DIR)))

[[ -z "$(echo $TEST_NAME | sed -e 's/.*_mpi_.*//')" ]] && \
  IS_USING_MPI=YES || IS_USING_MPI=NO

[[ -z "$(echo $TEST_NAME | sed -e 's/.*_perf.*//')" ]] && \
  IS_PERF_RUN=YES || IS_PERF_RUN=NO

NUM_NODE=$(echo $TEST_NAME | sed -e 's/.*_n0*\([0-9]*\).*/\1/')

NUM_RANK_PER_NODE=$(echo $TEST_NAME | \
  sed -e 's/.*_rpn0*\([0-9]*\).*/\1/' -e 's/.*[a-zA-Z_].*/1/')

NUM_PROC=$(( $NUM_NODE * $NUM_RANK_PER_NODE ))

if [ $IS_PERF_RUN = NO ] ; then
  NE=32
  NCELL_Z=32
  #NCELL_LOCAL_X=16
  NCELL_LOCAL_X=32
  NCELL_LOCAL_Y=32
else
  NE=32
  NCELL_Z=64
  #NCELL_LOCAL_X=16
  NCELL_LOCAL_X=128
  NCELL_LOCAL_Y=128
fi


if [ $IS_USING_MPI = NO ] ; then

  CMD="./sweep --ncell_x 64 --ncell_y 64 --ncell_z $NCELL_Z --ne $NE --na 32 --nblock_z $NCELL_Z \
    --is_using_device 1 --nthread_octant 8 --nthread_e $NE"

else

  # Determine a decomposition.

  i=1
  while [ $(( $i * $i )) -le $NUM_PROC ] ; do
    if [ $(( $NUM_PROC % $i )) = 0 ] ; then
      NUM_PROC_X=$i
    fi
    i=$(( $i + 1 ))
  done

  NUM_PROC_Y=$(( $NUM_PROC / $NUM_PROC_X ))

  CMD="./sweep --ncell_x $(( $NCELL_LOCAL_X * $NUM_PROC_X )) --ncell_y $(( $NCELL_LOCAL_Y * $NUM_PROC_Y )) \
    --nproc_x $NUM_PROC_X --nproc_y $NUM_PROC_Y \
    --ncell_z $NCELL_Z --ne $NE --na 32 --nblock_z $NCELL_Z \
    --is_using_device 1 --nthread_octant 8 --nthread_e $NE"

fi

if [ "$SLURM_PROCID" = 0 ] ; then
  echo $CMD
fi

$CMD 2>&1 | tee out_sweep.txt

#------------------------------------------------------------------------------
