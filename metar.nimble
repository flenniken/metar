import strutils

# https://github.com/nim-lang/nimble#nimble-reference

# Include the metar version number.
include metar/version

version = metarVersion
author = "Steve Flenniken"
description = "Metadata Reader for Images"
license = "MIT"
binDir = "bin"

requires "nim >= 0.19.0"

skipExt = @["nim"]
# skipDirs = @["tests", "private"]


proc git_bin_folder(debug: bool=false): string =
  ## Return the folder to store the binaries dependent on the
  ## platform.
  when hostOS == "macosx":
    if debug:
      result = "bin/mac/debug"
    else:
      result = "bin/mac"
  elif hostOS == "linux":
    if debug:
      result = "bin/linux/debug"
    else:
      result = "bin/linux"
  else:
    error("add new platform")


proc build_metar_and_python_module(ignoreOutput = false) =
  var ignore: string
  if ignoreOutput:
    ignore = ">/dev/null 2>&1"
  else:
    ignore = ""

  let output = git_bin_folder()
  exec r"rm -f $1/metar" % [output]
  exec r"rm -f $1/metar.so" % [output]
  exec r"nim c --out:$1/metar -d:release metar/metar $2" % [output, ignore]
  exec r"find . -name \*.pyc -delete"
  exec r"nim c -d:buildingLib -d:release --threads:on --tlsEmulation:off --app:lib --out:$1/metar.so metar/metar $2" % [output, ignore]
  exec r"strip $1/metar" % [output]
  exec r"strip -x $1/metar.so" % [output]


task m, "Build metar exe and python module":
  build_metar_and_python_module()

# task md, "Build debug version of metar and python module":
#   let output = git_bin_folder(debug=true)
#   exec r"nim c --out:$1/metar metar/metar" % [output]
#   exec r"find . -name \*.pyc -delete"
#   # The python shared lib must be the same name as the nim module.
#   exec r"nim c -d:buildingLib --debugger:native --threads:on --tlsEmulation:off --app:lib --out:$1/metar.so metar/metar " % [output]

task md, "Build debug version of metar":
  let output = git_bin_folder(debug=true)
  exec r"rm -f $1/metar" % [output]
  exec r"nim c -d:nimTypeNames --out:$1/metar metar/metar" % [output]

task mdlib, "Build debug version of the python module":
  let output = git_bin_folder(debug=true)
  exec r"rm -f $1/metar.so" % [output]
  exec r"find . -name \*.pyc -delete"
  exec r"nim c -d:buildingLib -d:nimTypeNames --threads:on --tlsEmulation:off --app:lib --out:$1/metar.so metar/metar " % [output]

proc test_module(filename: string, release = false): string =
  ## Test one module.
  const cmd = "nim c --verbosity:0 -d:test $2 --hints:off -r --out:bin/$1 tests/$1"
  if release:
    result = (cmd % [filename, "-d:release"])
  else:
    result = (cmd % [filename, ""])

proc get_test_filenames(): seq[string] =
  ## Return each nim file in the tests folder.
  exec "find tests -maxdepth 1 -type f -name \\*.nim | sed 's/tests\\///' | sed 's/.nim//' >testfiles.txt"
  let text = slurp("testfiles.txt")
  result = @[]
  for filename in text.splitLines():
    if filename.len > 0:
      result.add(filename)
  exec "rm -f testfiles.txt"

proc runShellTests() =
  echo ""
  echo "\e[1;34m[Suite] \e[00mShell Tests"
  exec "bash -c tests/test_shell.sh"

proc runTests(release: bool) =
  ## Test each nim file in the tests folder.
  for filename in get_test_filenames():
    let source = test_module(filename, release)
    exec source

  # Build the python module and run its tests.
  build_metar_and_python_module(true)
  echo ""
  echo "\e[1;34m[Suite] \e[00mTest Python Module\n"
  # echo "\e[1;32m    [OK] \e[00mtest getAppeInfo\n"
  exec "python python/test_metar.py"

  runShellTests()


# task mp, "Make python module only.":
#   let output = git_bin_folder()
#   exec r"nim c -d:buildingLib -d:release --opt:size --threads:on --tlsEmulation:off --app:lib --out:%1/metar.so metar/metar " % [output]


# task mpdb, "Make python module with debug info":
#   let output = git_bin_folder(debug=true)
#   exec r"nim c -d:buildingLib  --debugger:native --verbosity:0 --hints:off --threads:on --tlsEmulation:off --app:lib --out:$1/metar.so metar/metar " % [output]
#   echo "You can debug the python shared lib like this:"
#   echo "lldb -- /usr/bin/python python/example.py"
#   echo "process launch"
#   echo "breakpoint set -f metar.nim -l 91"
#   echo "breakpoint set -f readMetadata.nim -l 60"
#   echo "continue"
#   echo "see \"lldb debugger\" note for more info."


# task py, "Run python tests":
#   exec r"find . -name \*.pyc -delete"
#   exec "python python/test_metar.py"


# task shell, "Run tests from the shell":
#   echo "building metar and python module"
#   build_metar_and_python_module(true)
#   runShellTests()


task test, "Run all the tests in debug":
  runTests(false)

task testr, "Run all the tests in release":
  runTests(true)

task showtests, "Show command line to run tests":
  for filename in get_test_filenames():
    let source = test_module(filename)
    echo source
  echo ""
  echo "Run one test like this:"
  let source = test_module("test_metar.nim")
  echo source & """ "happy path""""

# Is there a way to pass a filename?
# task one, "Test the test_readerJpeg file.":
#   test_module("test_readerJpeg")

task clean, "Delete unneed files":
  # ## Delete binary files in the test dir (files with no extension).
  # exec "find tests -type f ! -name \"*.*\" | xargs rm"

  # # # Delete binary files in the metar dir (files with no extension).
  # exec "find metar -type f ! -name \"*.*\" | xargs rm"

  # Delete files generated by dot.
  exec "rm -f metar/metar.deps"
  exec "rm -f metar/metar.dot"
  exec "rm -f metar/my.dot"
  exec "rm -f metar/metar.png"
  exec "rm -f testfiles.txt"
  exec "rm -f docfiles.txt"
  exec "rm -f names.txt"

  # Delete files generated by coverage.
  exec "rm -f coverage.info"
  exec "rm -fr metar/coverage"
  exec r"find tests -type f -perm +001 | grep -v '\.' | xargs rm"
  
  exec "rm -f docs/*.json"

  # Delete unneeded files in bin folder.
  exec "rm -f bin/test_*"
  exec "rm -f bin/metar*"
  exec "rm -f bin/metar.so*"


proc doc_module(name: string) =
  const cmd = "nim doc0 --index:on --out:docs/html/$1.html metar/$1.nim"
  let source = cmd % name
  exec source

task docs, "Build all the docs":

  exec "find metar -type f -name \\*.nim | grep -v metar/private | sed 's;metar/;;' | grep -v '^private' | sed 's/.nim//' >docfiles.txt"
  let fileLines = slurp("docfiles.txt")
  for filename in fileLines.splitLines():
    if filename.len > 0:
      # echo filename
      doc_module(filename)
  exec "rm docfiles.txt"

  exec "nim buildIndex --out:docs/html/theindex.html docs/html/"
  exec "nim rst2html --out:docs/html/main.html docs/main.rst"
  exec "rm docs/html/*.idx"
  exec "open docs/html/main.html"

task tree, "Show the project directory tree":
  exec "tree -I '*~|nimcache'"

task t, "Build and run t.nim":
  let cmd = "nim c -r -d:release --out:bin/t metar/private/t"
  echo cmd
  exec cmd

task tlib, "Build t python library":
  # Note the nim and the lib name must match, for example: t.so and t.nim.
  # tlib.so and t.nim results in the error:
  # ImportError: dynamic module does not define init function (inittlib)
  exec r"nim c --app:lib --out:bin/t.so metar/private/t"
  exec r"python python/test.py"


# task t2, "Build and run t2.nim":
#   exec "nim c -r --out:bin/t2 metar/private/t2"

task coverage, "Run code coverage of tests":

  # Running one module and its test file at a time works.

  var test_filenames = get_test_filenames()
  # var test_filenames = ["test_readMetadata"]

  # Compile test code with coverage support.
  for filename in test_filenames:
    echo "compiling: " & filename
    exec "nim --verbosity:0 --hints:off -d:test --debugger:native --passC:--coverage --passL:--coverage c tests/" & filename

  exec "lcov --base-directory . --directory ~/.cache/nim/ --zerocounters -q"

  # Run test code.
  for filename in test_filenames:
    exec "tests/" & filename

  exec "lcov --base-directory . --directory ~/.cache/nim/ -c -o coverage.info"

  # Remove Nim system libs from the coverage info.
  exec "lcov --remove coverage.info \"*/lib/*\" -o coverage.info"

  exec "genhtml -o metar/coverage/html coverage.info"
  exec "open metar/coverage/html/index.html"


task dot, "Show dependency graph":
  exec "nim genDepend metar/metar.nim"
  # Create my.dot file with the contents of metar.dot after stripping
  # out nim modules.
  exec """find metar -maxdepth 1 -name \*.nim | sed "s:metar/::" | sed "s:.nim::" >names.txt"""
  exec "python python/dotMetar.py names.txt metar/metar.dot >metar/my.dot"
  exec "dot -Tsvg metar/my.dot -o bin/dependencies.svg"
  exec "open -a Firefox bin/dependencies.svg"

  # You can set the border color like this:
  # macros [color = red];
  # strutils [color = red];
  # json [color = red];
  # tables [color = red];

  # Set the line color to blue:
  # abc -> def [color = blue]

  # Set the arrowhead shape:
  # abc -> def [arrowhead = diamond]

  # find all files in the project and set their color blue.
  # find metar -maxdepth 1 -name \*.nim | sed 's%metar/%%' | sed 's/.nim/ [color blue]/'

  # Make a dotted line.
  # version -> ver [style = dotted]
  # metar -> ver [style = dotted]


task showtestfiles, "Show command line to debug code":
  echo ""
  echo "Common switches:"
  echo "  nimswitches='c --debugger:native --verbosity:0 --hints:off'"
  echo ""

  echo "Compile test_readerJpeg with debugging info:"
  echo "  nim $nimswitches --out:bin/test_readerJpeg tests/test_readerJpeg.nim"
  echo ""

  echo "Compile metar with debugging info:"
  echo "  nim $nimswitches --out:bin/metar metar/metar.nim"
  echo ""
  echo "Launch metar with the debugger:"
  echo "  lldb bin/metar testfiles/image.jpg"
  echo ""

task jsondoc, "Write doc comments to a json file for metar.nim":
  exec r"nim jsondoc0 --out:docs/metar.json metar/metar"
  exec "open -a Firefox docs/metar.json"

task jsondoct, "Write doc comments to a json file for t.nim":
  exec r"nim jsondoc0 --out:docs/tdoc0.json metar/private/t"
  exec r"nim jsondoc --out:docs/tdoc.json metar/private/t"
  exec "open -a Firefox docs/tdoc.json"

# The metar image is called metar_image
# The container is called metar_container

task create, "Create a metar docker image.":
  exec r"docker build -t metar-image ."

task run, "Run the metar docker container.":
  exec r"./run-metar-container.sh"

task ddelete, "Delete the metar docker container.":
  try:
    exec r"docker stop metar-container; docker rm metar-container"
  except:
    discard

task dlist, "List the metar docker image and container.":
  try:
    exec r"echo 'image:';docker images | grep metar-image ; echo '\ncontainer:';docker ps -a | grep metar-container"
  except:
    discard
