#!/bin/bash

# Wraps the check_single_node.py script to enable searching multiple GCDs

declare -A status_code_severity=(
[SUCCESS]=0
[PERF-FAIL]=1
[FAIL]=2
[HW-FAIL]=3
[INCORRECT]=3
)

echohost() {
    echo "[$(date +'%Y-%m-%dT%H:%M')] $(hostname): $1"
}

should_update_status() {
    # Requires 2 args - old status & new status
    old_status_severity=${status_code_severity[${1}]}
    new_status_severity=${status_code_severity[${2}]}
    if [ $new_status_severity -gt $old_status_severity ]; then
        return 0
    else
        return 1
    fi
}


output_dir=${WORK_DIR}/$(hostname)
[ ! -d $output_dir ] && echohost "Couldn't find output dir: ${output_dir}. Exiting." && exit 0

errs=""
status_code="SUCCESS"
ngcds=0

cd $NODE_LOCAL_TMP
# dir names: lammps_run_[0-7]
for d in ./*; do
    d=$(basename ${d})
    if [ -d $d ] && [[ "$d" =~ ^lammps_run_[0-7]{1}$ ]]; then
        echohost "Found dir: $d"
        cd $d
        gcd_id=$(echo $d | cut -d'_' -f3)
        ./check_single_node.py --quiet --rfp ./rfp.nompi.13.26.21.log > gcd_report.txt 2>&1
        ngcds=$(expr $ngcds + 1)
        # Check that it's only one line
        if [ "$(cat gcd_report.txt | wc -l | awk '{print $1}')" == "1" ]; then
            # Then it's one line
            new_status=$(cat gcd_report.txt | head -n1 | awk '{print $2}')
            if [ ! "$new_status" == "SUCCESS" ]; then
                cp lammps-*.log $output_dir
                should_update_status $status_code $new_status && status_code=$new_status
                new_msg=$(cat gcd_report.txt | head -n1 | awk '{$1=""; $2=""; print $0}' | sed -e 's|[\(\)]||g')
                errs="${errs} GCD ${gcd_id} (SN: $(cat /sys/class/drm/card${gcd_id}/device/serial_number)): ${new_msg}."
            fi
        else
            echohost "Found multiple log files reported for one GCD"
            # If the status code is less fatal, update it
            should_update_status $status_code "FAIL" && status_code="FAIL"
            errs="${errs} Found multiple log files for GCD ${gcd_id}."
            # Save the gcd_report output
            cp gcd_report.txt ${output_dir}/gcd.${gcd_id}.report.txt
        fi
        cd ..
    fi
done

echo "$(hostname) ${status_code} Scanned ${ngcds} GCDs. ${errs:1}" > ${output_dir}/node_report.txt
echohost "Completed single-node check"

exit 0
