## Image metadata reader

import macros
import strutils
import parseopt2
import metar/readMetadata
import metar/version

type
  Args* = tuple[files: seq[string], json: bool, help: bool, version: bool] ## \
  ## Command line arguments.  A list of filenames, and booleans for
  ## json, help and version output.


proc showHelp*() =
  ## Show the following command line options.
  ##
  ## ::
  ##
  ## Show metadata information for the given image(s).
  ## Usage: metar [-j] [-v] file [file...]
  ## -j --json     Output JSON data.
  ## -v --version  Show the version number.
  ## -h --help     Show this help.
  ## file          Image file to analyze.

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
  ## .. code-block:: nim
  ##   from parseopt2 import initOptParser
  ##   from metar import parseCommandLine
  ##   var optParser = initOptParser()
  ##   var args = parseCommandLine(optParser)
  ##   echo args

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

proc main*() =
  ## Print the metadata image information for the given image file(s)
  ## specified on the command line. See showHelp for the options.

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
    let metadata = readMetadata(filename)
    if metadata != nil:
      echo "Unable to read the image."
      continue
    if args.json:
      printMetadataJson(metadata)
    else:
      printMetadata(metadata)

main()
