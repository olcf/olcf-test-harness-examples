#!/bin/bash

# In Run_Archive
cat `find $WORK_DIR -name "node_report.txt"` > nodecheck.txt

exit_code=0
# Make exit code based off of node statuses
#   FAILED - FAILED, FAIL, BAD
#   SUCCESS - OK, SUCCESS, GOOD, PASS
#   HW-FAIL - INCORRECT, HW-FAIL
#   PERF-FAIL - PERF, PERF-FAIL
[[ -f nodecheck.txt ]] && cat nodecheck.txt | tr [a-z] [A-Z] | awk '{print $2}' | grep -e '^PERF-FAIL$' -e '^PERF$' -q && echo "Found perf failure" && exit_code=5
[[ -f nodecheck.txt ]] && cat nodecheck.txt | tr [a-z] [A-Z] | awk '{print $2}' | grep -e '^FAILED$' -e '^FAIL$' -e '^BAD$' -q && echo "Found test failure" && exit_code=1
[[ -f nodecheck.txt ]] && cat nodecheck.txt | tr [a-z] [A-Z] | awk '{print $2}' | grep -e '^HW-FAIL$' -e '^INCORRECT$' -q && echo "Found critical HW failure" && exit_code=2

if [ ! "$exit_code" == "0" ]; then
    # Then print breakdown
    echo "PERF-FAIL: $(cat nodecheck.txt | tr [a-z] [A-Z] | awk '{print $2}' | grep -e '^PERF-FAIL$' -e '^PERF$' | wc -l)"
    echo "FAILED: $(cat nodecheck.txt | tr [a-z] [A-Z] | awk '{print $2}' | grep -e '^FAILED$' -e '^FAIL$' -e '^BAD$' | wc -l)"
    echo "HW-FAIL: $(cat nodecheck.txt | tr [a-z] [A-Z] | awk '{print $2}' | grep -e '^HW-FAIL$' -e '^INCORRECT$' | wc -l)"
fi

exit ${exit_code}
