# Package

version       = "0.1.0"
author        = "Steve Flenniken"
description   = "Metadata Reader for Images"
license       = "MIT"

# Dependencies

requires "nim >= 0.17.0"

srcDir = "src"
binDir = "bin"
skipDirs = @["tests", "docs", "private"]

task build_metar, "Build and run metar":
  exec "nim c -r --out:metar src/metar"

task test_metar, "Runs test_metar":
  exec "nim c -r --out:bin/test_metar tests/test_metar"

task test_readMetadata, "Runs test_readMetadata":
  exec "nim c -r --out:bin/test_readMetadata tests/test_readMetadata"

task docs, "Build all the docs":
  exec "nim doc --out:docs/metar.html src/metar.nim"
  exec "nim doc --out:docs/readMetadata.html src/metar/readMetadata.nim"

task tree, "Show the directory tree":
  exec "tree -I '*~|nimcache'"

task hello, "This is a hello task":
  echo("Hello World!")
