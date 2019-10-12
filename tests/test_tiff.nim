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
import tiffTags
import ranges
import tables

proc dumpIfdInfo(ifdinfo: IFDInfo) =
  echo "nodeList ="
  for item in ifdInfo.nodeList:
    echo item.name & ":"
    var jsonString: string
    toUgly(jsonString, item.node)
    echo jsonString

  echo "nextList = "
  for next in ifdInfo.nextList:
     echo "$1 $2" % [next.name, $next.offset]


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

    let entry = getIFDEntry(buffer[0..12-1], endian, 0)
    let expected = "NewSubfileType(254), 1 longs, packed: 00 00 00 00"
    check(entry.tag == 254'u16)
    check(entry.kind == Kind.longs)
    check(entry.count == 1)
    check(entry.packed == [0'u8, 0, 0, 0])
    check(entry.endian == endian)
    check(entry.headerOffset == 0)

    # Loop through the 14 IDF entries.
    for ix in 0..14-1:
      let start = ix*12
      let entry = getIFDEntry(buffer[start..start+12-1], endian, 0)
      # echo $entry
      check(entry.headerOffset == 0)
      check(entry.endian == endian)
      # echo $entry


  test "test getIFDEntry bigEndian":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x04, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    check(entry.tag == 254'u16)
    check(entry.kind == Kind.longs)
    check(entry.count == 5)
    check(entry.packed == [0'u8, 1, 2, 3])
    check(entry.endian == bigEndian)
    check(entry.headerOffset == 0)
    check($entry == "NewSubfileType(254), 5 longs, offset: 66051")

  test "test getIFDEntry bytes":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x01, 0x00, 0x00, 0x00, 0x04,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    check($entry == "NewSubfileType(254), 4 bytes, values: [0,1,2,3]")

  test "test getIFDEntry shorts":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x03, 0x00, 0x00, 0x00, 0x02,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    check($entry == "NewSubfileType(254), 2 shorts, values: [1,515]")

  test "test getIFDEntry longs":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x04, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    check($entry == "NewSubfileType(254), 1 longs, values: [66051]")

  test "test getIFDEntry 3 shorts":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x03, 0x00, 0x00, 0x00, 0x03,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0)
    check($entry == "NewSubfileType(254), 3 shorts, offset: 66051")

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

  test "test readValueList 1 float64":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x0c, 0x00, 0x00, 0x00, 0x01,
      0x00, 0x00, 0x00, 0x0c, 0, 0, 0, 0, 0, 0, 0, 0
    ]
    var (file, filename) = createTestFile(buffer)
    defer:
      file.close()
      removeFile(filename)

    let entry = getIFDEntry(buffer[0..12-1], bigEndian, 0)
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

    let entry = getIFDEntry(buffer[0..12-1], bigEndian, 0)
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

    let entry = getIFDEntry(buffer[0..12-1], bigEndian, 0)
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
    let entry = getIFDEntry(buffer[0..12-1], endian, 0)
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

    let entry = getIFDEntry(buffer[0..12-1], bigEndian, 0)
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

    let entry = getIFDEntry(buffer[0..12-1], bigEndian, 0)
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

  # test "readExif":
  #   var file = openTestFile("testfiles.save/IMG_6093.JPG")
  #   defer: file.close()
  #   var ranges = newSeq[Range]()
  #   var node = readExif(file, 46'u32, 4796'u32, ranges)
  #   # echo node
  #   check(node.kind == JObject)

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

  # test "test readIFD2":
  #   let filename = "testfiles/single-channel.ome.tif"
  #   var file = openTestFile(filename)
  #   # var file = openTestFile("testfiles/MARBLES.TIF")

  #   # Read the IFD info and set the ranges.
  #   var ranges = newSeq[Range]()
  #   const headerOffset:uint32 = 0
  #   let (ifdOffset, endian) = readHeader(file, headerOffset)
  #   echo "filename = $1" % [$filename]
  #   echo "ifdOffset = $1" % [$ifdOffset]
  #   echo "endian = $1" % [$endian]
  #   var id = 1
  #   var ifdInfo = readIFD(file, id, headerOffset, ifdOffset, endian, "nodeName", ranges)
  #   dumpIfdInfo(ifdInfo)

  # test "dump ifd entries":
  #   let filenames = [
  #     "testfiles/A0_200_T.TIF",
  #     "testfiles/101.tif",
  #     "testfiles/single-channel.ome.tif",
  #     "testfiles/multipage_tiff_example.tif",
  #     "testfiles/Multi_page24bpp.tif",
  #     "testfiles/image.tif",
  #     "testfiles/MARBLES.TIF",
  #   ]

  #   for filename in filenames:
  #     var file = openTestFile(filename)
  #     defer: file.close()

  #     let headerOffset = 0u32
  #     let (ifdOffset, endian) = readHeader(file, headerOffset)
  #     # echo "filename = $1" % [$filename]
  #     # echo "ifdOffset = $1" % [$ifdOffset]
  #     # echo "endian = $1" % [$endian]

  #     let start: uint32 = headerOffset + ifdOffset
  #     file.setFilePos((int64)start)
  #     var numberEntries = (int)readNumber[uint16](file, endian)
  #     # echo "numberEntries = $1" % [$numberEntries]

  #     let bufferSize = 12 * numberEntries
  #     var buffer = newSeq[uint8](bufferSize)
  #     if file.readBytes(buffer, 0, bufferSize) != bufferSize:
  #       fail()
  #     # echo hexDumpSource(buffer, 12)

  test "test getIFDEntries":

    # header: 2 endian, 2 magic number, 4 IFD offset
    # 0x4D'u8, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08,

    # 0x00, 0x10, # number of entries

    # entries from testfiles/single-channel.ome.tif
    # 2 tag bytes, 2 kind bytes, 4 count bytes, 4 packed bytes
    var buffer = [
      0x01'u8, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0xB7,
      0x01, 0x01, 0x00, 0x04, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0xA7,
      0x01, 0x02, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x08, 0x00, 0x00,
      0x01, 0x03, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
      0x01, 0x06, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
      0x01, 0x0E, 0x00, 0x02, 0x00, 0x00, 0x04, 0x74, 0x00, 0x01, 0x24, 0xCB,
      0x01, 0x11, 0x00, 0x04, 0x00, 0x00, 0x00, 0xA7, 0x00, 0x00, 0x01, 0x0C,
      0x01, 0x15, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
      0x01, 0x16, 0x00, 0x04, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x01, 0x17, 0x00, 0x04, 0x00, 0x00, 0x00, 0xA7, 0x00, 0x00, 0x03, 0xA8,
      0x01, 0x1A, 0x00, 0x05, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x06, 0x44,
      0x01, 0x1B, 0x00, 0x05, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x06, 0x4C,
      0x01, 0x1C, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
      0x01, 0x28, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x03, 0x00, 0x00,
      0x01, 0x31, 0x00, 0x02, 0x00, 0x00, 0x00, 0x16, 0x00, 0x00, 0x06, 0x54,
      0x01, 0x53, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, 0x02, 0x00, 0x00,
    ]

    # Read the IFD info and set the ranges.
    const headerOffset:uint32 = 0
    const ifdOffset = 8
    const endian = bigEndian
    var ranges = newSeq[Range]()
    let entries = getIFDEntries(buffer, headerOffset, ifdOffset, endian, "nodeName", ranges)

    check(entries.len == 16)
    check(ranges.len == 0)

    check($entries[0] == "ImageWidth(256), 1 longs, values: [439]")
    check($entries[1] == "ImageHeight(257), 1 longs, values: [167]")
    check($entries[2] == "BitsPerSample(258), 1 shorts, values: [8]")
    check($entries[3] == "Compression(259), 1 shorts, values: [1]")
    check($entries[4] == "PhotometricInterpretation(262), 1 shorts, values: [1]")
    check($entries[5] == "ImageDescription(270), 1140 strings, offset: 74955")
    check($entries[6] == "StripOffsets(273), 167 longs, offset: 268")
    check($entries[7] == "SamplesPerPixel(277), 1 shorts, values: [1]")
    check($entries[8] == "RowsPerStrip(278), 1 longs, values: [1]")
    check($entries[9] == "StripByteCounts(279), 167 longs, offset: 936")
    check($entries[10] == "XResolution(282), 1 rationals, offset: 1604")
    check($entries[11] == "YResolution(283), 1 rationals, offset: 1612")
    check($entries[12] == "PlanarConfiguration(284), 1 shorts, values: [1]")
    check($entries[13] == "ResolutionUnit(296), 1 shorts, values: [3]")
    check($entries[14] == "Software(305), 22 strings, offset: 1620")
    check($entries[15] == "SampleFormat(339), 1 shorts, values: [2]")

    # for entry in entries:
    #   echo $entry

  test "test getIFDEntries no entriestest":
    var buffer: array[0, uint8] = []
    const headerOffset:uint32 = 0
    const ifdOffset = 8
    const endian = bigEndian
    var ranges = newSeq[Range]()
    var message = ""
    try:
      let entries = getIFDEntries(buffer, headerOffset, ifdOffset, endian, "nodeName", ranges)
    except NotSupportedError:
      message = getCurrentExceptionMsg()
    check(message == "Invalid entries buffer size.")

  test "test getIFDEntries error":
    # 2 tag bytes, 2 kind bytes, 4 count bytes, 4 packed bytes
    var buffer = [
      0x01'u8, 0x00, 0x99, 0x04, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x01, 0xB7,
      0x01, 0x01, 0x00, 0x04, 0x8f, 0xff, 0x00, 0x01, 0x00, 0x00, 0x00, 0xA7,
    ]

    # Read the IFD info and set the ranges.
    const headerOffset:uint32 = 0
    const ifdOffset = 8
    const endian = bigEndian
    var ranges = newSeq[Range]()
    let entries = getIFDEntries(buffer, headerOffset, ifdOffset, endian, "nodeName", ranges)

    check(entries.len == 0)

    check(ranges.len == 2)
    check(ranges[0].start == 8)
    check(ranges[0].finish == 20)
    check(ranges[0].name == "nodeName-e")
    check(ranges[0].message == "IFD entry - Kind is not known: 39172")
    check(ranges[0].known == false)

    check(ranges.len == 2)
    check(ranges[1].start == 20)
    check(ranges[1].finish == 32)
    check(ranges[1].name == "nodeName-e")
    check(ranges[1].message == "IFD entry - Count is too big: 2415853569")
    check(ranges[1].known == false)
