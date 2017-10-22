##[
`Home <index.html>`_

version
=======

The version module reads the version number from ver.txt and creates
the versionNumber variable at compile time.

]##

import macros
import strutils

macro buildVersionNumber(filename: string): typed =
  ## Read a file containing the version number and create a version
  ## number const like:
  ##
  ## const versionNumber* = "n.n.n"
  ##
  ## The file is expected to have one line like: version = "0.0.2"

  let
    fileLines = slurp(filename.strVal)
  assert(fileLines.len > 0, "Invalid file, no lines.")

  var line = fileLines.splitLines[0]
  assert(line.len > 6, "Invalid line, to short.")

  let start = line.find('"')
  assert(start >= 0, "Invalid line, missing quote.")

  let finish = line.find('"', start+1)
  assert(finish >= 0, "Invalid line, missing ending quote.")

  let source = "const versionNumber* = " & line[start..finish]
  # echo source

  result = parseStmt(source)

buildVersionNumber("ver.nim")
