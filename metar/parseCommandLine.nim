import macros
import strutils
import parseopt2
import readMetadata
import version
import metadata


proc parseCommandLine*(optParser: var OptParser): Args =
  ## Return the command line parameters.
  ##
  ## .. code-block:: nim
  ##   import parseopt2
  ##   import metar
  ##   echo parseCommandLine()

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
