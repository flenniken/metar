import unittest
import tiffTags

suite "Test test_tiffTags.nim":

  test "tagName uint16":
    check(tagName(254'u16) == "NewSubfileType(254)")
    check(tagName(434'u16) == "DefaultImageColor(434)")
    check(tagName(51125'u16) == "DefaultUserCrop(51125)")

  test "tagName not found":
    check(tagName(0'u16) == "0")
    check(tagName(253'u16) == "253")
    check(tagName(51126'u16) == "51126")

  test "tagName":
    check(tagName("254") == "NewSubfileType(254)")
    check(tagName("434") == "DefaultImageColor(434)")
    check(tagName("51125") == "DefaultUserCrop(51125)")

  test "tagName not found 2":
    check(tagName("0") == "0")
    check(tagName("253") == "253")
    check(tagName("abc") == "abc")
