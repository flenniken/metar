# See: readerTiff.nim(0):

import unittest
import metadata
import json
import testFile
import readers
import tiff


suite "Test readerTiff.nim":

  test "test keyName":
    check(keyName("tiff", "ifd", "0") == "")
    check(keyName("tiff", "ifd", "253") == "")
    check(keyName("tiff", "ifd", "254") == "NewSubfileType(254)")
    check(keyName("tiff", "ifd", "256") == "ImageWidth(256)")
    check(keyName("tiff", "ifd", "257") == "ImageHeight(257)")
    check(keyName("tiff", "ifd", "four") == "")
    check(keyName("tiff", "ifd", "51125") == "DefaultUserCrop(51125)")


  test "test readTiff":
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    try:
      discard readTiff(file)
    except UnknownFormatError:
      let message = getCurrentExceptionMsg()
      check(message == "Tiff: not implemented.")

  # todo: create multipage tiff.
  # If you would like to create your own multipage tiff, simply install
  # irfanview, go to “Options/Multipage images/Create Multipage tif…”
  # and select the images you want to be included in the tif.

  test "test readTiff":
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    let metadata = readTiff(file)
    # discard metadata
    # echo readable(metadata, "tiff")
