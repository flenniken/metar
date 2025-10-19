=================
Metar Development
=================

Download
=================

You download the metar source into a folder on your machine using
git clone.

::

  mkdir -p ~/code/metar
  cd ~/code/metar
  git clone https://github.com/flenniken/metar.git .


Docker Environment
=================

You build and test metar in a docker environment. You create the
environment with the runenv b command::

  cd ~/code/metar
  runenv b

You run the environment with the r command::

  runenv r

You need to build the nim compiler from source.  You do that in
the docker environment the first time::

  cd ~/Nim
  ./build_all.sh
  cd -

Build Tasks
=================

You use the build script commands to build and test metar.  You can
see all the available tasks by running build without any arguments.

Note: b is an alias to ./build

::

(debian)~/metar $ b
b         Build the debug and release versions of metar.
t         Test the debug and release versions of metar.
docs      Build all the docs.
dot       Build the dependency graph.
ts        Run metar sanity checks.

You build the debug and release versions of metar using the b
build command.

::

  cd ~/code/metar
  b b

The binary files are stored in the bin folder. The debug version
is in the debug folder and the release version is one level up.

Test
=================

You can run the unit tests for the debug and release versions
using the t build command.

::

  b t

