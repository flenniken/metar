=================
Metar Development
=================

You develop metar on the Mac or Linux using nim, nimble and other programs.

* `Nimble Tasks`_
* `Platforms`_
* `Install`_
* `Build`_
* `Test]`_
* `Docs]`_
* `Python Install`_

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

Metar is developed and tested on mac and linux (Debian) and is
cross compiled for Windows.

I use the mac to host docker. Docker containers are used to build
the linux and windows versions. You could probably host on linux
without much trouble. Hosting on Windows has issues since the nimble
tasks use unix commands and paths.

The host file system contains the code and the docker containers
share the same files.

There are nimble tasks manage the linux Docker environment. They appear
near the bottom of the list and start with "d".

```
  dcreate      Create a metar linux docker image.
  drun         Run the metar linux docker container.
  ddelete      Delete the metar linux docker container.
  dlist        List the metar linux docker image and container.

```

You can cross compile for Windows, Linux and Mac using the
xcompile docker image. There are nimble tasks for this.

```
  mxwin        Compile for windows 64 bit using the xcompile docker image.
  mxmac        Compile for mac 64 bit using the xcompile docker image.
  mxlinux      Compile for linux 64 bit using the xcompile docker image.

```

The xcompile docker image comes from

* `docker-nim-cross <https://hub.docker.com/r/chrishellerappsian/docker-nim-cross>`_

You make the xcompile image from it as follows:

::
  mkdir -p ~/code/docker-nim-cross
  cd ~/code/docker-nim-cross
  git clone https://github.com/chrisheller/docker-nim-cross.git .
  docker build -t xcompile .

  docker images | grep xcompile
  xcompile    latest    f55dcbecd036     10 days ago      2.86GB

todo: add nimpy to the image (or a new image based on it) so you
can build the python libraries this way. The metar-image shows
how to install nimpy.

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

Create a python virtual environment called metar for working with
the metar python library, then activate it. Your prompt will be
prefixed with (metar) showing that it is the active environment.

::

  cd ~/code/metar
  python3 -m venv env/mac/metarenv
  source env/mac/metarenv/bin/activate
  pip install --upgrade pip


Python Install
=================

Install metar in the virtual environment using pip. The freeze
command shows the installed custom packages, in this case metar.

::
   cd ~/code/metar
   pip install bin/mac
   pip freeze

   metar==0.1.22

You can test run metar:

::
  python
  >>> import metar
  >>> metar.get_version()
  '0.1.22'
  >>> ctrl-d

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
   rm -r env/mac/metar

Docs
=================

The module and procedure documention is created by extracting
comments from the modules.
