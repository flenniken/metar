
import unittest
import readMetadata

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
