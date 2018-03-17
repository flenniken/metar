import os
import metadata
import unittest
import testUtils
import tiff
import readBytes

suite "test tiff.nim":

  test "test readHeader big":
    var bytes = [0x4d'u8, 0x4d, 0x00, 0x2a, 0x12, 0x34]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)

    let (offset, endian) = readHeader(file, 0)
    check(offset == (uint16)0x1234)
    check(endian == bigEndian)

  test "test readHeader little":
    var bytes = [0x49'u8, 0x49, 0x2a, 0x00, 0x34, 0x12]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)

    let (offset, endian) = readHeader(file, 0)
    check(offset == (uint16)0x1234)
    check(endian == littleEndian)

  test "test readHeader non-zero offset":
    var bytes = [0x22'u8, 0x33, 0x00, 0x4d, 0x4d, 0x00, 0x2a, 0x12, 0x34]
    var (file, filename) = createTestFile(bytes)
    defer:
      file.close()
      removeFile(filename)

    let (offset, endian) = readHeader(file, 3)
    check(offset == (uint16)0x1234)
    check(endian == bigEndian)
    
  test "test readHeader invalid order":
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
    var bytes = [0x4d'u8, 0x4d, 0x00, 0x2b, 0x12, 0x34]
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
