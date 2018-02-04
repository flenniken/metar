
import unittest
import readMetadata
import json

suite "Test readMetadata.nim":

  # proc keyName*(readerName: string, section: string, key: string): string =
  test "keyName invalid name":
    require(keyName("missing", "xmp", "key") == "")

  test "keyName invalid section":
    require(keyName("jpeg", "missing", "key") == "")
    require(keyName("dng", "missing", "key") == "")
    require(keyName("tiff", "missing", "key") == "")

  test "keyName invalid key":
    require(keyName("jpeg", "xmp", "missing") == "")
    require(keyName("dng", "xmp", "missing") == "")
    require(keyName("tiff", "xmp", "missing") == "")

  # todo: test keyNames basic working case

  test "test getMetaInfo":
    let info = getMetaInfo("filename", "readerName", 12345)
    # echo info
    # echo pretty(info)
    # todo: check values

  test "test readMetadata nil":
    let info = readMetadata("filename")
    check(info == nil)

  test "test readMetadata":
    let filename = "testfiles/image.jpg"
    let info = readMetadata(filename)
    # todo: check output
    # echo info
