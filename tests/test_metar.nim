
import unittest
import parseopt2
import metar
import metadata
import strutils

const help = """
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
    check(text == help)

  test "test showHelp":
    check(showHelp() == help)
