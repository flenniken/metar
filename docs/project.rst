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

Note: It's suggested you create an alias n to run nimble since it
is used so much.

For example:

```
  alias n='nimble'
```

You can list the tasks running nimble's tasks command::

```
  n tasks

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
```

Platforms
=================

Currently metar is developed and tested on two platforms, mac and
linux (Debian).

### Mac

I use the mac to host docker and to share the metar source code
with the linux docker system.

### Linux

You can use Docker to run and test metar on the linux platform.

There are nimble tasks manage the Docker environment. They are
the tasks at the bottom:

```
  dcreate      Create a metar linux docker image.
  drun         Run the metar linux docker container.
  ddelete      Delete the metar linux docker container.
  dlist        List the metar linux docker image and container.
```

Install
=================

#todo: show how to make a directory, pull down the source code and
build.
#todo: Show how to make a linux environment and build metar on it.
#todo: show installing nim too.

Build
=================

Test
=================

Docs
=================

The module and procedure documention is created by extracting
comments from the modules.

Python Install
=================

You install the one file python library using pip
after you build it in a folder on your machine.
For more details see the development section below.

  pip install ~/code/metar/python/metar

Uninstall using pip:

  pip remove metar

