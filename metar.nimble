import os
import strutils

# https://github.com/nim-lang/nimble#nimble-reference

# Include the metar version number.
include metar/version

version = metarVersion
author = "Steve Flenniken"
description = "Metadata Reader for Images"
license = "MIT"
binDir = "bin"
requires "nim >= 2.2.4"
bin = @["metar/metar"]
