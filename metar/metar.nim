# See: test_metar.nim(0):

## The metar module implements the metar command line program and it
## contains the public procedures available in libraries.

# The current version of nimpy will only export metar methods when
# they are defined in the metar module.  So all public python
# procedures are defined in this file.

when not defined(buildingLib):
  import tpub
import readers
import version
import readable
import metadata
import json
when defined(buildingLib):
  import nimpy
else:
  import parseopt
  # Do nothing with exportpy pragmas when not building a library.
  macro exportpy(name: untyped, x: untyped): untyped =
    result = x


proc readMetadataJson*(filename: string): string
    {.exportpy: "read_metadata_json".} =
  ## Read the given image file's metadata and return it as a JSON
  ## string. Return an empty string when the file is not recognized.
  ##
  ## Nim:
  ##
  ## .. code-block:: nim
  ##
  ##   import metar
  ##   echo readMetadataJson("testfiles/image.dng")
  ##   {"ifd1":{"offset":8,"next":0,"254":[1],"256":[256],...}
  ##
  ## Python:
  ##
  ## .. code-block::
  ##
  ##   >>> from metar import read_metadata_json
  ##   >>> print(read_metadata_json("testfiles/image.dng"))
  ##   {"ifd1":{"offset":8,"next":0,"254":[1],"256":[256],...}
  ##
  try:
    let (metadata, readerName) = getMetadata(filename)
    discard readerName
    result = $metadata
  except UnknownFormatError:
    result = ""


proc readMetadata*(filename: string): string
    {.exportpy: "read_metadata".} =
  ## Read the given image file's metadata and return it as a human
  ## readable string. Return an empty string when the file is not
  ## recognized.
  ##
  ## Nim:
  ##
  ## .. code-block:: nim
  ##
  ##   import metar
  ##   echo readMetadata("testfiles/image.dng")
  ##
  ## Python:
  ##
  ## .. code-block::
  ##
  ##   >>> from metar import read_metadata_json
  ##   >>> print(read_metadata("testfiles/image.dng"))
  ##
  ## Returns::
  ##
  ##   ========== ifd1 ==========
  ##   offset = 8
  ##   next = 0
  ##   NewSubfileType(254) = [1]
  ##   ImageWidth(256) = [256]
  ##   ImageHeight(257) = [171]
  ##   ...
  ##
  try:
    let (metadata, readerName) = getMetadata(filename)
    result = metadata.readable(readerName)
  except UnknownFormatError:
    result = ""


proc keyName*(readerName: string, section: string, key: string):
            string {.exportpy: "key_name".} =
  ## Return a human readable name for the given key.
  ##
  ## The readerName is "jpeg", "tiff" etc. You can find the name in
  ## the meta section.  A section is a top level key in the metadata
  ## dictionary, ie, "xmp", "iptc", "meta", etc. A key is a sub key of
  ## the section, ie, "256".
  ##
  ## Nim:
  ##
  ## .. code-block:: nim
  ##
  ##   import metar
  ##   echo keyName("tiff", "ifd1", "256")
  ##   ImageWidth(256)
  ##
  ## Python:
  ##
  ## .. code-block::
  ##
  ##   >>> from metar import key_name
  ##   >>> key_name("tiff", "ifd1", "256")
  ##   'ImageWidth(256)'
  ##
  result = readers.keyName(readerName, section, key)


proc getVersion*(): string {.exportpy: "get_version".} =
  ## Return the Metar version number string.
  ##
  ## Nim:
  ##
  ## .. code-block:: nim
  ##
  ##   import metar
  ##   echo get_version()
  ##   0.0.4
  ##
  ## Python:
  ##
  ## .. code-block::
  ##
  ##   >>> from metar import get_version
  ##   >>> get_version()
  ##   '0.0.4'
  ##
  result = metarVersion


when not defined(buildingLib):
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
    ## Show the following command line options and usage::
    ##
    ##   Show metadata information for the given image(s).
    ##   Usage: metar [-j] [-v] file [file...]
    ##   -j --json     Output JSON data.
    ##   -v --version  Show the version number.
    ##   -h --help     Show this help.
    ##   file          Image filename to analyze.
    ##
    ## This procedure is not defined in the python library.
    ##
    result = """
Show metadata information for the given image(s).
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
    ##
    ##   import metar, parseopt
    ##   var optParser = initOptParser(@["-j", "image.dng"])
    ##   var args = parseCommandLine(optParser)
    ##   for str in processArgs(args):
    ##     echo str
    ##
    ## This iterator is not defined in the python library.
    ##

    if args.version:
      yield($metarVersion)
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
    ##
    ##   import metar, parseopt
    ##   import parseCommandLine
    ##   var optParser = initOptParser(@["-j", "image.dng"])
    ##   var args = parseCommandLine(optParser)
    ##   check(args.help == false)
    ##   check(args.json == true)
    ##   check(args.version == false)
    ##   check(args.files.len == 1)
    ##   check(args.files[0] == "image.dng")
    ##
    ## This procedure is not defined in the python library.
    ##
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


  when isMainModule:
    # Detect control-c and stop.
    proc controlCHandler() {.noconv.} =
      quit 0
    setControlCHook(controlCHandler)

    # Process the command line args and run.
    var optParser = initOptParser()
    let args = parseCommandLine(optParser)
    for str in processArgs(args):
      echo str
