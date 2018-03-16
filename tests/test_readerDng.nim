# See: readerDng.nim(0):

import readerDng
import os
import strutils
import unittest
import metadata
import hexDump
import tables
import json
import readable
import testUtils

suite "Test readerDng.nim":

  test "test readDng":
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    try:
      discard readDng(file)
    except UnknownFormatError:
      let message = getCurrentExceptionMsg()
      check(message == "Dng: not implemented.")

