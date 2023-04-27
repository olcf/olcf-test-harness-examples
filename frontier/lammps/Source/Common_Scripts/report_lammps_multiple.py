#!/usr/bin/env python3

import sys
sys.path.append('./build_directory/Source/Common_Scripts')
import os
import helper

metrics = {}

incorrect = 0
# This should be run in Run_Archive
for f in os.listdir():
    if f.startswith('log.'):
        f_split = f.split('.')
        last_entry = f_split[len(f_split) - 1]
        if last_entry.startswith('n'):
            # then it's a valid file name
            node_count = int(last_entry[1:])
            print(f"Found log for node count of {node_count}")
            if not helper.check_file(f):
                incorrect += 1
                print(f"check_file failed for {f}")
            else:
                print(f"check_file passed for {f}")
                tmp_metric = helper.report_file(f)
                for k, v in tmp_metric.items():
                    metrics[f"{k}-{node_count}n"] = v
                    print(f"{k}-{node_count}n = {v}")

if incorrect > 0:
    sys.exit(1)

metrics_file = open('metrics.txt', 'w')
for k, v in metrics.items():
    metrics_file.write(f"{k} = {v}\n")
metrics_file.close()

sys.exit(0)
