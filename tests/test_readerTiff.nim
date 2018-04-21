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
import testFile
import readMetadata

const keyName = keyNameImp

suite "Test readerTiff.nim":

  test "test keyName":
    check(keyName("tiff", "ifd", "0") == "")
    check(keyName("tiff", "ifd", "253") == "")
    check(keyName("tiff", "ifd", "254") == "NewSubfileType")
    check(keyName("tiff", "ifd", "256") == "ImageWidth")
    check(keyName("tiff", "ifd", "257") == "ImageLength")
    check(keyName("tiff", "ifd", "four") == "")
    check(keyName("tiff", "ifd", "51125") == "DefaultUserCrop")


  test "test readTiff":
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    try:
      discard readTiff(file)
    except UnknownFormatError:
      let message = getCurrentExceptionMsg()
      check(message == "Tiff: not implemented.")

