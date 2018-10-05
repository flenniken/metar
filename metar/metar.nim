# See: test_metar.nim(0):

## The metar module implements the metar command line program and it
## contains the public procedures available in libraries.

import tpub
import readMetadata
import version
import readable
import metadata
import json
when defined(buidingLib):
  import nimpy
else:
  import parseopt
  # Do nothing with exportpy pragmas when not building a library.
  macro exportpy(name: untyped, x: untyped): untyped =
    result = x

# The current version of nimpy will only export metar methods when
# they are defined in the metar module.  The keyName proc is here so
# it will get exported in the python module.

proc keyName*(readerName: string, section: string, key: string):
            string {.exportpy: "key_name".} =
  ## Return a human readable name for the given key. The name is
  ## key_name in python. The readerName is jpeg, tiff,... You can find
  ## the reader name in the meta reader field. Section is a top level
  ## key in the metadata dictionary, ie, xmp, iptc... A key is a sub
  ## key of the section.  For example:
  ##
  ## ::
  ##
  ## echo keyName("jpeg", "ifd1", "256")
  ##
  ## ImageWidth
  result = keyNameImp(readerName, section, key)


proc getVersion*(): string {.exportpy: "get_version".} =
  ## Return the Metar version number string.  The name is get_version
  ## in python.
  result = versionNumber


proc readMetadataJson*(filename: string): string
    {.exportpy: "read_metadata_json".} =
  ## Read the given image file's metadata and return it as a JSON
  ## string. The name is read_metadata_json in python. Return an empty
  ## string when the file is not recognized.
  try:
    result = $getMetadata(filename)
  except UnknownFormatError:
    result = ""


proc readMetadata*(filename: string): string
    {.exportpy: "read_metadata".} =
  ## Read the given image file's metadata and return it as a human
  ## readable string. The name in python is read_metadata. Return an
  ## empty string when the file is not recognized.
  try:
    result = getMetadata(filename).readable("")
  except UnknownFormatError:
    result = ""


when not defined(buidingLib):
  tpubtype:
    type
      Args = tuple
        ## Command line arguments.  A list of filenames, and booleans for
        ## json, help and version output.
        files: seq[string]
        json: bool
        help: bool
        version: bool

  proc showHelp(): string {.tpub.} =
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


  iterator processArgs(args: Args): string {.tpub.} =
    ## Given the command line arguments, return the requested
    ## information as lists of lines (strings).
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
        # Show the metadata if any.
        var str: string
        if args.json:
          str = readMetadataJson(filename)
        else:
          str = readMetadata(filename)
        if str != "":
          # Show the filename when more than one.
          if args.files.len > 1:
            yield("file: " & filename)
          yield(str)


  proc parseCommandLine(optParser: var OptParser): Args {.tpub.} =
    ## Return the command line parameters.
    ##
    ## The following example is for the command line: metar -j image.dng
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
    # Handle control-c and stop.
    proc controlCHandler() {.noconv.} =
      quit 0
    setControlCHook(controlCHandler)

    # Process the command line args and run.
    var optParser = initOptParser()
    let args = parseCommandLine(optParser)
    for str in processArgs(args):
      echo str
