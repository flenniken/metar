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

  test "test addSection":
    var metadata = newJObject()
    var dups = initTable[string, int]()
    var info = newJObject()
    info["test"] = newJInt(1)
    addSection(metadata, dups, "name", info)
    # echo metadata
    # echo readable(metadata)
    check($metadata == """{"name":{"test":1}}""")

    info = newJObject()
    info["test"] = newJInt(2)
    addSection(metadata, dups, "name", info)
    # echo metadata
    # echo readable(metadata)
    check($metadata == """{"name":[{"test":1},{"test":2}]}""")

  # If you would like to create your own multipage tiff, simply install
  # irfanview, go to “Options/Multipage images/Create Multipage tif…”
  # and select the images you want to be included in the tif.

  test "test readTiff":
    var file = openTestFile("testfiles/MARBLES.TIF")
    defer: file.close()

    let metadata = readTiff(file)
    echo readable(metadata, "tiff")
