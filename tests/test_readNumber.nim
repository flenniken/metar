import os
import strutils
import unittest
import readNumber

let filename = "/tmp/test.bin"
var testFile: File
var buffer = [0x01'u8, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef]

suite "Test readNumber.nim":

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
    var v8 = readNumber[uint8](testFile)
    # echo "v8 = ", toHex(v8)
    check(v8 == 0x01)

    testFile.setFilePos(0)
    v8 = read_number[uint8](testFile, bigEndian)
    # echo "check(v8 == 0x", toHex(v8), ")"
    check(v8 == 0x01)

    testFile.setFilePos(0)
    var i8 = read_number[int8](testFile, bigEndian)
    # echo "check(i8 == 0x", toHex(i8), ")"
    check(i8 == 0x01)

    testFile.setFilePos(0)
    i8 = read_number[int8](testFile)
    # echo "check(i8 == 0x", toHex(i8), ")"
    check(i8 == 0x01)

  test "read int16":

    testFile.setFilePos(0)
    var v16 = read_number[uint16](testFile)
    # echo "check(v16 == 0x", toHex(v16), ")"
    check(v16 == 0x2301)

    testFile.setFilePos(0)
    v16 = read_number[uint16](testFile, bigEndian)
    # echo "check(v16 == 0x", toHex(v16), ")"
    check(v16 == 0x0123)

    testFile.setFilePos(0)
    var i16 = read_number[int16](testFile, bigEndian)
    # echo "check(i16 == 0x", toHex(i16), ")"
    check(i16 == 0x0123)

    testFile.setFilePos(0)
    i16 = read_number[int16](testFile)
    # echo "check(i16 == 0x", toHex(i16), ")"
    check(i16 == 0x2301)

  test "read int32":

    testFile.setFilePos(0)
    var v32 = read_number[uint32](testFile)
    # echo "check(v32 == 0x", toHex(v32), ")"
    check(v32 == 0x67452301)

    testFile.setFilePos(0)
    v32 = read_number[uint32](testFile, bigEndian)
    # echo "check(v32 == 0x", toHex(v32), ")"
    check(v32 == 0x01234567)

    testFile.setFilePos(0)
    var i32 = read_number[int32](testFile, bigEndian)
    # echo "check(i32 == 0x", toHex(i32), ")"
    check(i32 == 0x01234567)

    testFile.setFilePos(0)
    i32 = read_number[int32](testFile)
    # echo "check(i32 == 0x", toHex(i32), ")"
    check(i32 == 0x67452301)

  test "read int64":

    testFile.setFilePos(0)
    var v64 = read_number[uint64](testFile)
    # echo "check(v64 == 0x", toHex(v64), ")"
    check(v64 == 0xEFCDAB8967452301'u64)

    testFile.setFilePos(0)
    v64 = read_number[uint64](testFile, bigEndian)
    # echo "check(v64 == 0x", toHex(v64), ")"
    check(v64 == 0x0123456789ABCDEF'u64)

    testFile.setFilePos(0)
    var i64 = read_number[int64](testFile, bigEndian)
    # echo "check(i64 == 0x", toHex(i64), ")"
    check(i64 == 0x0123456789ABCDEF'i64)

    testFile.setFilePos(0)
    i64 = read_number[int64](testFile)
    # echo "check(i64 == 0x", toHex(i64), ")"
    check(i64 == 0xEFCDAB8967452301)

  test "read float64":

    testFile.setFilePos(8)
    var f64 = read_number[float64](testFile, system.cpuEndian)
    # echo "check(f64 == ", f64, ")"
    check(f64 == 1.234)

  test "read float32":

    testFile.setFilePos(16)
    var f32 = read_number[float32](testFile, system.cpuEndian)
    # echo "check(f32 == ", f32, ")"
    check(f32 == 67.33999633789062)

  test "read negative int":

    testFile.setFilePos(20)
    var neg = read_number[int16](testFile, system.cpuEndian)
    # echo "check(neg == ", neg, ")"
    check(neg == -42)

  test "read invalid file position":
    expect IOError:
      testFile.setFilePos(300)
      var v8 = read_number[uint8](testFile)
      # echo "v8 = ", toHex(v8)
      check(v8 == 0x01)

  test "getNumber 16":

    var num16: uint16

    let expected = ["2301", "4523", "6745", "8967", "AB89", "CDAB",
                    "EFCD", "0123", "2345", "4567", "6789", "89AB",
                    "ABCD", "CDEF"]

    for index in 0..6:
      num16 = getNumber[uint16](buffer, index)
      # echo toHex(num16)
      check(expected[index] == toHex(num16))

    let ex2 = ["0123", "2345", "4567", "6789", "89AB", "ABCD", "CDEF"]
    for index in 0..6:
      num16 = getNumber[uint16](buffer, index, bigEndian)
      # echo toHex(num16)
      check(ex2[index] == toHex(num16))

  test "getNumber 8":

    let ex3 = ["01", "23", "45", "67", "89", "AB", "CD", "EF", "01",
               "23", "45", "67", "89", "AB", "CD", "EF"]
    for index in 0..7:
      var num8 = getNumber[uint8](buffer, index)
      # echo toHex(num8)
      check(ex3[index] == toHex(num8))

    let ex4 = ["01", "23", "45", "67", "89", "AB", "CD", "EF"]
    for index in 0..7:
      var num8 = getNumber[uint8](buffer, index, bigEndian)
      # echo toHex(num8)
      check(ex4[index] == toHex(num8))

  test "getNumber 32":

    let ex5 = ["67452301", "89674523", "AB896745", "CDAB8967", "EFCDAB89"]
    for index in 0..4:
      var num32 = getNumber[uint32](buffer, index)
      # echo toHex(num32)
      check(ex5[index] == toHex(num32))

    let ex6 = ["01234567", "23456789", "456789AB", "6789ABCD", "89ABCDEF"]
    for index in 0..4:
      var num8 = getNumber[uint32](buffer, index, bigEndian)
      # echo toHex(num8)
      check(ex6[index] == toHex(num8))

  test "getNumber 64":

    var num64 = getNumber[uint64](buffer)
    # echo toHex(num64)
    check("EFCDAB8967452301" == toHex(num64))

    num64 = getNumber[uint64](buffer, 0, bigEndian)
    # echo toHex(num64)
    check("0123456789ABCDEF" == toHex(num64))

  test "get2":

    var buffer = [0xff'u8, 0xc0]

    var num16: uint16 = getNumber[uint16](buffer, 0)
    check(num16 == 0xc0ff)

    var num = get2(buffer)
    check(num == 0xffc0)

  test "read1":
    testFile.setFilePos(0)
    var one = testfile.read1()
    check(one == 0x01)

  test "read2":
    testFile.setFilePos(0)
    var two = testfile.read2()
    check(two == 291)
