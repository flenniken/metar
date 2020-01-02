=================
Metar Development
=================

You develop metar on the Mac or Linux using nim, nimble and other programs.

* [Nimble Tasks](#nimble-tasks)
* [Platforms](#platforms)
* [Install](#install)
* [Build](#build)
* [Test](#test)
* [Docs](#docs)
* [Python Install](#python-install)

Nimble Tasks
=================

You run the build, test and perform many other tasks with nimble.

Note: It's suggested you create an alias n to run nimble to save typing.

You can list all the tasks running nimble's tasks command::

```
  nimble tasks

  m            Build metar exe and python module, release versions
  mall         Build metar exe and python module both debug and release
  md           Build debug version of metar
  mdlib        Build debug version of the python module
  test         Run all the tests in debug
  testall      Run all the tests in both debug and release
  showtests    Show the command lines to run unit tests individually
  clean        Delete unneeded files
  docs1        Build docs for one module
  docs         Build all the docs
  tree         Show the project directory tree
  t            Build and run t.nim
  coverage     Run unit tests to collect and show code coverage data
  dot          Create and show the metar modules dependency graph
  showdebugger Show example command line to debug code
  dcreate      Create a metar linux docker image.
  drun         Run the metar linux docker container.
  ddelete      Delete the metar linux docker container.
  dlist        List the metar linux docker image and container.
  mxwin        Compile for windows 64 bit using the xcompile docker image.
  mxmac        Compile for mac 64 bit using the xcompile docker image.
  mxlinux      Compile for linux 64 bit using the xcompile docker image.

```

Prerequisites
=================

You need nim and docker to build metar.

* `Install Nim <https://nim-lang.org/install.html>`_
* `Docker <https://docs.docker.com/>`_

::

  docker --version
  Docker version 19.03.4, build 9013bf5

  nim --version | head -1
  Nim Compiler Version 1.0.4 [MacOSX: amd64]


Platforms
=================

Metar is developed and tested on two platforms, mac and
linux (Debian). It is cross compiled for Windows.

### Mac

I use the mac to host docker and to share the metar source code
with the linux docker system.

### Linux

There are nimble tasks manage the linux Docker environment. They are
the tasks at the bottom that start with "d".

```
  dcreate      Create a metar linux docker image.
  drun         Run the metar linux docker container.
  ddelete      Delete the metar linux docker container.
  dlist        List the metar linux docker image and container.
```

### Windows

You can cross compile for Windows using the xcompile docker image
using the mxwin nimble task.


Install
=================

Install the source into a folder on your machine using git.

::

  mkdir -p ~/code/metar
  cd ~/code/metar
  git clone https://github.com/flenniken/metar.git .


Build
=================
You build metar using the m nimble task.  This builds the release
version of the exe and python library.

::
  cd ~/code/metar
  nimble m

  Executing task m in /Users/steve/code/testm/metar.nimble
  ===> Building release metar for macosx <===
  nim c -d:release --out:bin/mac/metar --hint[Processing]:off --hint[CC]:off --hint[Link]:off metar/metar
  Hint: used config file '/Users/steve/.choosenim/toolchains/nim-1.0.4/config/nim.cfg' [Conf]
  Hint: operation successful (49154 lines compiled; 3.104 sec total; 89.488MiB peakmem; Release Build) [SuccessX]
  ===> Building release metar.so for macosx <===
  nim c -d:release --out:bin/mac/metar.so -d:buildingLib --app:lib --hint[Processing]:off --hint[CC]:off --hint[Link]:off metar/metar
  Hint: used config file '/Users/steve/.choosenim/toolchains/nim-1.0.4/config/nim.cfg' [Conf]
  Hint: operation successful (52877 lines compiled; 3.087 sec total; 89.445MiB peakmem; Release Build) [SuccessX]

The binary files are stored in the bin folder as shown below.

::

  n bins
    Executing task bins in /Users/steve/code/metar/metar.nimble
  -rwxr-xr-x  1 steve  staff  297156 Dec 31 14:33 bin/mac/metar
  -rwxr-xr-x  1 steve  staff  332868 Dec 31 14:33 bin/mac/metar.so

  bin/mac/metar --version
  0.1.22

Test
=================

You can run the unit tests for the debug version using the nimble
test command or for both debug and release using the testall command.

::

  nimble test

  Executing task test in /Users/steve/code/metar/metar.nimble
  ==> Run debug unit tests. <==

  [Suite] Shell Tests
    Skipping: metar exe is missing: bin/mac/debug/metar

  [Suite] Test imageData
    [OK] test newImageData
    [OK] test newImageData2
    [OK] test ImageData to string
    [OK] test newImageData merge
    [OK] test newImageData error
    [OK] test newImageData nil
    [OK] test createImageNode
    [OK] test createImageNode no width
    [OK] test createImageNode no height
    [OK] test createImageNode missing
    [OK] test toString

  [Suite] Test hexDump.nim
    [OK] test hexDump
    [OK] test hexDump 17
    ...


Create Python Environment
=================

Create a python virtual environment for working with metar python
library, then activate it. Your prompt will be prefixed with
(metarpy) showing that it is the active environment.

::

  cd ~/code/metar
  python3 -m venv metarpy
  source metarpy/bin/activate

  (metarpy) ~/code/metar $

Python Install
=================

Install metar in the virtual environment using pip. The freeze
command shows the installed custom packages, in this case metar.

todo: make pip installer work.

::
   cd ~/code/metar
   pip install python/metar
   pip freeze

   metar==0.1.22


You can test run metar:

::
  python
  >>> import metar
  >>> metar.get_version()
  1.22.0
  >>> exit()

  pip freeze
  metar==0.1.22

Uninstall metar using pip:

::
  pip uninstall -y metar

Stop using the virtual python environment using the deactivate
command:

::
   deactivate

Remove the virtual environment by deleting the metarpy folder.

::
   cd ~/code/metar
   rm -r metarpy



Docs
=================

The module and procedure documention is created by extracting
comments from the modules.
