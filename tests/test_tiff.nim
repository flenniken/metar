import os
import metadata
import unittest
import testFile
import tiff
import readNumber
import hexDump

proc dumpTestFile(filename: string, startOffset: int64, length: Natural) =
  ## Hex dump a section of the given file.

  var file = openTestFile(filename)
  defer: file.close()
  var buffer = newSeq[uint8](length)
  file.setFilePos(startOffset)
  if file.readBytes(buffer, 0, length) != length:
    raise newException(IOError, "Unable to read the file.")
  echo hexDump(buffer, (uint16)startOffset)
  echo hexDumpSource(buffer)


suite "test tiff.nim":

  test "test readHeader big":
    # Test big endian header
    var bytes = [0x4d'u8, 0x4d, 0x00, 0x2a, 0x12, 0x34, 0x56, 0x78]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)

    let (offset, endian) = readHeader(file, 0)
    check(offset == (int64)0x12345678)
    check(endian == bigEndian)

  test "test readHeader little":
    # Test little endian header
    var bytes = [0x49'u8, 0x49, 0x2a, 0x00, 0x78, 0x56, 0x34, 0x12]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)

    let (offset, endian) = readHeader(file, 0)
    check(offset == 0x12345678'i64)
    check(endian == littleEndian)

  test "test readHeader non-zero offset":
    # test header that does not start at 0.
    var bytes = [0x22'u8, 0x33, 0x00, 0x4d, 0x4d, 0x00, 0x2a, 0x12, 0x34, 0x56, 0x78]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)

    let (offset, endian) = readHeader(file, 3)
    check(offset == 0x12345678'i64)
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
    check(offset == 0x08'i64)
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
    check(ifdOffset == 0x08'i64)
    check(endian == littleEndian)

    # Read the number of IFD entries.
    let ifdCount = readNumber[uint16](file)
    check(ifdCount == 14)

    # Read the first entry and test the string representation.
    const bufferSize = 12*14
    var buffer: array[bufferSize, uint8]
    if file.readBytes(buffer, 0, bufferSize) != bufferSize:
      raise newException(IOError, "Unable to read the file.")

    let entry = getIFDEntry(buffer, endian)
    let expected = "NewSubfileType(254, 00FEh), 1 longs, packed: 00 00 00 00"
    check($entry == expected)

    # Loop through the 14 IDF entries.
    for ix in 0..14-1:
      let entry = getIFDEntry(buffer, endian, ix*12)
      # echo $entry


  test "test getIFDEntry bigEndian":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x04, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian)
    let expected = "NewSubfileType(254, 00FEh), 5 longs, packed: 00 01 02 03"
    check($entry == expected)
    # echo $entry

  test "test getIFDEntry index":
    var buffer = [
      0x00'u8, 0x00, 0x00, 0xFE, 0x00, 0x04, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x01, 0x02, 0x03,
    ]
    let entry = getIFDEntry(buffer, bigEndian, 2)
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
      discard getIFDEntry(buffer, bigEndian, 2)
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
      discard getIFDEntry(buffer, bigEndian)
    except NotSupportedError:
      # echo getCurrentExceptionMsg()
      gotException = true
    check(gotException == true)

  test "test getIFDEntry invalid kind":
    var buffer = [
      0x00'u8, 0xFE, 0x00, 0x22, 0x00, 0x00, 0x00, 0x05,
      0x00, 0x01, 0x02, 0x03,
    ]
    var gotException = false
    try:
      discard getIFDEntry(buffer, bigEndian)
    except NotSupportedError:
      # echo getCurrentException().name
      # echo getCurrentExceptionMsg()
      gotException = true
    check(gotException == true)
