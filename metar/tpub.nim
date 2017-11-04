##[
`Home <index.html>`_

tpub
====

The tpub module implements the {.tpub.} macro pragma used to make
procedures public in debug mode.

]##

import macros

macro tpub*(x: untyped): untyped =
  ## Exports a proc when in debug mode (not in release) so it can be
  ## tested in an external module.
  ##
  ## Usage:
  ##
  ## .. code-block:: nim
  ##   import tpub
  ##   proc main(value:int): string {.tpub.} =
  ##     result = "test main in external module"
  ##
  expectKind(x, RoutineNodes)
  when not defined(release):
    x.name = newTree(nnkPostfix, ident"*", name(x))
  result = x
