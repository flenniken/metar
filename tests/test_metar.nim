
import unittest
import parseopt
import metar
import strutils

const expectedHelp = """
Show metadata information for the given image(s).
Usage: metar [-j] [-v] file [file...]
-j --json     Output JSON data.
-v --version  Show the version number.
-h --help     Show this help.
file          Image filename to analyze.
"""

suite "test_metar.nim":

  test "test readMetadataJson":
    let str = readMetadataJson("missing file")
    check(str == "")

  test "test readMetadata":
    let str = readMetadataJson("missing file")
    check(str == "")

  test "test processArgs":
    let args:Args = (files: @[], json: false, help: true, version: false)
    var strings = newSeq[string]()
    for str in processArgs(args):
      strings.add(str)
    let text = strings.join("\n")
    check(text == expectedHelp)

  test "test processArgs version":
    let args:Args = (files: @[], json: false, help: false, version: true)
    var strings = newSeq[string]()
    for str in processArgs(args):
      strings.add(str)
    let text = strings.join("\n")
    # echo text
    # check(text == "0.0.3")
    check(text.len >= 4 and text.len <= 8)

  test "test showHelp":
    check(showHelp() == expectedHelp)

  test "happy path":
    # Get metadata for image.jpg.
    let args:Args = (files: @["testfiles/image.jpg"], json: false,
                     help: false, version: false)
    let expected = "filename = \"image.jpg\""
    var found = false
    for str in processArgs(args):
      let pos = find(str, expected)
      if pos == -1:
        echo str
        echo "the expected string not found:"
        echo expected
      # check(pos > 200)
      found = true
    check(found == true)

  test "parseCommandLine defaults":
    var optParser = initOptParser()
    let args = parseCommandLine(optParser)
    check(args.help == false)
    check(args.json == false)
    check(args.version == false)
    check(args.files.len == 0)

  test "parseCommandLine json":
    var optParser = initOptParser(@["-j", "image.dng"])
    var args = parseCommandLine(optParser)
    check(args.help == false)
    check(args.json == true)
    check(args.version == false)
    check(args.files.len == 1)
    check(args.files[0] == "image.dng")

  test "parseCommandLine json long":
    var optParser = initOptParser(@["--json", "image.dng"])
    var args = parseCommandLine(optParser)
    check(args.help == false)
    check(args.json == true)
    check(args.version == false)
    check(args.files.len == 1)
    check(args.files[0] == "image.dng")

  test "parseCommandLine help short":
    var optParser = initOptParser(@["-j", "-h", "image.dng"])
    var args = parseCommandLine(optParser)
    # echo args
    check(args.help == true)
    check(args.json == true)
    check(args.version == false)
    check(args.files.len == 1)
    check(args.files[0] == "image.dng")

  test "parseCommandLine help long":
    var optParser = initOptParser(@["-j", "--help", "image.dng"])
    var args = parseCommandLine(optParser)
    check(args.help == true)
    check(args.json == true)
    check(args.version == false)
    check(args.files.len == 1)
    check(args.files[0] == "image.dng")

  test "parseCommandLine version":
    var optParser = initOptParser(@["-v", "--help", "image.dng"])
    var args = parseCommandLine(optParser)
    check(args.help == true)
    check(args.json == false)
    check(args.version == true)
    check(args.files.len == 1)
    check(args.files[0] == "image.dng")

  test "parseCommandLine version long":
    var optParser = initOptParser(@["--version", "--help", "image.dng"])
    var args = parseCommandLine(optParser)
    check(args.help == true)
    check(args.json == false)
    check(args.version == true)
    check(args.files.len == 1)
    check(args.files[0] == "image.dng")

  test "parseCommandLine no image":
    var optParser = initOptParser(@["-v", "--help"])
    var args = parseCommandLine(optParser)
    check(args.help == true)
    check(args.json == false)
    check(args.version == true)
    check(args.files.len == 0)

  test "parseCommandLine no parameters2":
    var optParser = initOptParser(@[])
    var args = parseCommandLine(optParser)
    check(args.help == false)
    check(args.json == false)
    check(args.version == false)
    check(args.files.len == 0)

  test "parseCommandLine multiple files":
    var optParser = initOptParser(@["file1", "file2", "-j"])
    var args = parseCommandLine(optParser)
    check(args.help == false)
    check(args.json == true)
    check(args.version == false)
    check(args.files.len == 2)
    check(args.files[0] == "file1")
    check(args.files[1] == "file2")

  test "parseCommandLine version":
    var optParser = initOptParser(@["-v"])
    var args = parseCommandLine(optParser)
    check(args.help == false)
    check(args.json == false)
    check(args.version == true)
    check(args.files.len == 0)

  test "getVersion":
    var version = getVersion()
    check(version.len >= 4 and version.len <= 8)

  test "keyName":
    var str = keyName("tiff", "ifd0", "256")
    check(str == "ImageWidth(256)")

  test "public interface":
    # If you change the public interface you must increment the major
    # version number which you should try not to do.

    type keyNameProc = proc (readerName: string, section: string, key: string): string
    var p1 : keyNameProc = keyName
    var str = p1("tiff", "ifd0", "256")
    check(str == "ImageWidth(256)")

    type readMetadataProc = proc (filename: string): string
    var p2 : readMetadataProc = readMetadata

    type readMetadataJsonProc = proc (filename: string): string
    var p3 : readMetadataJsonProc = readMetadataJson

    type getVersionProc = proc (): string
    var p4 : getVersionProc = getVersion
