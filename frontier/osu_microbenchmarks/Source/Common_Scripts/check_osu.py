#!/usr/bin/env python3

import os
import sys

os.chdir("workdir")
files_in_dir = os.listdir('.')

def check_file(result):
    hashes_done = False

    def check_numeric_columns(ln):
        ln = ln.split()
        for val in ln:
            val = val.replace('.', '', 1)
            if not val.isnumeric():
                return False
        return True

    with open(result, 'r') as f:
        for line in f:
            if not hashes_done and len(line) > 1:
                if not line.startswith('#'):
                    hashes_done = True
                    if not check_numeric_columns(line):
                        print(f"In file {result}: unexpected non-numeric line: {line}")
                        return False
            elif len(line) > 1:
                if not check_numeric_columns(line):
                    print(f"In file {result}: unexpected non-comment, non-numeric line: {line}")
                    return False
    return True

ret_code = 0
for f in files_in_dir:
    if f.endswith(".out"):
        # then check to make sure it matches expected format
        if not check_file(f):
            ret_code = 1

if ret_code == 0:
    print("All tests passed")

sys.exit(ret_code)
