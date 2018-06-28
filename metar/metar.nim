# See: test_metar.nim(0):

## The metar module implements the metar command line program and it
## contains the public procedures available in libraries.

import readMetadata
import version
import readable
import metadata
import json
import nimpy
when not defined(buidingLib):
  import parseopt


# The keyName proc is here so it will get exported in the python module.
proc keyName*(readerName: string, section: string, key: string):
            string {.exportpy: "key_name".} =
  ## Return a human readable name for the given key.
  result = keyNameImp(readerName, section, key)


proc getVersion*(): string {.exportpy: "get_version".} =
  ## Return the version number.
  result = versionNumber


proc readMetadataJson*(filename: string): string
    {.exportpy: "read_metadata_json".} =
  ## Read the given image file's metadata and return it as a JSON
  ## string. Return an empty string when the file is not recognized.
  try:
    result = $getMetadata(filename)
  except UnknownFormatError:
    result = ""


proc readMetadata*(filename: string): string
    {.exportpy: "read_metadata".} =
  ## Read the given image file's metadata and return it as a human
  ## readable string. Return an empty string when the file is not
  ## recognized.
  try:
    result = getMetadata(filename).readable("")
  except UnknownFormatError:
    result = ""


when not defined(buidingLib):
  type
    Args* = tuple
      ## Command line arguments.  A list of filenames, and booleans for
      ## json, help and version output.
      files: seq[string]
      json: bool
      help: bool
      version: bool

  proc showHelp*(): string =
    ## Show the following command line options.
    ##
    ## ::
    ##
    ## Show metadata information for the given image(s).
    ## Usage: metar [-j] [-v] file [file...]
    ## -j --json     Output JSON data.
    ## -v --version  Show the version number.
    ## -h --help     Show this help.
    ## file          Image filename to analyze.

    result = """Show metadata information for the given image(s).
Usage: metar [-j] [-v] file [file...]
-j --json     Output JSON data.
-v --version  Show the version number.
-h --help     Show this help.
file          Image filename to analyze.
"""


  iterator processArgs*(args: Args): string =
    ## Given the command line arguments, return the requested
    ## information as bunches of lines.
    ##
    ## .. code-block:: nim
    ##   import parseopt
    ##   var optParser = initOptParser(@["-j", "image.dng"])
    ##   var args = parseCommandLine(optParser)
    ##   for str in processArgs(args):
    ##     echo str

    if args.version:
      yield($versionNumber)
    elif args.files.len == 0 or args.help:
      yield(showHelp())
    else:
      for filename in args.files:
        # Show the filename when more than one.
        if args.files.len > 1:
          yield("file: " & filename)

        # Show the metadata if any.
        var str: string
        if args.json:
          str = readMetadataJson(filename)
        else:
          str = readMetadata(filename)
        if str != "":
          yield(str)


  proc parseCommandLine*(optParser: var OptParser): Args =
    ## Return the command line parameters.
    ##
    ## .. code-block:: nim
    ##   import parseopt
    ##   import parseCommandLine
    ##   var optParser = initOptParser(@["-j", "image.dng"])
    ##   var args = parseCommandLine(optParser)
    ##   check(args.help == false)
    ##   check(args.json == true)
    ##   check(args.version == false)
    ##   check(args.files.len == 1)
    ##   check(args.files[0] == "image.dng")

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
      of CmdLineKind.cmdEnd:
        discard

    result = (files, json, help, version)


when not defined(buidingLib):
  when isMainModule:
    proc controlCHandler() {.noconv.} =
      quit 0
    setControlCHook(controlCHandler)

    var optParser = initOptParser()
    let args = parseCommandLine(optParser)
    for str in processArgs(args):
      echo str
