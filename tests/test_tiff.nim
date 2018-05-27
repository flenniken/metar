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
import readerJpeg # todo: remove this by moving dependent methods out

proc dumpTestFile(filename: string, startOffset: int64, length: Natural) =
  ## Hex dump a section of the given file.

  var file = openTestFile(filename)
  defer: file.close()
  var buffer = newSeq[uint8](length)
  file.setFilePos(startOffset)
  if file.readBytes(buffer, 0, length) != length:
    raise newException(IOError, "Unable to read the file.")
  echo hexDump(buffer, (uint16)startOffset)
  # echo hexDumpSource(buffer)


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
    check(tagName((uint16)254) == "NewSubfileType")
    check(tagName((uint16)255) == "SubfileType")
    check(tagName((uint16)256) == "ImageWidth")
    check(tagName((uint16)257) == "ImageLength")

    check(tagName((uint16)0) == "")
    check(tagName((uint16)60123) == "")

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
    let expected = "NewSubfileType(254, 00FEh), 1 longs, packed: 00 00 00 00"
    check($entry == expected)

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
    let expected = "NewSubfileType(254, 00FEh), 5 longs, packed: 00 01 02 03"
    check($entry == expected)
    # echo $entry

  test "test getIFDEntry index":
    var buffer = [
      0x00'u8, 0x00, 0x00, 0xFE, 0x00, 0x04, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 0, 2)
    let expected = "NewSubfileType(254, 00FEh), 5 longs, packed: 00 01 02 03"
    check($entry == expected)
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
    check(ifdInfo.nodeList.len == 3)
    check(ifdInfo.nodeList[0].name == "test")
    check(ifdInfo.nodeList[1].name == "xmp")
    check(ifdInfo.nodeList[2].name == "image")

    # for range in ranges:
    #   echo $range

# (start: 568, finish: 7537, name: "xmp", message: "", known: true)
# (start: 8, finish: 500, name: "test", message: "", known: true)
# (start: 506, finish: 7537, name: "test", message: "", known: true)
# (start: 7538, finish: 16387, name: "test", message: "", known: true)
# (start: 37312, finish: 168640, name: "image1", message: "", known: true)

    check(ranges.len == 5)
    check(ranges[0].name == "xmp")
    check(ranges[0].start == 568)
    check(ranges[0].finish == 7537)
    check(ranges[1].name == "test")
    check(ranges[2].name == "test")
    check(ranges[3].name == "test")
    check(ranges[4].name == "image1")

    check(ifdInfo.nextList.len == 3)
    check(ifdInfo.nextList[0].name == "ifd")
    check(ifdInfo.nextList[1].name == "ifd")
    check(ifdInfo.nextList[2].name == "exif")

    let image = ifdInfo.nodeList[2].node
    # echo $image

    check(image["name"].getStr() == "8")
    check(image["width"].getInt() == 256)
    check(image["height"].getInt() == 171)
    check($image["pixels"] == "[[37312,168640]]")

    # for info in ifdInfo.nodeList:
    #   let (name, node) = info
    #   var metadata = newJObject()
    #   metadata[name] = node
    #   echo readable(metadata, "tiff")

  test "test mergeOffsets empty":
    let list: seq[tuple[start: uint32, finish: uint32]] = @[]
    let (minList, gapList) = mergeOffsets(list)
    check(minList.len == 0)
    check(gapList.len == 0)

  test "test mergeOffsets 1":
    let list = @[(5'u32, 10'u32)]
    let (minList, gapList) = mergeOffsets(list)
    check(minList.len == 1)
    check(gapList.len == 0)
    check(minList == list)

  test "test mergeOffsets 2":
    let list = @[(5'u32, 10'u32), (10'u32, 30'u32)]
    let expected = @[(5'u32, 30'u32)]
    let (minList, gapList) = mergeOffsets(list)
    check(minList.len == 1)
    check(gapList.len == 0)
    check(minList == expected)

  test "test mergeOffsets 3":
    let list = @[(5'u32, 10'u32), (20'u32, 30'u32)]
    let expectedGap = @[(10'u32, 20'u32)]
    let (minList, gapList) = mergeOffsets(list)
    check(minList.len == 2)
    check(gapList.len == 1)
    check(minList == list)
    check(gapList == expectedGap)

  test "test mergeOffsets 4":
    let list = @[(0'u32, 0'u32), (20'u32, 30'u32)]
    let expectedMin = @[(20'u32, 30'u32)]
    let expectedGap = @[(0'u32, 20'u32)]
    let (minList, gapList) = mergeOffsets(list)
    check(minList.len == 1)
    check(gapList.len == 1)
    check(minList == expectedMin)
    check(gapList == expectedGap)

  test "test mergeOffsets 5":
    let list = @[(20'u32, 30'u32), (40'u32, 40'u32)]
    let expectedMin = @[(20'u32, 30'u32)]
    let expectedGap = @[(30'u32, 40'u32)]
    let (minList, gapList) = mergeOffsets(list)
    check(minList.len == 1)
    check(gapList.len == 1)
    check(minList == expectedMin)
    check(gapList == expectedGap)

  test "test mergeOffsets 6":
    let list = @[(0'u32, 0'u32), (20'u32, 30'u32), (40'u32, 40'u32)]
    let expectedMin = @[(20'u32, 30'u32)]
    let expectedGap = @[(0'u32, 20'u32), (30'u32, 40'u32)]
    let (minList, gapList) = mergeOffsets(list)
    check(minList.len == 1)
    check(gapList.len == 2)
    check(minList == expectedMin)
    check(gapList == expectedGap)

  test "test mergeOffsets 7":
    let list = @[(0'u32, 40'u32), (20'u32, 45'u32), (40'u32, 60'u32)]
    let expectedMin = @[(0'u32, 60'u32)]
    let (minList, gapList) = mergeOffsets(list)
    check(minList.len == 1)
    check(gapList.len == 0)
    check(minList == expectedMin)

  # padding is on even byte boundries.

  test "test mergeOffsets padding 1":
    # Not on padding value.
    let list = @[(0'u32, 39'u32), (41'u32, 45'u32)]
    let expectedMin = @[(0'u32, 39'u32), (41'u32, 45'u32)]
    let expectedGap = @[(39'u32, 41'u32)]
    let (minList, gapList) = mergeOffsets(list, paddingShift = 1)
    check(minList.len == 2)
    check(gapList.len == 1)
    check(minList == expectedMin)
    check(gapList == expectedGap)

  test "test mergeOffsets padding 2":
    # On padding value.
    let list = @[(0'u32, 39'u32), (40'u32, 49'u32)]
    let expectedMin = @[(0'u32, 49'u32)]
    let (minList, gapList) = mergeOffsets(list, paddingShift = 1)
    check(minList.len == 1)
    check(gapList.len == 0)
    check(minList == expectedMin)

  test "test mergeOffsets padding 3":
    # Not on padding
    let list = @[(0'u32, 37'u32), (49'u32, 55'u32)]
    let expectedMin = list
    let expectedGap = @[(37'u32, 49'u32)]
    let (minList, gapList) = mergeOffsets(list, paddingShift = 1)
    check(minList.len == 2)
    check(gapList.len == 1)
    check(minList == expectedMin)
    check(gapList == expectedGap)

  # test "test boundry":
  #   for finish in 0..33:
  #     let boundry = ((finish shr 3) + 1) shl 3
  #     echo "finish = " & $finish & " boundry = " & $boundry
