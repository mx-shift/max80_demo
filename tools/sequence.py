#!/usr/bin/env python3
"""Write the demo's sequence of pictures for racegen.py.

Usage: sequence.py PICSDIR > seq.txt

The spinning sphere, each picture for 2 frames (30 a second), round 20
times, about 9 seconds with 14 pictures.
"""
import glob
import os
import sys

pics = sys.argv[1]
spin = sorted(os.path.basename(p) for p in glob.glob(os.path.join(pics, 'spin*.pbm')))
# no still: the spin right after it made it pointless
for _ in range(20):
    for p in spin:
        print(p, 2)
