# See: tiff.nim(0):

import os
import metadata
import unittest
import testFile
import tiff
import readNumber
import hexDump
import strutils
import json
import readable
import xmpparser
import tiffTags
import ranges
import hexDump
import tables


suite "test tiff.nim":

  test "test readHeader big":
    # Test big endian header
    var bytes = [0x4d'u8, 0x4d, 0x00, 0x2a, 0x12, 0x34, 0x56, 0x78]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)

    let (offset, endian) = readHeader(file, 0)
    check(offset == (uint32)0x12345678)
    check(endian == bigEndian)

  test "test readHeader little":
    # Test little endian header
    var bytes = [0x49'u8, 0x49, 0x2a, 0x00, 0x78, 0x56, 0x34, 0x12]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)

    let (offset, endian) = readHeader(file, 0)
    check(offset == 0x12345678'u32)
    check(endian == littleEndian)

  test "test readHeader non-zero offset":
    # test header that does not start at 0.
    var bytes = [0x22'u8, 0x33, 0x00, 0x4d, 0x4d, 0x00, 0x2a, 0x12, 0x34, 0x56, 0x78]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)

    let (offset, endian) = readHeader(file, 3)
    check(offset == 0x12345678'u32)
    check(endian == bigEndian)

  test "test readHeader invalid order":
    # test header with invalid byte order bytes.
    var bytes = [0x4d'u8, 0x4e, 0x00, 0x2a, 0x12, 0x34]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)
    var gotException = false
    try:
      discard readHeader(file, 0)
    except UnknownFormatError:
      # echo getCurrentExceptionMsg()
      gotException = true

    check(gotException == true)

  test "test readHeader not enough bytes":
    # test a file with not enought bytes for a header.
    var bytes = [0x4d'u8, 0x4d]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)
    var gotException = false
    try:
      discard readHeader(file, 0)
    except UnknownFormatError:
      # echo getCurrentExceptionMsg()
      gotException = true

    check(gotException == true)

  test "test readHeader invalid magic":
    # Test header with an invalid magic number.
    var bytes = [0x4d'u8, 0x4d, 0x00, 0x2b, 0x12, 0x34, 0x56, 0x78]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)

    var gotException = false
    try:
      discard readHeader(file, 0)
    except UnknownFormatError:
      # echo getCurrentExceptionMsg()
      gotException = true

    check(gotException == true)

  test "test header image.tif":
    # Test the header from a real file.
    var file = openTestFile("testfiles/image.tif")
    defer: file.close()
    let (offset, endian) = readHeader(file, 0)
    check(offset == 0x08'u32)
    check(endian == littleEndian)

  test "test tagName":
    check(tagName((uint16)254) == "NewSubfileType(254)")
    check(tagName((uint16)255) == "SubfileType(255)")
    check(tagName((uint16)256) == "ImageWidth(256)")
    check(tagName((uint16)257) == "ImageHeight(257)")

    check(tagName((uint16)0) == "0")
    check(tagName((uint16)60123) == "60123")

  # test "test dump tiff":
  #   dumpTestFile("testfiles/image.tif", 0, 20)

  test "test getIFDEntry":
    var file = openTestFile("testfiles/image.tif")
    defer: file.close()
    let (ifdOffset, endian) = readHeader(file, 0)
    check(ifdOffset == 0x08'u32)
    check(endian == littleEndian)

    # Read the number of IFD entries.
    let ifdCount = readNumber[uint16](file)
    check(ifdCount == 14)

    # Read the first entry and test the string representation.
    const bufferSize = 12*14
    var buffer: array[bufferSize, uint8]
    if file.readBytes(buffer, 0, bufferSize) != bufferSize:
      raise newException(IOError, "Unable to read the file.")

    let entry = getIFDEntry(buffer, endian, 0)
    let expected = "NewSubfileType(254), 1 longs, packed: 00 00 00 00"
    check(entry.tag == 254'u16)
    check(entry.kind == Kind.longs)
    check(entry.count == 1)
    check(entry.packed == [0'u8, 0, 0, 0])
    check(entry.endian == endian)
    check(entry.headerOffset == 0)

    # Loop through the 14 IDF entries.
    for ix in 0..14-1:
      let entry = getIFDEntry(buffer, endian, 0, ix*12)
      # echo $entry


  test "test getIFDEntry bigEndian":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x04, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    let expected = "NewSubfileType(254), 5 longs, packed: 00 01 02 03"
    check(entry.tag == 254'u16)
    check(entry.kind == Kind.longs)
    check(entry.count == 5)
    check(entry.packed == [0'u8, 1, 2, 3])
    check(entry.endian == bigEndian)
    check(entry.headerOffset == 0)

  test "test getIFDEntry index":
    var buffer = [
      0x00'u8, 0x00, 0x00, 0xFE, 0x00, 0x04, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0, 2)
    # let expected = "NewSubfileType(254), 5 longs, packed: 00 01 02 03"

    check(entry.tag == 254'u16)
    check(entry.kind == Kind.longs)
    check(entry.count == 5)
    check(entry.packed == [0'u8, 1, 2, 3])
    check(entry.endian == bigEndian)
    check(entry.headerOffset == 0)
    # echo $entry

  test "test getIFDEntry index not enough":
    var buffer = [
      0x00'u8, 0x00, 0x00, 0xFE, 0x00, 0x04, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x01, 0x02
    ]
    var gotException = false
    try:
      discard getIFDEntry(buffer, bigEndian, 0, 2)
    except NotSupportedError:
      # echo getCurrentExceptionMsg()
      gotException = true
    check(gotException == true)

  test "test getIFDEntry not enough bytes":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x04, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x01, 0x02
    ]
    var gotException = false
    try:
      discard getIFDEntry(buffer, bigEndian, 0)
    except NotSupportedError:
      # echo getCurrentExceptionMsg()
      gotException = true
    check(gotException == true)

  test "test getIFDEntry invalid kind":
    # Test with a kind of 0x22.
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x22, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x01, 0x02, 0x03,
    ]
    var gotException = false
    try:
      discard getIFDEntry(buffer, bigEndian, 0)
    except NotSupportedError:
      # echo getCurrentException().name
      # echo getCurrentExceptionMsg()
      gotException = true
    check(gotException == true)

  test "test getIFDEntry kind 0":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x01, 0x02, 0x03,
    ]
    var gotException = false
    try:
      discard getIFDEntry(buffer, bigEndian, 0)
    except NotSupportedError:
      # echo getCurrentException().name
      # echo getCurrentExceptionMsg()
      gotException = true
    check(gotException == true)

  test "test kindSize":
    # for kind in low(Kind)..high(Kind):
    #   echo "$1 $2 $3" % [$ord(kind), $kindSize(kind), $kind]

    check(kindSize(Kind.bytes) == 1)
    check(kindSize(Kind.strings) == 1)
    check(kindSize(Kind.shorts) == 2)
    check(kindSize(Kind.longs) == 4)
    check(kindSize(Kind.rationals) == 8)
    check(kindSize(Kind.sbytes) == 1)
    check(kindSize(Kind.blob) == 1)
    check(kindSize(Kind.sshorts) == 2)
    check(kindSize(Kind.slongs) == 4)
    check(kindSize(Kind.srationals) == 8)
    check(kindSize(Kind.floats) == 4)
    check(kindSize(Kind.doubles) == 8)

  test "test readValueList 1 long":
    # tag = 00feh, kind = longs, count = 1, packed = 00010203h
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x04, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 1)
    check(toHex((uint32)list[0].getInt()) == "00010203")

  test "test readValueList -1 long":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x09, 0x00, 0x00, 0x00, 0x01,
      0xff, 0xff, 0xff, 0xff,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 1)
    check(list[0].getInt() == -1)

  test "test readValueList 1 long little endian":
    # tag = 00feh, kind = longs, count = 1, packed = 00010203h
    var buffer = [
      0xFE'u8, 0x00, 0x04, 0x00, 0x01, 0x00, 0x00, 0x00,
      0x00, 0x01, 0x02, 0x03,
    ]
    let endian = littleEndian
    let entry = getIFDEntry(buffer, endian, 0)
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 1)
    check(toHex((uint32)list[0].getInt()) == "03020100")

  test "test readValueList 1 short":
# tag = 00feh, kind = shorts, count = 1, packed = 00010203h
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 1)
    check(toHex((uint16)list[0].getInt()) == "0001")

  test "test readValueList -1 short":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x08, 0x00, 0x00, 0x00, 0x01,
      0xff, 0xff, 0xff, 0xff,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 1)
    check(list[0].getInt() == -1)


  test "test readValueList 2 short":
    # tag = 00feh, kind = shorts, count = 2, packed = 00010203h
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x03, 0x00, 0x00, 0x00, 0x02,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 2)
    check(toHex((uint16)list[0].getInt()) == "0001")
    check(toHex((uint16)list[1].getInt()) == "0203")

  test "test readValueList 2 short little endian":
    # tag = 00feh, kind = shorts, count = 2, packed = 00010203h
    var buffer = [
      0xfe'u8, 0x00, 0x03, 0x00, 0x02, 0x00, 0x00, 0x00,
      0x00, 0x01, 0x02, 0x03,
    ]
    let endian = littleEndian
    let entry = getIFDEntry(buffer, endian, 0)
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 2)
    check(toHex((uint16)list[0].getInt()) == "0100")
    check(toHex((uint16)list[1].getInt()) == "0302")


  test "test readValueList 1 byte":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x01, 0x02, 0x03,
    ]
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 1)
    check($list == "[0]")

  test "test readValueList 1 sbyte":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x06, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x01, 0x02, 0x03,
    ]
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 1)
    check($list == "[0]")

  test "test readValueList 2 byte":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02,
      0x00, 0x01, 0x02, 0x03,
    ]
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 2)
    check($list == "[0,1]")

  test "test readValueList 3 byte":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x01, 0x00, 0x00, 0x00, 0x03,
      0x00, 0x01, 0x02, 0x03,
    ]
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 3)
    check($list == "[0,1,2]")

  test "test readValueList 4 byte":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x01, 0x00, 0x00, 0x00, 0x04,
      0x00, 0x01, 0x02, 0x03,
    ]
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    # echo $list
    check(list.len == 4)
    check($list == "[0,1,2,3]")

  test "test readValueList 4 byte little endian":
    var buffer = [
      0xFE'u8, 0x00, 0x01, 0x00, 0x04, 0x00, 0x00, 0x00,
      0x00, 0x01, 0x02, 0x03,
    ]
    let endian = littleEndian
    let entry = getIFDEntry(buffer, endian, 0)
    var file: File
    var list = readValueList(file, entry)
    # echo $list
    check(list.len == 4)
    check($list == "[0,1,2,3]")


  test "test readValueList 1 float32":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x0b, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x00, 0x00, 0x00,
    ]
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    # echo $list
    check(list.len == 1)
    check($list == "[0.0]")



  test "test readValueList 1 byte blob":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x07, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x01, 0x02, 0x03,
    ]
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    # echo $list
    check(list.len == 1)
    check($list == "[0]")


  test "test readValueList strings 1":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02,
      0x65, 0x00, 0x02, 0x03,
    ]
    # The count field is the number of bytes in all the strings and
    # their ending 0.
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    # echo $list
    check(list.len == 1)
    check($list == """["e"]""")

  test "test readValueList strings 2":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x02, 0x00, 0x00, 0x00, 0x04,
      0x41, 0x00, 0x42, 0x00,
    ]
    # The count field is the number of bytes in all the strings and
    # their ending 0.
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var file: File
    var list = readValueList(file, entry)
    # echo $list
    check(list.len == 2)
    check($list == """["A","B"]""")

  test "test readValueList strings 3":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x02, 0x00, 0x00, 0x00, 0x04,
      0x65, 0x66, 0x67, 0x00,
    ]
    # The count field is the number of bytes in all the strings and
    # their ending 0.
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    var file: File
    var list = readValueList(file, entry)
    check(list.len == 1)
    check($list == """["efg"]""")

  test "find":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x02, 0x00, 0x00, 0x00, 0x04,
      0x65, 0x66, 0x67, 0x77,
    ]
    var pos: int
    pos = tiff.find(buffer, 2'u8)
    check(pos == 3)
    pos = tiff.find(buffer, 2'u8, 1)
    check(pos == 3)
    pos = tiff.find(buffer, 0'u8)
    check(pos == 0)
    pos = tiff.find(buffer, 0'u8, 1)
    check(pos == 2)
    pos = tiff.find(buffer, 0'u8, 20)
    check(pos == -1)
    pos = tiff.find(buffer, 44u8)
    check(pos == -1)
    pos = tiff.find(buffer, 0x77u8)
    check(pos == 11)

# [10] => ["1"]
# [abc0] => ["abc"]
# [1020] => ["1","2"]
# [] => []
# [0] => [""]
# [1] => ["1"]
# [102] => ["1","2"]

  test "test parseStrings A":
    var buffer = [65'u8, 0x00]
    var node = parseStrings(buffer)
    check(node.len == 1)
    check(node[0].getStr() == "A")

  test "test parseStrings ABC":
    var buffer = [65'u8, 66'u8, 67'u8, 0x00]
    var node = parseStrings(buffer)
    check(node.len == 1)
    check(node[0].getStr() == "ABC")

  test "test parseStrings A,B":
    var buffer = [65'u8, 0, 66, 0]
    var node = parseStrings(buffer)
    check(node.len == 2)
    check(node[0].getStr() == "A")
    check(node[1].getStr() == "B")


  test "test parseStrings empty":
    var buffer = newSeq[uint8]()
    var node = parseStrings(buffer)
    check(node.len == 0)


  test "test parseStrings 0":
    var buffer = [0'u8]
    var node = parseStrings(buffer)
    check(node.len == 1)
    check(node[0].getStr() == "")


  test "test parseStrings no ending 0":
    var buffer = [65'u8]
    var node = parseStrings(buffer)
    check(node.len == 1)
    check(node[0].getStr() == "A")

  test "test parseStrings no ending 0 again":
    var buffer = [65'u8, 0, 67]
    var node = parseStrings(buffer)
    check(node.len == 2)
    check(node[0].getStr() == "A")
    check(node[1].getStr() == "C")

  test "test readValueList one more than packed":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x01, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x00, 0x00, 0x0c, 0, 1, 2, 3, 4, 5
    ]
    var (file, filename) = createTestFile(buffer)
    defer:
      file.close()
      removeFile(filename)

    let entry = getIFDEntry(buffer, bigEndian, 0)
    var list = readValueList(file, entry)
    check(list.len == 5)
    check($list == "[0,1,2,3,4]")


  test "test readValueList 1 float64":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x0c, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x00, 0x00, 0x0c, 0, 0, 0, 0, 0, 0, 0, 0
    ]
    var (file, filename) = createTestFile(buffer)
    defer:
      file.close()
      removeFile(filename)

    let entry = getIFDEntry(buffer, bigEndian, 0)
    var list = readValueList(file, entry)
    check(list.len == 1)
    check($list == "[0.0]")


  test "test readValueList 1 rationals":
    # rationals are two uint32, a numerator and denominator.
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x05, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x00, 0x00, 0x0c, 0, 0, 0, 1, 0, 0, 0, 2
    ]
    var (file, filename) = createTestFile(buffer)
    defer:
      file.close()
      removeFile(filename)

    let entry = getIFDEntry(buffer, bigEndian, 0)
    var list = readValueList(file, entry)
    check(list.len == 1)
    check($list == "[[1,2]]")


  test "test readValueList 0 rationals":
    # rationals are two uint32, a numerator and denominator.
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00,
      0x00, 0x00, 0x00, 0x00
    ]
    var (file, filename) = createTestFile(buffer)
    defer:
      file.close()
      removeFile(filename)

    let entry = getIFDEntry(buffer, bigEndian, 0)
    var list = readValueList(file, entry)
    check(list.len == 0)
    check($list == "[]")


  test "test readValueList 1 srationals":
    # srationals are two int32, a numerator and denominator.
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x00, 0x00, 0x0c, 0xff, 0xff, 0xff, 0xff, 0, 0, 0, 2
    ]
    var (file, filename) = createTestFile(buffer)
    defer:
      file.close()
      removeFile(filename)

    let entry = getIFDEntry(buffer, bigEndian, 0)
    var list = readValueList(file, entry)
    check(list.len == 1)
    check($list == "[[-1,2]]")


  test "test readValueList 2 float32":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x0b, 0x00, 0x00, 0x00, 0x02,
      0x00, 0x00, 0x00, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
    ]
    var (file, filename) = createTestFile(buffer)
    defer:
      file.close()
      removeFile(filename)

    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var list = readValueList(file, entry)
    # echo $list
    check(list.len == 2)
    check($list == "[0.0,0.0]")


  test "test readValueList 2 rationals":
    # rationals are two uint32, a numerator and denominator.
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x05, 0x00, 0x00, 0x00, 0x02,
      0x00, 0x00, 0x00, 0x0c, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 0, 0, 4
    ]
    var (file, filename) = createTestFile(buffer)
    defer:
      file.close()
      removeFile(filename)

    let entry = getIFDEntry(buffer, bigEndian, 0)
    var list = readValueList(file, entry)
    check(list.len == 2)
    check($list == "[[1,2],[3,4]]")

    test "kind values":
      check(ord(Kind.bytes) == 1)
      check(ord(Kind.strings) == 2)
      check(ord(Kind.shorts) == 3)
      check(ord(Kind.longs) == 4)
      check(ord(Kind.rationals) == 5)
      check(ord(Kind.sbytes) == 6)
      check(ord(Kind.blob) == 7)
      check(ord(Kind.sshorts) == 8)
      check(ord(Kind.slongs) == 9)
      check(ord(Kind.srationals) == 10)
      check(ord(Kind.floats) == 11)
      check(ord(Kind.doubles) == 12)
      check(ord(low(Kind)) == 1)
      check(ord(high(Kind)) == 12)

  test "test readIFD":
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    const headerOffset:uint32 = 0
    let (ifdOffset, endian) = readHeader(file, headerOffset)
    check(ifdOffset == 8)
    check(endian == littleEndian)

    var ranges = newSeq[Range]()
    let ifdInfo = readIFD(file, 1, headerOffset, ifdOffset, endian, "test", ranges)

    # echo ""
    # for node in ifdInfo.nodeList:
    #    echo node.name
    # echo ""
    # for next in ifdInfo.nextList:
    #    echo "$1 $2" % [next.name, $next.offset]

    check(ifdInfo.nodeList.len == 3)
    check(ifdInfo.nodeList[0].name == "test")
    check(ifdInfo.nodeList[1].name == "xmp")
    check(ifdInfo.nodeList[2].name == "image")

    check(ifdInfo.nextList.len == 3)
    check(ifdInfo.nextList[0].name == "ifd")
    check(ifdInfo.nextList[0].offset == 16388)
    check(ifdInfo.nextList[1].name == "ifd")
    check(ifdInfo.nextList[1].offset == 36698)
    check(ifdInfo.nextList[2].name == "exif")
    check(ifdInfo.nextList[2].offset == 36962)

    # for range in ranges:
    #    echo $range

    check(ranges.len > 1)

  test "test readBlob":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x07, # kind blob
      0x00, 0x00, 0x00, 0x05, # count
      0x00, 0x00, 0x00, 0x0c, # packed
      0x00, 0x01, 0x02, 0x03, 0x04, # blob
    ]
    var (file, filename) = createTestFile(buffer)
    defer:
      file.close()
      removeFile(filename)

    let entry = getIFDEntry(buffer, bigEndian, 0)
    var blob = readBlob(file, entry)
    check(blob.len == 5)
    check($blob == "@[0, 1, 2, 3, 4]")

  test "test readBlob less 5":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x07, # kind blob
      0x00, 0x00, 0x00, 0x04, # count
      0x09, 0x08, 0x07, 0x06, # packed
    ]
    var (file, filename) = createTestFile(buffer)
    defer:
      file.close()
      removeFile(filename)

    let entry = getIFDEntry(buffer, bigEndian, 0)
    var blob = readBlob(file, entry)
    check(blob.len == 4)
    check($blob == "@[9, 8, 7, 6]")

  test "test readBlob wrong kind":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x02, # kind string
      0x00, 0x00, 0x00, 0x04, # count
      0x65, 0x66, 0x67, 0x00, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()

    # kind should be blob or bytes
    expect NotSupportedError:
      discard readBlob(file, entry)

  test "readOneNumber long":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x04, # kind, long
      0x00, 0x00, 0x00, 0x01, # count
      0x12, 0x34, 0x56, 0x78, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    var number = readOneNumber(file, entry)
    check(toHex0(number) == "12345678")

  test "readOneNumber short":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x03, # kind, long
      0x00, 0x00, 0x00, 0x01, # count
      0x12, 0x34, 0x56, 0x78, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    var number = readOneNumber(file, entry)
    check(toHex0(number) == "1234")

  test "readOneNumber byte":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x01, # kind, long
      0x00, 0x00, 0x00, 0x01, # count
      0x12, 0x34, 0x56, 0x78, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    var number = readOneNumber(file, entry)
    check(toHex0(number) == "12")

  test "readOneNumber sbyte":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x06, # kind, long
      0x00, 0x00, 0x00, 0x01, # count
      0xff, 0xff, 0xff, 0xfe, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    var number = readOneNumber(file, entry)
    check(number == -1)

  test "readOneNumber sshort":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x08, # kind, long
      0x00, 0x00, 0x00, 0x01, # count
      0xff, 0xff, 0xff, 0xfe, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    var number = readOneNumber(file, entry)
    check(number == -1)

  test "readOneNumber slong":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x09, # kind, long
      0x00, 0x00, 0x00, 0x01, # count
      0xff, 0xff, 0xff, 0xfe, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    var number = readOneNumber(file, entry)
    check(number == -2)

  test "readOneNumber invalid count":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x09, # kind, long
      0x00, 0x00, 0x00, 0x02, # count
      0xff, 0xff, 0xff, 0xfe, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()

    try:
      var number = readOneNumber(file, entry)
      echo number
      fail()
    except NotSupportedError:
      # echo getCurrentExceptionMsg()
      discard

  test "readOneNumber number too big":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x04, # kind, long
      0x00, 0x00, 0x00, 0x01, # count
      0xff, 0xff, 0xff, 0xfe, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()

    try:
      var number = readOneNumber(file, entry)
      echo number
      fail()
    except NotSupportedError:
      # echo getCurrentExceptionMsg()
      discard

  test "readOneNumber not number":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x02, # kind, string
      0x00, 0x00, 0x00, 0x01, # count
      0xff, 0xff, 0xff, 0xfe, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()

    try:
      var number = readOneNumber(file, entry)
      echo number
      fail()
    except NotSupportedError:
      # echo getCurrentExceptionMsg()
      discard

  test "readLongs":
    # proc readLongs*(file: File, entry: IFDEntry, maximum: Natural): seq[uint32] =
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x04, # kind, long
      0x00, 0x00, 0x00, 0x01, # count
      0x00, 0x00, 0x00, 0x02, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()

    var numbers = readLongs(file, entry, 2)
    # echo numbers
    check(numbers == @[2'u32])

  test "readLongs zero":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x04, # kind, long
      0x00, 0x00, 0x00, 0x00, # count
      0x00, 0x00, 0x00, 0x02, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()

    var numbers = readLongs(file, entry, 2)
    # echo numbers
    check(numbers.len == 0)

  test "readLongs two":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x04, # kind, long
      0x00, 0x00, 0x00, 0x02, # count
      0x00, 0x00, 0x00, 0x08, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()

    var numbers = readLongs(file, entry, 2)
    # echo numbers
    check(numbers == @[687930880'u32, 67109120'u32])

  test "readLongs too many":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x04, # kind, long
      0x00, 0x00, 0x00, 0x02, # count
      0x00, 0x00, 0x00, 0x08, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()

    try:
      var numbers = readLongs(file, entry, 1)
      echo numbers
    except NotSupportedError:
      # echo getCurrentExceptionMsg()
      discard

  test "readLongs not long":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x01, # kind, byte
      0x00, 0x00, 0x00, 0x02, # count
      0x00, 0x00, 0x00, 0x08, # packed
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()

    try:
      var numbers = readLongs(file, entry, 2)
      echo numbers
    except NotSupportedError:
      # echo getCurrentExceptionMsg()
      discard

  test "test readValueListMax":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x01, # kind, byte
      0x00, 0x00, 0x00, 0x02, # count
      0x00, 0x01, 0x02, 0x03, # packed
    ]
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var file: File
    var list = readValueListMax(file, entry, 2)
    check(list.len == 2)
    check($list == "[0,1]")

  test "test readValueListMax too many":
    var buffer = [
      0x00'u8, 0xFE, # tag
      0x00, 0x01, # kind, byte
      0x00, 0x00, 0x00, 0x02, # count
      0x00, 0x00, 0x00, 0x08, # packed
    ]
    let endian = bigEndian
    let entry = getIFDEntry(buffer, endian, 0)
    # echo $entry
    var file: File
    var json = readValueListMax(file, entry, 1)
    check(json.getStr == "2 bytes starting at 8")

  test "readExif":
    var file = openTestFile("testfiles/IMG_6093.JPG")
    defer: file.close()
    var ranges = newSeq[Range]()
    var node = readExif(file, 46'u32, 4796'u32, ranges)
    # echo node
    check(node.kind == JObject)

  test "readTiff":
    var file = openTestFile("testfiles/image.dng")
    defer: file.close()
    var metadata = readTiff(file)
    # echo metadata
    check(metadata.kind == JObject)

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
