import unittest
import strutils
import os
import readBytes

var filename = "/tmp/test.bin"

proc test() =
  # Create a test file.
  var f: File
  if open(f, filename, fmWrite):
    var bytes = [01'u8, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef]
    discard f.writeBytes(bytes, 0, bytes.len)
    var d: float = 1.234
    discard f.writeBuffer(addr(d), sizeof(d))
    var d32: float32 = 67.34
    discard f.writeBuffer(addr(d32), sizeof(d32))
    var i16: int16 = -42
    discard f.writeBuffer(addr(i16), sizeof(i16))
    f.close()
  else:
    echo "Unable to create the file: ", filename

  defer:
    discard tryRemoveFile(filename)


  if not open(f, filename, fmRead):
    assert(false, "unable to open the file")
  defer:
    f.close()

  var v8 = read_number[uint8](f)
  # echo "v8 = ", toHex(v8)
  assert(v8 == 0x01)
  f.setFilePos(0)

  var v16 = read_number[uint16](f)
  # echo "assert(v16 == 0x", toHex(v16), ")"
  assert(v16 == 0x2301)
  f.setFilePos(0)

  var v32 = read_number[uint32](f)
  # echo "assert(v32 == 0x", toHex(v32), ")"
  assert(v32 == 0x67452301)
  f.setFilePos(0)

  var v64 = read_number[uint64](f)
  # echo "assert(v64 == 0x", toHex(v64), ")"
  assert(v64 == 0xEFCDAB8967452301'u64)
  f.setFilePos(8)

  var f64 = read_number[float64](f, system.cpuEndian)
  # echo "assert(f64 == ", f64, ")"
  assert(f64 == 1.234)
  var f32 = read_number[float32](f, system.cpuEndian)
  # echo "assert(f32 == ", f32, ")"
  assert(f32 == 67.33999633789062)
  var neg = read_number[int16](f, system.cpuEndian)
  # echo "assert(neg == ", neg, ")"
  assert(neg == -42)
  f.setFilePos(0)

  v8 = read_number[uint8](f, bigEndian)
  # echo "assert(v8 == 0x", toHex(v8), ")"
  assert(v8 == 0x01)
  f.setFilePos(0)

  v16 = read_number[uint16](f, bigEndian)
  # echo "assert(v16 == 0x", toHex(v16), ")"
  assert(v16 == 0x0123)
  f.setFilePos(0)

  v32 = read_number[uint32](f, bigEndian)
  # echo "assert(v32 == 0x", toHex(v32), ")"
  assert(v32 == 0x01234567)
  f.setFilePos(0)

  v64 = read_number[uint64](f, bigEndian)
  # echo "assert(v64 == 0x", toHex(v64), ")"
  assert(v64 == 0x0123456789ABCDEF'u64)
  f.setFilePos(0)

  var i8 = read_number[int8](f, bigEndian)
  # echo "assert(i8 == 0x", toHex(i8), ")"
  assert(i8 == 0x01)
  f.setFilePos(0)

  var i16 = read_number[int16](f, bigEndian)
  # echo "assert(i16 == 0x", toHex(i16), ")"
  assert(i16 == 0x0123)
  f.setFilePos(0)

  var i32 = read_number[int32](f, bigEndian)
  # echo "assert(i32 == 0x", toHex(i32), ")"
  assert(i32 == 0x01234567)
  f.setFilePos(0)

  var i64 = read_number[int64](f, bigEndian)
  # echo "assert(i64 == 0x", toHex(i64), ")"
  assert(i64 == 0x0123456789ABCDEF'i64)
  f.setFilePos(0)

  i8 = read_number[int8](f)
  # echo "assert(i8 == 0x", toHex(i8), ")"
  assert(i8 == 0x01)
  f.setFilePos(0)

  i16 = read_number[int16](f)
  # echo "assert(i16 == 0x", toHex(i16), ")"
  assert(i16 == 0x2301)
  f.setFilePos(0)

  i32 = read_number[int32](f)
  # echo "assert(i32 == 0x", toHex(i32), ")"
  assert(i32 == 0x67452301)
  f.setFilePos(0)

  i64 = read_number[int64](f)
  # echo "assert(i64 == 0x", toHex(i64), ")"
  assert(i64 == 0xEFCDAB8967452301)
  f.setFilePos(0)

when isMainModule:
  test()
