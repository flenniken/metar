
import unittest
import metar/readMetadata

suite "Test readMetadata.nim":

  # proc keyName*(readerName: string, section: string, key: string): string =
  test "keyName invalid name":
    require(keyName("missing", "xmp", "key") == nil)

  test "keyName invalid section":
    require(keyName("jpeg", "missing", "key") == nil)
    require(keyName("dng", "missing", "key") == nil)
    require(keyName("tiff", "missing", "key") == nil)

  test "keyName invalid key":
    require(keyName("jpeg", "xmp", "missing") == nil)
    require(keyName("dng", "xmp", "missing") == nil)
    require(keyName("tiff", "xmp", "missing") == nil)

  # todo: test keyNames basic working case
