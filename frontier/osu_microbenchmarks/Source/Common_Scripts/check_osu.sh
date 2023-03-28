#!/bin/bash

echo "Starting check script for OSU Microbench"
echo "This elementary script simply checks if stderr is non-empty"

cd workdir

[ -s stderr.txt ]
if [ "$?" -eq "0" ]; then
    # then the file is not empty
    echo "TEST FAILED with error:"
    cat stderr.txt
    exit 1
else
    echo "Test passed - no output in stderr"
    exit 0
fi
