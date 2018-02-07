
import unittest
import metar
import parseopt2
import parseCommandLine

suite "test_parseCommandLine.nim":

  test "parseCommandLine defaults":
    var optParser = initOptParser()
    let args = parseCommandLine(optParser)
    require(args.help == false)
    require(args.json == false)
    require(args.version == false)
    require(args.files.len == 0)
  
  test "parseCommandLine json":
    var optParser = initOptParser(@["-j", "image.dng"])
    var args = parseCommandLine(optParser)
    require(args.help == false)
    require(args.json == true)
    require(args.version == false)
    require(args.files.len == 1)
    require(args.files[0] == "image.dng")

  test "parseCommandLine help short":
    var optParser = initOptParser(@["-j", "-h", "image.dng"])
    var args = parseCommandLine(optParser)
    # echo args
    require(args.help == true)
    require(args.json == true)
    require(args.version == false)
    require(args.files.len == 1)
    require(args.files[0] == "image.dng")

  test "parseCommandLine help long":
    var optParser = initOptParser(@["-j", "--help", "image.dng"])
    var args = parseCommandLine(optParser)
    require(args.help == true)
    require(args.json == true)
    require(args.version == false)
    require(args.files.len == 1)
    require(args.files[0] == "image.dng")

  test "parseCommandLine version":
    var optParser = initOptParser(@["-v", "--help", "image.dng"])
    var args = parseCommandLine(optParser)
    require(args.help == true)
    require(args.json == false)
    require(args.version == true)
    require(args.files.len == 1)
    require(args.files[0] == "image.dng")

  test "parseCommandLine no image":
    var optParser = initOptParser(@["-v", "--help"])
    var args = parseCommandLine(optParser)
    require(args.help == true)
    require(args.json == false)
    require(args.version == true)
    require(args.files.len == 0)

  test "parseCommandLine no parameters2":
    var optParser = initOptParser(@[])
    var args = parseCommandLine(optParser)
    require(args.help == false)
    require(args.json == false)
    require(args.version == false)
    require(args.files.len == 0)

  test "parseCommandLine multiple files":
    var optParser = initOptParser(@["file1", "file2", "-j"])
    var args = parseCommandLine(optParser)
    require(args.help == false)
    require(args.json == true)
    require(args.version == false)
    require(args.files.len == 2)
    require(args.files[0] == "file1")
    require(args.files[1] == "file2")

  test "parseCommandLine version":
    var optParser = initOptParser(@["-v"])
    var args = parseCommandLine(optParser)
    require(args.help == false)
    require(args.json == false)
    require(args.version == true)
    require(args.files.len == 0)
    
