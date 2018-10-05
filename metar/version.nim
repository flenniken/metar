
## You use the version module to read the version number from ver.nim
## and to create the versionNumber variable at compile time.

import macros
import strutils

macro declareVersionNumber(filename: string): typed =
  ## Read a file containing the version number and create a version
  ## number const like:
  ##
  ## .. code-block:: nim
  ##   const versionNumber* = "n.n.n"
  ##
  ## The file is expected to have one line like: version = "0.0.2"

  let fileLines = slurp(filename.strVal)
  assert(fileLines.len > 0, "Invalid file, no lines.")

  var line = fileLines.splitLines[0]
  assert(line.len > 6, "Invalid line, too short.")

  let start = line.find('"')
  assert(start >= 0, "Invalid line, missing quote.")

  let finish = line.find('"', start+1)
  assert(finish >= 0, "Invalid line, missing ending quote.")

  let source = "const versionNumber* = " & line[start..finish]
  result = parseStmt(source)

# const versionNumber* = "n.n.n"
declareVersionNumber("ver.nim")
