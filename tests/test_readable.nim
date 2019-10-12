import readable
import unittest
import json
import strutils
import readers

static:
  doAssert defined(test), ": test not defined."

suite "test readable.nim":

  test "test readable image.jpg":
    let filename = "testfiles/image.jpg"
    let (metadata, readerName) = getMetadata(filename)
    let str = readable(metadata, readerName)
    # echo str
    let expected = """
========== APP0 ==========
id = "JFIF"
major = 1
minor = 1
units = 1
x = 96
y = 96
width = 0
height = 0
"""
    check(str.startsWith(expected) == true)

  test "test getRangeString":
    # Add the section to the ranges.
    # name, marker, start, finish, known, error
    var node = newJArray()
    node.add(newJString("section_name"))
    # node.add(newJInt((int)23'u8))
    node.add(newJInt(1234))
    node.add(newJInt(4321))
    node.add(newJBool(false))
    node.add(newJString("error string"))

    let str = getRangeString(node)
    # echo str
    check(str == "section_name* (1234, 4321) error string")


  test "test ellipsize":
    check(ellipsize("abcde", 5) == "abcde")
    check(ellipsize("abcde", 4) == "a...")
    check(ellipsize("abcde", 3) == "...")
    check(ellipsize("abcde", 2) == "")
    check(ellipsize("abcde", 0) == "")

    check(ellipsize("a", 1) == "a")
    check(ellipsize("ab", 2) == "ab")
    check(ellipsize("ab", 1) == "")

    check(ellipsize("", 5) == "")

  test "test getLeafString":
    check(getLeafString(newJNull(), 30) == "-")
    check(getLeafString(newJBool(true), 30) == "t")
    check(getLeafString(newJBool(false), 30) == "f")
    check(getLeafString(newJInt(123), 30) == "123")
    check(getLeafString(newJFloat(3.45), 30) == "3.45")
    check(getLeafString(newJString("hello"), 30) == "\"hello\"")

  test "test getLeafString 2":
    check(getLeafString(newJNull(), 0) == "")
    check(getLeafString(newJBool(true), 0) == "")
    check(getLeafString(newJBool(false), 0) == "")
    check(getLeafString(newJInt(123456), 5) == "12...")
    check(getLeafString(newJInt(12345), 4) == "1...")
    check(getLeafString(newJInt(1234), 3) == "...")
    check(getLeafString(newJInt(123), 3) == "123")
    check(getLeafString(newJInt(123), 2) == "")
    check(getLeafString(newJInt(123), 1) == "")
    check(getLeafString(newJInt(123), 0) == "")
    check(getLeafString(newJFloat(3.4567), 5) == "3....")
    check(getLeafString(newJFloat(3.456), 5) == "3.456")
    check(getLeafString(newJFloat(3.45), 4) == "3.45")
    check(getLeafString(newJFloat(3.45), 3) == "...")
    check(getLeafString(newJFloat(3.45), 2) == "")
    check(getLeafString(newJString("hello"), 30) == "\"hello\"")

  test "test getLeafString object":
    var obj = newJObject()
    obj["hi"] = newJInt(5)
    obj["there"] = newJInt(6)
    check(getLeafString(obj, 30) == """{"hi": 5, "there": 6}""")

  test "test getLeafString array":
    var array = newJArray()
    array.add(newJInt(5))
    array.add(newJInt(6))
    check(getLeafString(array, 30) == """[5, 6]""")

  test "test getLeafString object 2":

    var obj = newJObject()
    obj["width"] = newJInt(1000)
    obj["height"] = newJInt(500)
    var list = newJArray()
    list.add(newJInt(1))
    list.add(newJInt(2))
    list.add(newJInt(3))
    obj["array"] = list
    obj["float"] = newJFloat(2.5)

    # echo "       123456789 123456789 123456789 123456789 123456789 123456789 123456789"
    for length in 0..74:
      let str = getLeafString(obj, length)
      check(str.len <= length)
      # echo "$1 $2: $3" % [$length, $str.len, str]


  test "test getLeafString list 2":

    var list = newJArray()
    for ix in 1..18:
      list.add(newJInt(ix))

    # echo "       123456789 123456789 123456789 123456789 123456789 123456789 123456789"
    for length in 0..64:
      let str = getLeafString(list, length)
      check(str.len <= length)
      # echo "$1 $2: $3" % [$length, $str.len, str]

  test "test getLeafString object 3":
    # todo: Test long strings in objects
    discard


  test "test printMetadata":
    var metadata = newJObject()
    var xmp = newJObject()
    xmp["width"] = newJInt(200)
    xmp["height"] = newJInt(100)
    xmp["string"] = newJString("test string")
    xmp["something"] = newJNull()
    xmp["on"] = newJBool(true)
    xmp["off"] = newJBool(false)
    var obj = newJObject()
    obj["hi"] = newJString("there")
    obj["num"] = newJInt(5)
    xmp["more"] = obj
    var list = newJArray()
    list.add(newJInt(5))
    list.add(newJInt(6))
    xmp["a"] = list
    metadata["xmp"] = xmp

    let str = readable(metadata, "")

    let expected = """
========== xmp ==========
width = 200
height = 100
string = "test string"
something = -
on = t
off = f
more = {"hi": "there", "num": 5}
a = [5, 6]"""
    check(str == expected)
