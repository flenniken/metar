
version       = "0.1.0"
author        = "Steve Flenniken"
description   = "Metadata Reader for Images"
license       = "MIT"

requires "nim >= 0.17.0"

#srcDir = "src"
skipDirs = @["tests", "docs", "private"]

task m, "Build and run metar":
  exec "nim c -r --out:bin/metar metar/metar"

task testm, "test metar":
  exec "nim c -r --out:bin/test_metar tests/test_metar"

task test_readMetadata, "test readMetadata":
  exec "nim c -r --out:bin/test_readMetadata tests/test_readMetadata"

task docs, "Build all the docs":
  exec "nim doc --out:docs/metar.html metar/metar.nim"
  exec "nim doc --out:docs/readMetadata.html metar/readMetadata.nim"

task tree, "Show the directory tree":
  exec "tree -I '*~|nimcache'"

task runt, "Build and run t.nim":
  exec "nim c -r --out:bin/t metar/private/t"

task hello, "This is a hello task":
  echo("Hello World!")
