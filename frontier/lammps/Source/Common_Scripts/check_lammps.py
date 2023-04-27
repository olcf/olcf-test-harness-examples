#!/usr/bin/env python3

import sys
sys.path.append('./build_directory/Source/Common_Scripts')

import os
import helper

# Weak, strong scaling log naming: log.{test_name}.n{nnodes}
# Single-run log naming: log.{test_name}

found_rfp = False
num_rfp_logs = 0
rfp_file_name = ''
logs = []
incorrect = 0
# This should be run in Run_Archive
for f in os.listdir():
    if f.startswith('log.') or f.startswith('rfp.log.'):
        if f.startswith('rfp.log.'):
            num_rfp_logs += 1
            found_rfp = True
            rfp_file_name = f
        else:
            logs.append(f)
        f_split = f.split('.')
        last_entry = f_split[len(f_split) - 1]
        if last_entry.startswith('n'):
            # then it's a valid file name
            node_count = last_entry[1:]
            print(f"Found log for node count of {node_count}")
            if not helper.check_file(f):
                incorrect += 1
                print(f"check_file failed for {f}")
            else:
                print(f"check_file passed for {f}")

if incorrect > 0:
    sys.exit(1)

if found_rfp and len(logs) == 1 and num_rfp_logs == 1:
    if not helper.energy_breakdown(rfp_file_name, logs[0]):
        sys.exit(1)
else:
    print(f"WARNING: found {num_rfp_logs} logs for RFP CPU-only validation, with {len(logs)} GPU log files")
    print(f"This message is expected if you don't run RFP (ie, weak scaling tests)")

sys.exit(0)
