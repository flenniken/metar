##[
`Home <index.html>`_

metar
=====

The metar module implements the metar command line program.

]##

import macros
import strutils
import readMetadata
import version
import readable
import metadata
import nimpy
import json
when not defined(buidingLib):
  import parseopt2
  import parseCommandLine

# The keyName proc is here so it will get exported in the python module.
proc keyName*(readerName: string, section: string, key: string):
            string {.exportpy: "key_name".} =
  result = keyNameImp(readerName, section, key)


proc getVersion*(): string {.exportpy: "get_version".} =
   result = versionNumber


proc readMetadataJson*(filename: string): string
    {.exportpy: "read_metadata_json".} =
  try:
    result = $getMetadata(filename)
  except UnknownFormatError:
    result = ""


proc readMetadata*(filename: string): string
    {.exportpy: "read_metadata".} =
  try:
    result = getMetadata(filename).readable()
  except UnknownFormatError:
    result = ""


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
  ## Return the requested information as bunches of lines.

  if args.version:
    yield($versionNumber)
  elif args.files.len == 0 or args.help:
    yield(showHelp())
  else:
    for filename in args.files:
      if args.files.len > 1:
        yield("file: " & filename)
      if args.json:
        yield(readMetadataJson(filename))
      else:
        let metadata = getMetadata(filename)
        for line in metadata.lines():
          yield(line)


when not defined(buidingLib):
  when isMainModule:
    var optParser = initOptParser()
    let args = parseCommandLine(optParser)
    for str in processArgs(args):
      echo str
