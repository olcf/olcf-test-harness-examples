#!/usr/bin/env python3

import sys
sys.path.append('./build_directory/Common_Scripts/node_checker')
import os
import helper

metrics = {}

# enable copy-less checking
workdir = os.environ['RGT_TEST_WORK_DIR'] if 'RGT_TEST_WORK_DIR' in os.environ else '.'

print(f"Searching {workdir} for runs")

failed = 0
incorrect = 0
# Failed check file
failed_node_names = []
# Failed energy breakdown
incorrect_node_names = []
num_logs = 0
# This should be run in Run_Archive
for f in os.listdir(workdir):
    if f.startswith('log.'):
        num_logs += 1
        f_split = f.split('.')
        node_name = f_split[len(f_split) - 1]
        size = f_split[len(f_split) - 2]
        if not helper.check_file(f"{workdir}/{f}"):
            failed += 1
            failed_node_names.append(f"{node_name}.{size}")
            print(f"check_file failed for {node_name} at {size}")
            continue
        rfp_log = f'rfp.log.{size}'
        if not helper.energy_breakdown(f"{workdir}/{rfp_log}", f"{workdir}/{f}"):
            incorrect += 1
            incorrect_node_names.append(node_name)
            print(f"Energy breakdown failed for {node_name} at {size}")
        print(f"All checks passed for {node_name} at {size}")

metrics_file = open('metrics.txt', 'w')
metrics_file.write(f"failed-node-count = {failed}\n")
metrics_file.write(f"incorrect-node-count = {incorrect}\n")
metrics_file.write(f"failed-node-names = {','.join(failed_node_names)}\n")
metrics_file.write(f"incorrect-node-names = {','.join(incorrect_node_names)}\n")
success_rate = 100.0 * float(num_logs - incorrect - failed) / float(num_logs)
metrics_file.write(f"success-rate = {success_rate}\n")
metrics_file.close()

if incorrect > 0:
    sys.exit(1)

sys.exit(0)
