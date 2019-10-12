import unittest
import tiffTags
import tables
import strutils

suite "Test test_tiffTags.nim":

  test "keyNameTiff":
    check(keyNameTiff("ifd", "254") == "NewSubfileType(254)")

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

  # test "sort tag table":
  #   # create a seq of keys then sort them.
  #   var vector = newSeq[uint16](tagToString.len)
  #   var ix = 0
  #   for key in tagToString.keys():
  #     vector[ix] = key
  #     ix += 1

  #   sort(vector, system.cmp[uint16])

  #   for key in vector:
  #     let name = tagToString[key]
  #     echo """  $1'u16: "$2",""" % [$key, name]


  test "validate table":
    var found = false
    var dups = initTable[string, int]()
    for _, value in tags():
      if "_" in value:
        echo "underscore value: " & value
        found = true
      if "-" in value:
        echo "minus value: " & value
        found = true
      if value in dups:
        echo "dup value: " & value
        found = true
      else:
        dups[value] = 1
    check(found == false)
    var lastKey = 0'u16
    for key, _ in tags():
      if key <= lastKey:
        check(key <= lastKey)
        break
      lastKey = key
