
## The tpub module implements the {.tpub.} macro pragma used to make
## procedures public when testing so you can test them in external
## test files. When the test option is off, the macros do nothing.

import macros

macro tpub*(x: untyped): untyped =
  ## Exports a proc when in test mode so it can be tested in an
  ## external module.
  ##
  ## Usage:
  ##
  ## .. code-block:: nim
  ##   import tpub
  ##   proc myProcToTest(value:int): string {.tpub.} =
  ##     ...
  ##
  expectKind(x, RoutineNodes)
  when defined(test):
    x.name = newTree(nnkPostfix, ident"*", name(x))
  result = x


macro tpubType*(x: untyped): untyped =
  ## Exports a type when in test mode so it can be tested in an
  ## external module.
  ##
  ## Here is an example that makes the type "SectionInfo" public in
  ## test mode:
  ##
  ## .. code-block:: nim
  ##   import tpub
  ##   tpubType:
  ##     type
  ##       SectionInfo = object
  ##         name*: string
  ##
  # echo "treeRepr = ", treeRepr(x)
  when defined(test):
    if x.kind == nnkStmtList:
      if x[0].kind == nnkTypeSection:
        for n in x[0].children:
          if n.kind == nnkTypeDef:
            if n[0].kind == nnkIdent:
              n[0] = newTree(nnkPostfix, ident"*", n[0])
  # echo "after:"
  # echo "treeRepr = ", treeRepr(x)
  result = x
