#!/usr/bin/env python3

import sys
sys.path.append('./build_directory/Common_Scripts/node_checker')

import os
import helper

# Weak, strong scaling log naming: log.{test_name}.n{nnodes}
# Single-run log naming: log.{test_name}

# enable copy-less checking
workdir = os.environ['RGT_TEST_WORK_DIR'] if 'RGT_TEST_WORK_DIR' in os.environ else '.'
print(f"Searching {workdir} for runs")

found_rfp = False
num_rfp_logs = 0
rfp_file_name = ''
logs = []
incorrect = 0
# This should be run in Run_Archive
for f in os.listdir(workdir):
    if f.startswith('log.') or f.startswith('rfp.log.'):
        logs.append(f)
        f_split = f.split('.')
        node_name = f_split[len(f_split) - 1]
        size = f_split[len(f_split) - 2]
        print(f"Found log for node count of {node_name}, {size} system size")
        if not helper.check_file(f"{workdir}/{f}"):
            incorrect += 1
            print(f"check_file failed for {f}")
        else:
            print(f"check_file passed for {f}")

if found_rfp and num_rfp_logs == 1:
    for l in logs:
        if not helper.energy_breakdown(f"{workdir}/{rfp_file_name}", f"{workdir}/{l}"):
            sys.exit(1)
else:
    print(f"WARNING: no RFP logs found")

# Exits after checking RFP because there's multiple nodes to be checked
if incorrect > 0:
    sys.exit(1)

sys.exit(0)
