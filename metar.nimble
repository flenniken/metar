import strutils

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

proc test_module(name: string) =
  const cmd = "nim c --verbosity:0 --hints:off -r --out:bin/$1 tests/$1"
  let source = (cmd % [name])
  exec source

task test_all, "test all":
  test_module("test_metar")
  test_module("test_readMetadata")

proc doc_module(name: string) =
  const cmd = "nim doc --out:docs/$1.html metar/$1.nim"
  let source = cmd % name
  exec source

task docs, "Build all the docs":
  doc_module("metar")
  doc_module("readMetadata")
  doc_module("readerJpeg")
  doc_module("readerDng")
  doc_module("readerTiff")
  doc_module("metadata")

task tree, "Show the directory tree":
  exec "tree -I '*~|nimcache'"

task runt, "Build and run t.nim":
  exec "nim c -r --out:bin/t metar/private/t"

task hello, "This is a hello task":
  echo("Hello World!")

task dot, "Show dependencies":
  exec "nim genDepend metar/metar.nim"
  exec "dot -Tpng metar/metar.dot -o bin/dependencies.png"
  exec "rm metar/metar.deps"
  exec "rm metar/metar.dot"
  exec "rm metar/metar.png"
  exec "open bin/dependencies.png"
