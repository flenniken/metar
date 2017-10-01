
# https://github.com/nim-lang/nimble#nimble-reference

# Include the version number.
include metar/ver

author = "Steve Flenniken"
description = "Metadata Reader for Images"
license = "MIT"
binDir = "bin"

requires "nim >= 0.17.0"

skipExt = @["nim"]
# skipDirs = @["tests", "private"]

task m, "Build and run metar":
  exec "nim c -r --out:bin/metar metar/metar"

# Run all the tests with "nimble test" but it puts binaries in the wrong place.

task test_all, "test all":
  exec "nim c -r --out:bin/test_metar tests/test_metar"
  exec "nim c -r --out:bin/test_readMetadata tests/test_readMetadata"
  exec "nim c -r --out:bin/version.nim metar/version.nim"

# task test_readMetadata, "test readMetadata":
#   exec "nim c -r --out:bin/test_readMetadata tests/test_readMetadata"

# task test_version, "test version":
#   exec "nim c -r --out:bin/version.nim metar/version.nim"

task docs, "Build all the docs":
  exec "nim doc --out:docs/metar.html metar/metar.nim"
  exec "nim doc --out:docs/readMetadata.html metar/readMetadata.nim"

task tree, "Show the directory tree":
  exec "tree -I '*~|nimcache'"

task runt, "Build and run t.nim":
  exec "nim c -r --out:bin/t metar/private/t"

task hello, "This is a hello task":
  echo("Hello World!")
