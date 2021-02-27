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

# The nimpy package is required for the library module but not the
# exe.  Nimpy does not update the its version number, its always at
# 0.1.0. So we use the git version number instead. See the package
# source code at ~/.nimble/pkgs. Update the version.nim file and the
# Dockerfile when you update the version.
requires "nim >= 1.0.4", "nimpy#c8ec14a" # Search for nimpyVersion*.

bin = @["metar/metar"]
# skipExt = @["nim"]
# skipDirs = @["tests", "private"]


proc getDirName(host: string): string =
  ## Return the host dir name given the nim hostOS name.
  ## Current possible host values: "windows", "macosx", "linux", "netbsd",
  ## "freebsd", "openbsd", "solaris", "aix", "haiku", "standalone".

  if host == "macosx":
    result = "mac"
  elif host == "linux":
    result = "linux"
  elif host == "windows":
    result = "win"
  else:
    assert false, "add a new platform"


proc get_output_path(host: string, baseName: string="", release: bool=true): string =
  ## Return the path to a folder or file for the output binaries. The
  ## path is dependent on the host platform and whether it is a debug
  ## or release build.  Pass hostOS for the current platform. Pass a
  ## baseName to get a full path to the file.

  var dirName = getDirName(host)

  var components = newSeq[string]()
  components.add("bin")
  components.add(dirName)
  if not release:
    components.add("debug")
  if baseName != "":
    components.add(baseName)
  result = joinPath(components)


proc build_metar_and_python_module(host = hostOS, name = "metar", libName = "metar.so",
    ignoreOutput = false, release = true, strip = true, xcompile = false,
    nimOptions = "", buildExe=true, buildLib=true) =

  let hints = "--hint[Processing]:off --hint[CC]:off --hint[Link]:off --hint[Conf]:off "

  var ignore: string
  if ignoreOutput:
    ignore = ">/dev/null 2>&1"
  else:
    ignore = ""

  var rel: string
  var relDisplay: string
  if release:
    rel = "-d:release "
    relDisplay = "release"
  else:
    rel = ""
    relDisplay = "debug"

  var docker: string
  if xcompile:
    docker = "docker run --rm -v `pwd`:/usr/local/src xcompile "
  else:
    docker = ""

  if buildExe:
    let output = get_output_path(host, name, release)
    echo "===> Building Command Line Exe $1 $2 for $3 <===" % [relDisplay, name, host]
    exec r"rm -f $1" % [output]

    let cmd = "$5nim c $2--out:$1 $3$6$4metar/metar" % [output, rel, nimOptions, ignore, docker, hints]
    echo cmd
    exec cmd

    if strip:
      exec r"strip $1" % [output]

  if buildLib:
    let output = get_output_path(host, libName, release)
    echo "===> Building Python Lib $1 $2 for $3 <===" % [relDisplay, libName, host]
    exec r"rm -f $1" % [output]

    var cmd = "$5nim c $2--out:$1 $3-d:buildingLib --app:lib $6metar/metar $4" % [output, rel, nimOptions, ignore, docker, hints]
    echo cmd
    exec cmd

    # Put the setup file next to the lib ready to install.
    var dirName = getDirName(host)
    let setupFilename = "bin/$1/setup.py" % [dirName]
    # if not system.fileExists(setupFilename):
    cmd = r"cp python/setup.py $1" % [setupFilename]
    echo cmd
    exec cmd

    exec r"find . -name \*.pyc -delete"

    if strip:
      exec r"strip -x $1" % [output]

proc createDependencyGraph() =
  # Create my.dot file with the contents of metar.dot after stripping
  # out nim modules.
  exec "nim --hints:off genDepend metar/metar.nim"
  exec """find metar -maxdepth 1 -name \*.nim | sed "s:metar/::" | sed "s:.nim::" >names.txt"""
  exec "python python/dotMetar.py names.txt metar/metar.dot >metar/my.dot"
  exec "dot -Tsvg metar/my.dot -o docs/html//dependencies.svg"

task t, "Show the list of tasks.":
  exec "nimble tasks"

task m, "Build metar exe and python module, release versions.":
  build_metar_and_python_module()

task mall, "Build metar exe and python module both debug and release.":
  build_metar_and_python_module()
  build_metar_and_python_module(release=false)


task md, "Build debug version of metar.":
  build_metar_and_python_module(buildLib=false, release=false)


task mdlib, "Build debug version of the python module.":
  build_metar_and_python_module(buildExe=false, release=false)

task pipinstall, "Install the release python metar module in the virtual env.":
    # Install the version just built in the virtual environment.
    var cmd = "pip3 install bin/linux"
    echo cmd
    exec cmd

proc get_test_module_cmd(filename: string, release = false): string =
  ## Return the command line to test one module.

  # You can add -f to force a recompile of imported modules, good for
  # testing "imported but not used" warnings.

  var rel: string
  if release:
    rel = "-d:release "
  else:
    rel = ""
  result = "nim c -f --verbosity:0 -d:test $2--hints:off -r -p:metar --out:bin/test/$1 tests/$1" % [filename, rel]

proc get_test_filenames(): seq[string] =
  ## Return each nim file in the tests folder.
  exec "find tests -maxdepth 1 -type f -name \\*.nim | sed 's/tests\\///' | sed 's/.nim//' >testfiles.txt"
  let text = slurp("testfiles.txt")
  result = @[]
  for filename in text.splitLines():
    if filename.len > 0:
      result.add(filename)
  exec "rm -f testfiles.txt"

proc runShellTests(release: bool) =
  echo ""
  echo "\e[1;34m[Suite] \e[00mShell Tests"
  if release:
    exec "bash -c \"tests/test_shell.sh release\""
  else:
    exec "bash -c tests/test_shell.sh"

proc testPython() =
  ## Test the python module.
  echo ""
  echo "\e[1;34m[Suite] \e[00mTest Python Module\n"

  var result = gorgeEx("hash python3 2>/dev/null")
  if result.exitCode != 0:
    echo "Skipping because python3 does not exist."
  else:
    exec "python3 python/test_metar.py"

proc runTests(release: bool) =
  var relDisplay: string
  if release:
    relDisplay = "release"
  else:
    relDisplay = "debug"
  echo "==> Run $1 unit tests. <==" % [relDisplay]

  runShellTests(release)
  testPython()

  ## Test each nim file in the tests folder.
  for filename in get_test_filenames():
    let cmd = get_test_module_cmd(filename, release)
    exec cmd

task testpython, "Test the python module.":
  testPython()


# task args, "Show command line arguments.":
#   # Nimble needs to improve it command line processing.
#   # https://github.com/nim-lang/nimble/issues/723
#   # todo: pass arguments to the tasks.
#   let count = system.paramCount()+1
#   echo "argument count: $1" % $count
#   for i in 0..count-1:
#     echo "$1: $2" % [$i, system.paramStr(i)]


task test, "Run all the tests in debug.":
  runTests(false)

task testall, "Run all the tests in both debug and release.":
  runTests(false)
  runTests(true)

task showtests, "Show the command lines to run unit tests individually.":
  for filename in get_test_filenames():
    let cmd = get_test_module_cmd(filename)
    echo cmd
  echo ""
  echo "Run one test called \"happy path\" in the moduled test_metar:"
  let cmd = get_test_module_cmd("test_metar.nim")
  echo cmd & """ "happy path""""

task clean, "Delete unneeded temporary files created by the build processes.":
  # ## Delete binary files in the test dir (files with no extension).
  # exec "find tests -type f ! -name \"*.*\" | xargs rm"

  # # # Delete binary files in the metar dir (files with no extension).
  # exec "find metar -type f ! -name \"*.*\" | xargs rm"

  # Delete files generated by dot.
  exec "rm -f metar.deps"
  exec "rm -f metar/metar.deps"
  exec "rm -f metar/metar.dot"
  exec "rm -f metar/my.dot"
  exec "rm -f metar/metar.png"
  # exec "rm -f metar_*.nims"
  exec "rm -f testfiles.txt"
  exec "rm -f docfiles.txt"
  exec "rm -f names.txt"

  # Delete files generated by coverage.
  exec "rm -f coverage.info"
  exec "rm -fr metar/coverage"
  # exec r"find tests -type f -perm +001 | grep -v '\.' | xargs -r rm"

  exec "rm -f docs/*.json"

  # Delete unneeded files in bin folder.
  exec "rm -f bin/test/test_*"
  exec "rm -f bin/metar*"
  exec "rm -f bin/metar.so*"

  # Delete ~ files
  exec r"find . -type f -name \*~ -delete"

  exec "rm -f readme.html"
  # exec "rm -f *.nims"

  exec "rm -f tshell.txt"

  exec "rm -f .DS_Store"
  exec "rm -f docs/.DS_Store"



proc doc_module(name: string) =
  let cmd = "nim doc --hints:off -d:test --index:on --out:docs/html/$1.html metar/$1.nim" % [name]
  echo cmd
  exec cmd

proc open_in_browser(filename: string) =
  ## Open the given file in a browser if the system has an open command.
  exec "(hash open 2>/dev/null && open $1) || echo 'open $1'" % filename

# pandoc works as well.
# task docp, "Build project.md document":
#   exec "pandoc docs/project.md -o docs/html/project.html"
#   open_in_browser("docs/html/project.html")

# task docp, "Build project.md document":
#   exec "markdown docs/project.md -o docs/html/project.html"
#   open_in_browser("docs/html/project.html")


proc buildMainDocs() =
  exec "nim rst2html --hints:off --out:docs/html/main.html docs/main.rst"
  exec "nim rst2html --hints:off --out:docs/html/project.html docs/project.rst"
  exec "nim rst2html --hints:off --out:readme.html readme.rst"
  exec "nim buildIndex --hints:off -d:test --out:docs/html/theindex.html docs/html/"
  exec "rm docs/html/*.idx"
  createDependencyGraph()
  # Open the main.html file in a browser when the open command exists.
  # exec "(hash open 2>/dev/null && open docs/html/main.html) || echo 'open docs/html/main.html'"
  open_in_browser("readme.html")


task docs1, "Build docs for one module.":
  doc_module("hexDump")
  buildMainDocs()


task docs, "Build all the docs.":
  exec "find metar -type f -name \\*.nim | grep -v metar/private | sed 's;metar/;;' | grep -v '^private' | sed 's/.nim//' >docfiles.txt"
  let fileLines = slurp("docfiles.txt")
  for filename in fileLines.splitLines():
    if filename.len > 0:
      # echo filename
      doc_module(filename)
  exec "rm docfiles.txt"

  buildMainDocs()


task tree, "Show the project directory tree.":
  exec "tree -I 'metarenv|private|testfiles.extra|*.nims' | less"

task bins, "Show the binary file details.":
  exec r"find bin -name metar\* -type f | xargs ls -l"

# task t, "Build and run t.nim.":
#   let cmd = "nim c -r -d:release --out:bin/test/t metar/private/t"
#   echo cmd
#   exec cmd

# task tlib, "Build t python library":
#   # Note the nim and the lib name must match, for example: t.so and t.nim.
#   # tlib.so and t.nim results in the error:
#   # ImportError: dynamic module does not define init function (inittlib)
#   exec r"nim c --app:lib --out:bin/test/t.so metar/private/t"
#   exec r"python python/test.py"


# task t2, "Build and run t2.nim":
#   exec "nim c -r --out:bin/test/t2 metar/private/t2"

task coverage, "Run unit tests to collect and show code coverage data.":

  var test_filenames = newSeq[string]()
  if true:
    # Run one module and its test file. Replace module name as needed.
    test_filenames.add("test_readerJpeg.nim")
  else:
    test_filenames = get_test_filenames()

  # Compile test code with coverage support.
  for filename in test_filenames:
    echo "compiling: " & filename
    var baseName = changeFileExt(filename, "")
    var command = "nim c --verbosity:0 -d:test --hints:off -p:metar --out:bin/test/$1 --debugger:native --passC:--coverage --passL:--coverage tests/$2" % [baseName, filename]
    echo command
    exec command

  exec "lcov --base-directory . --directory ~/.cache/nim/ --zerocounters -q"

  # Run test code.
  for filename in test_filenames:
    let baseName = changeFileExt(filename, "")
    let cmd = "bin/test/$1" % [baseName]
    echo cmd
    exec cmd

  # Delete the system files since we do not care about their coverage data.
  exec r"find ~/.cache/nim -name stdlib\*gcda -delete"

  # Collect the coverate info.
  exec r"lcov --base-directory . --directory ~/.cache/nim/ -c -o coverage.info"

  # Remove Nim system libs from the coverage info.
  # exec r"lcov --remove coverage.info \"*/lib/*\" -o coverage.info"

  # Generate the html from the coverage info.
  exec r"genhtml -o metar/coverage/html coverage.info"
  open_in_browser(r"metar/coverage/html/index.html")


task dot, "Create and show the metar modules dependency graph.":
  createDependencyGraph()
  exec "open -a Firefox docs/html/dependencies.svg"

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


task showdebugger, "Show example command line to debug code with lldb.":
  echo ""
  echo "Common switches:"
  echo "  nimswitches='c --debugger:native --verbosity:0 --hints:off'"
  echo ""

  echo "Compile test_readerJpeg with debugging info:"
  echo "  nim $nimswitches --out:bin/test/test_readerJpeg tests/test_readerJpeg.nim"
  echo ""

  echo "Compile metar with debugging info:"
  echo "  nim $nimswitches --out:bin/test/metar metar/metar.nim"
  echo ""
  echo "Launch metar with the debugger:"
  echo "  lldb bin/linux/metar testfiles/image.jpg"
  echo ""

# task jsondoc, "Write doc comments to a json file for metar.nim.":
#   exec r"nim jsondoc0 --out:docs/metar.json metar/metar"
#   exec "open -a Firefox docs/metar.json"

# task jsondoct, "Write doc comments to a json file for t.nim.":
#   exec r"nim jsondoc0 --out:docs/tdoc0.json metar/private/t"
#   exec r"nim jsondoc --out:docs/tdoc.json metar/private/t"
#   exec "open -a Firefox docs/tdoc.json"

# The metar image is called metar_image
# The container is called metar_container

task dcreate, "Create a metar linux docker image.":
  exec r"docker build -t metar-image env/linux/."

task drun, "Run the metar linux docker container.":
  exec r"./env/run-metar-container.sh"

task ddelete, "Delete the metar linux docker container.":
  try:
    exec r"docker stop metar-container; docker rm metar-container"
  except:
    discard

task dlist, "List the metar linux docker image and container.":
  try:
    exec r"echo 'image:';docker images | grep metar-image ; echo '\ncontainer:';docker ps -a | grep metar-container"
  except:
    discard

task mxwin, "Compile for windows 64 bit using the xcompile docker image.":

  build_metar_and_python_module(host = "windows", name = "metar.exe", libName = "metar.dll", release = true, strip = false, nimOptions = "--os:windows --cpu:amd64 ", xcompile = true)

task mxmac, "Compile for mac 64 bit using the xcompile docker image.":

  build_metar_and_python_module(host = "macosx", name = "metar", libName = "metar.so", release = true, strip = false, nimOptions = "--os:macosx --cpu:amd64 ", xcompile = true)

task mxlinux, "Compile for linux 64 bit using the xcompile docker image.":

  build_metar_and_python_module(host = "linux", name = "metar", libName = "metar.so", release = true, strip = true, nimOptions = "--os:linux --cpu:amd64 ", xcompile = true)

task pyactivate, "Activate the python virtual env.  Create it when missing.":
  var dirName = getDirName(hostOS)
  let virtualEnv = "env/$1/metarenv" % dirName
  if system.dirExists(virtualEnv):
    if system.getEnv("VIRTUAL_ENV", "") == "":
      var cmd = ". $1/bin/activate" % [virtualEnv]
      echo "run:"
      echo cmd
  else:
    echo "Creating virtual environment: $1" % [virtualEnv]
    var cmd = "python3 -m venv $1" % [virtualEnv]
    echo cmd
    exec cmd
    cmd = "source $1/bin/activate" % [virtualEnv]
    echo cmd
    exec cmd
    cmd = "pip3 install wheel"
    echo cmd
    exec cmd
