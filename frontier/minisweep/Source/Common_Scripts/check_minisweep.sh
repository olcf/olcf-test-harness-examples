#!/bin/bash -l

OUTFILE=stdout.txt

grep PASS $OUTFILE

if [ $? == 0 ]
then
    echo "Test PASSED!"
else 
    echo "Test FAILED."
    exit 1
fi

exit 0