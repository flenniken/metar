=================
Metar Development
=================

You can build and devlop metar following these instructions.

* `Nimble Tasks`_
* `Prerequisites`_
* `Download`_
* `Build`_
* `Test`_
* `Python Environment`_
* `Platforms`_
* `Docs`_

Nimble Tasks
=================

You use nimble tasks to build and test metar. Most all
development scripts are nimble tasks. You can see all the
available tasks using nimble's tasks command as shown below.

Note: It's suggested you create an alias n to run nimble to save typing.

::

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

Prerequisites
=================

The source code is written in the nim language so nim is
required.  Docker is needed to support your non host platforms
which is linux and windows for me.

* `Install Nim <https://nim-lang.org/install.html>`_
* `Docker <https://docs.docker.com/>`_

You can verify you have them installed by checking their version numbers.

::

  docker --version
  Docker version 19.03.4, build 9013bf5

  nim --version | head -1
  Nim Compiler Version 1.0.4 [MacOSX: amd64]

Download
=================

You download the metar source into a folder on your machine using
git clone.

::

  mkdir -p ~/code/metar
  cd ~/code/metar
  git clone https://github.com/flenniken/metar.git .


Build
=================

You build the release version of metar using the m nimble task.
This builds both the exe and python library. For example:

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

The binary files are stored in the bin folder as shown below. You
can verify the metar version with the version switch.

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
test command or for both debug and release using the testall
command. Here is what that looks like:

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

Python Environment
=================

The are a number of commands to develop metar in a python environment.

Create Virtual Environment
--------------------------

Create a python virtual environment called metarenv for working with
the metar python library. After activating it your prompt will change.

::

  cd ~/code/metar
  python3 -m venv env/mac/metarenv
  source env/mac/metarenv/bin/activate
  pip install --upgrade pip

Install Metar Library
---------------------

You can install metar in your virtual environment to test it in a
isolated environment. Do this using pip as show below.

The freeze command shows the installed custom packages, in this
case just metar.

::

   cd ~/code/metar
   pip install bin/mac
   pip freeze

   metar==0.1.22

Test Metar Library
------------------

You can test run metar in python by importing it and calling the
get_version procedure.

::

  python
  >>> import metar
  >>> metar.get_version()
  '0.1.22'
  >>> ctrl-d

  pip freeze
  metar==0.1.22

Uninstall Metar Library
-----------------------

Uninstall metar using pip:

::

  pip uninstall -y metar

Stop using Environment
----------------------

Stop using the virtual python environment using the deactivate
command:

::

   deactivate

Delete Environment
------------------

Remove the virtual environment by deleting the metarenv folder.

::

   cd ~/code/metar
   rm -r env/mac/metarenv


Platforms
=================

Metar is developed and tested on mac and linux (Debian) and is
cross compiled for Windows.

I use the mac to host docker. Docker containers are used to build
the linux and windows versions. You could probably host on linux
without much trouble. Hosting on Windows has issues since the nimble
tasks use unix commands and paths.

The host file system shares the code with the docker containers.

There are nimble tasks manage the linux Docker environment. They appear
near the bottom of the list and start with "d".

I have a terminal window for my mac version and one window for
the linux version. I edit on my mac, then run and test in both
mac and linux.

The dcreate command creates the image from a Dockerfile and names
it metar-image. The drun command creates a docker container
called metar-container when it is missing, then runs it.

::

  dcreate      Create a metar linux docker image.
  drun         Run the metar linux docker container.
  ddelete      Delete the metar linux docker container.
  dlist        List the metar linux docker image and container.

Cross Compile
-------------

You can cross compile for Windows, Linux and Mac using the
xcompile docker image. There are nimble tasks for this.

::

  mxwin        Compile for windows 64 bit using the xcompile docker image.
  mxmac        Compile for mac 64 bit using the xcompile docker image.
  mxlinux      Compile for linux 64 bit using the xcompile docker image.

The xcompile docker image comes from chrishellerappsian.

* `docker-nim-cross <https://hub.docker.com/r/chrishellerappsian/docker-nim-cross>`_

The following post talks about the image:

* `Nim Forum Post <https://forum.nim-lang.org/t/5569>`_

You make the xcompile image by downloading Chris's code then
building the image and naming it xcompile as follows:

::

  mkdir -p ~/code/docker-nim-cross
  cd ~/code/docker-nim-cross
  git clone https://github.com/chrisheller/docker-nim-cross.git .
  docker build -t xcompile .

  docker images | grep xcompile
  xcompile    latest    f55dcbecd036     10 days ago      2.86GB

todo: add nimpy to the image (or build a new image based on it) so you
can build the python libraries using it. See the metar-image
docker file which shows how to install nimpy.

Docs
=================

You create the nim module and procedure documention by extracting
comments from the modules with the nimble docs task. After
building all the docs the command opens the main readme in your browser.

You can build one doc using the doc1 command.
