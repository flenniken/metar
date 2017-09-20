from parseopt2 import getopt, CmdLineKind, OptParser, initOptParser
import macros, strutils

type
  Args* = tuple[files: seq[string], json: bool, help: bool, version: bool]

type
  MData* = seq[string]

macro buildVersionNumber(filename: string): typed =
  ## Read a file containing a version number and create a version
  ## number const.
  ## const versionNumber = "n.n"
  
  let
    inputString = slurp(filename.strVal)
  
  if inputString.len < 1:
    error("file is empty")

  var firstLine = inputString.splitLines[0]
  if firstLine.len < 1:
    error("first line is empty")

  var source = "const versionNumber = \"" & firstLine & "\"\n"

  result = parseStmt(source)

# Read the version.txt file and create the code: const versionNumber = "xxx"
buildVersionNumber("version.txt")

proc showHelp() =
  echo """Show metadata information for the given image(s).
Usage: metar [-j] [-v] file [file...]
-j --json     Output JSON data.
-v --version  Show the version number.
-h --help     Show this help.
file          Image file to analyze.
"""

proc parseCommandLine*(optParser: var OptParser): Args =
  ## Return the command line parameters.
  ##
  ## Return a tuple: ([file, file2,...], json, help, version)
  ## .. code-block:: nim
  ## Example:
  ##
  ## from parseopt2 import initOptParser
  ## var optParser = initOptParser()
  ## var args = parseCommandLine(optParser)

  var files: seq[string] = @[]
  var json = false
  var help = false
  var version = false
  
  # Iterate over all arguments passed to the cmdline.
  for kind, key, value in getopt(optParser):
    case kind
    of CmdLineKind.cmdShortOption:
      for ix in 0..key.len-1:
        if key[ix] == 'j':
          json = true
        elif key[ix] == 'h':
          help = true
        elif key[ix] == 'v':
          version = true
    of CmdLineKind.cmdLongOption:
      if key == "json":
        json = true
      elif key == "help":
        help = true
      elif key == "version":
        version = true
    of CmdLineKind.cmdArgument:
      files.add(key)
    else:
      help = true

  result = (files, json, help, version)

proc readMetadata*(filename: string): MData =
  ## Return metadata for the given image.
  return nil

proc printResultJson*(mdata: MData) =
  ## Print metadata as JSON.
  echo "printing json"

proc printResult*(mdata: MData) =
  ## Print metadata.
  echo "printing metadata"


proc main() =
  ## Print the metadata image information for the given image file(s).

  var optParser = initOptParser()
  var args = parseCommandLine(optParser)
  if args.version:
    echo versionNumber
    return
  elif args.files.len == 0 or args.help:
    showHelp()
    return
  for filename in args.files:
    if args.files.len > 1:
      echo "file: ", filename
    let mdata = readMetadata(filename)
    if mdata != nil:
      echo "Unable to read the image."
      continue
    if args.json:
      printResultJson(mdata)
    else:
      printResult(mdata)

main()
