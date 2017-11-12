import os
import strutils
import unittest
import readBytes

let filename = "/tmp/test.bin"
var testFile: File
var buffer = [0x01'u8, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef]

suite "Test readBytes.nim":

  setup:
    # Create a test file.
    if open(testFile, filename, fmWrite):
      var bytes = [01'u8, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef]
      discard testFile.writeBytes(bytes, 0, bytes.len)
      var d: float = 1.234
      discard testFile.writeBuffer(addr(d), sizeof(d))
      var d32: float32 = 67.34
      discard testFile.writeBuffer(addr(d32), sizeof(d32))
      var i16: int16 = -42
      discard testFile.writeBuffer(addr(i16), sizeof(i16))
      testFile.close()
    else:
      echo "Unable to create the file: ", filename

    if not open(testFile, filename, fmRead):
      assert(false, "unable to open the file")

  teardown:
    testFile.close()
    discard tryRemoveFile(filename)

  test "read int8":
    testFile.setFilePos(0)
    var v8 = read_number[uint8](testFile)
    # echo "v8 = ", toHex(v8)
    require(v8 == 0x01)

    testFile.setFilePos(0)
    v8 = read_number[uint8](testFile, bigEndian)
    # echo "require(v8 == 0x", toHex(v8), ")"
    require(v8 == 0x01)

    testFile.setFilePos(0)
    var i8 = read_number[int8](testFile, bigEndian)
    # echo "require(i8 == 0x", toHex(i8), ")"
    require(i8 == 0x01)

    testFile.setFilePos(0)
    i8 = read_number[int8](testFile)
    # echo "require(i8 == 0x", toHex(i8), ")"
    require(i8 == 0x01)

  test "read int16":

    testFile.setFilePos(0)
    var v16 = read_number[uint16](testFile)
    # echo "require(v16 == 0x", toHex(v16), ")"
    require(v16 == 0x2301)

    testFile.setFilePos(0)
    v16 = read_number[uint16](testFile, bigEndian)
    # echo "require(v16 == 0x", toHex(v16), ")"
    require(v16 == 0x0123)

    testFile.setFilePos(0)
    var i16 = read_number[int16](testFile, bigEndian)
    # echo "require(i16 == 0x", toHex(i16), ")"
    require(i16 == 0x0123)

    testFile.setFilePos(0)
    i16 = read_number[int16](testFile)
    # echo "require(i16 == 0x", toHex(i16), ")"
    require(i16 == 0x2301)

  test "read int32":

    testFile.setFilePos(0)
    var v32 = read_number[uint32](testFile)
    # echo "require(v32 == 0x", toHex(v32), ")"
    require(v32 == 0x67452301)

    testFile.setFilePos(0)
    v32 = read_number[uint32](testFile, bigEndian)
    # echo "require(v32 == 0x", toHex(v32), ")"
    require(v32 == 0x01234567)

    testFile.setFilePos(0)
    var i32 = read_number[int32](testFile, bigEndian)
    # echo "require(i32 == 0x", toHex(i32), ")"
    require(i32 == 0x01234567)

    testFile.setFilePos(0)
    i32 = read_number[int32](testFile)
    # echo "require(i32 == 0x", toHex(i32), ")"
    require(i32 == 0x67452301)

  test "read int64":

    testFile.setFilePos(0)
    var v64 = read_number[uint64](testFile)
    # echo "require(v64 == 0x", toHex(v64), ")"
    require(v64 == 0xEFCDAB8967452301'u64)

    testFile.setFilePos(0)
    v64 = read_number[uint64](testFile, bigEndian)
    # echo "require(v64 == 0x", toHex(v64), ")"
    require(v64 == 0x0123456789ABCDEF'u64)

    testFile.setFilePos(0)
    var i64 = read_number[int64](testFile, bigEndian)
    # echo "require(i64 == 0x", toHex(i64), ")"
    require(i64 == 0x0123456789ABCDEF'i64)

    testFile.setFilePos(0)
    i64 = read_number[int64](testFile)
    # echo "require(i64 == 0x", toHex(i64), ")"
    require(i64 == 0xEFCDAB8967452301)

  test "read float64":

    testFile.setFilePos(8)
    var f64 = read_number[float64](testFile, system.cpuEndian)
    # echo "require(f64 == ", f64, ")"
    require(f64 == 1.234)

  test "read float32":

    testFile.setFilePos(16)
    var f32 = read_number[float32](testFile, system.cpuEndian)
    # echo "require(f32 == ", f32, ")"
    require(f32 == 67.33999633789062)

  test "read negative int":

    testFile.setFilePos(20)
    var neg = read_number[int16](testFile, system.cpuEndian)
    # echo "require(neg == ", neg, ")"
    require(neg == -42)

  test "read invalid file position":
    expect IOError:
      testFile.setFilePos(300)
      var v8 = read_number[uint8](testFile)
      # echo "v8 = ", toHex(v8)
      require(v8 == 0x01)

  test "length 16":

    var num16: uint16

    let expected = ["2301", "4523", "6745", "8967", "AB89", "CDAB",
                    "EFCD", "0123", "2345", "4567", "6789", "89AB",
                    "ABCD", "CDEF"]

    for index in 0..6:
      num16 = length[uint16](buffer, index)
      # echo toHex(num16)
      require(expected[index] == toHex(num16))

    let ex2 = ["0123", "2345", "4567", "6789", "89AB", "ABCD", "CDEF"]
    for index in 0..6:
      num16 = length[uint16](buffer, index, bigEndian)
      # echo toHex(num16)
      require(ex2[index] == toHex(num16))

  test "length 8":

    let ex3 = ["01", "23", "45", "67", "89", "AB", "CD", "EF", "01",
               "23", "45", "67", "89", "AB", "CD", "EF"]
    for index in 0..7:
      var num8 = length[uint8](buffer, index)
      # echo toHex(num8)
      require(ex3[index] == toHex(num8))

    let ex4 = ["01", "23", "45", "67", "89", "AB", "CD", "EF"]
    for index in 0..7:
      var num8 = length[uint8](buffer, index, bigEndian)
      # echo toHex(num8)
      require(ex4[index] == toHex(num8))

  test "length 32":

    let ex5 = ["67452301", "89674523", "AB896745", "CDAB8967", "EFCDAB89"]
    for index in 0..4:
      var num32 = length[uint32](buffer, index)
      # echo toHex(num32)
      require(ex5[index] == toHex(num32))

    let ex6 = ["01234567", "23456789", "456789AB", "6789ABCD", "89ABCDEF"]
    for index in 0..4:
      var num8 = length[uint32](buffer, index, bigEndian)
      # echo toHex(num8)
      require(ex6[index] == toHex(num8))

  test "length 64":

    var num64 = length[uint64](buffer)
    # echo toHex(num64)
    require("EFCDAB8967452301" == toHex(num64))

    num64 = length[uint64](buffer, 0, bigEndian)
    # echo toHex(num64)
    require("0123456789ABCDEF" == toHex(num64))

  test "length invalid number, string":
    expect AssertionError:
      var value = length[string](buffer)

  test "length invalid number, char":
    expect AssertionError:
      var value = length[char](buffer)
