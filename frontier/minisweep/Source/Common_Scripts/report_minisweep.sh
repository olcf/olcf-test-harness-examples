#!/bin/bash -l

OUTFILE=stdout.txt
REPORTFILE=minisweep_results.csv

gflops=`grep Normsq $OUTFILE |  awk '{print $10}'`
timeval=`grep Normsq $OUTFILE |  awk '{print $8}'`

echo "Time,GF/s" >> $REPORTFILE
echo "$timeval,$gflops" >> $REPORTFILE
