#!/usr/bin/env python -i

import os
import sys

# The block of code is only needed when you want to run the
# development version of metar.  Add metar bin folder containing the
# metar.so file to the path so it is imported.
absolute_path = os.path.abspath(__file__)
parent_dir = os.path.dirname(os.path.dirname(absolute_path))
path = os.path.join(parent_dir, "bin")
assert(os.path.exists(os.path.join(path, "metar.so")))
sys.path.insert(0, path)

