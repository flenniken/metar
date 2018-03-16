# See: readerTiff.nim(0):

import os
import strutils
import unittest
import metadata
import readerTiff
import hexDump
import tables
import json
import readable
import testUtils

suite "Test readerTiff.nim":

  test "test readTiff":
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    try:
      discard readTiff(file)
    except UnknownFormatError:
      let message = getCurrentExceptionMsg()
      check(message == "Tiff: not implemented.")

